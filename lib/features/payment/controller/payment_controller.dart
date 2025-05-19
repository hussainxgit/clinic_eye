// services/payment/payment_service.dart
import 'package:clinic_eye/core/models/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../messaging/services/kwt_sms_service.dart';
import '../config/payment_config.dart';
import '../../patient/model/patient.dart';
import '../model/payment.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../services/my_fatoorah_service.dart'; // Import the new service

class PaymentController {
  final FirebaseService _firebaseService;
  final MyFatoorahService _myFatoorahService; // Add MyFatoorahService
  final KwtSmsService messagingService; // Add read provider

  PaymentController(
    this._firebaseService,
    this._myFatoorahService,
    this.messagingService,
  ); // Update constructor

  // Create payment record in Firestore
  Future<Result<Payment>> createAndGeneratePayment({
    required String patientName,
    required String patientMobile,
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required double amount,
    String currency = 'KWD',
  }) async {
    // Check if payment already exists
    final existingPayments = await _getPaymentsByAppointment(appointmentId);
    if (existingPayments.isNotEmpty) {
      final latestPayment = existingPayments.first;
      if (latestPayment.status == PaymentStatus.successful ||
          latestPayment.status == PaymentStatus.pending) {
        if (latestPayment.status == PaymentStatus.successful) {
          return Result.success(latestPayment);
        }
      }
    }

    // Create new payment record or use existing pending
    String paymentIdToUse;

    final pendingPayment =
        existingPayments
            .where((p) => p.status == PaymentStatus.pending)
            .toList();
    if (pendingPayment.isNotEmpty) {
      paymentIdToUse = pendingPayment.first.id;
      await _firebaseService.firestore
          .collection('payments')
          .doc(paymentIdToUse)
          .update({'createdAt': DateTime.now()});
    } else {
      // Handle the case when there is no pending payment (create a new payment, etc.)
      // create new payment record
      final generatePaymentLinkResult = await generatePaymentLink(
        payment: Payment(
          id: _firebaseService.firestore.collection('payments').doc().id,
          appointmentId: appointmentId,
          patientId: patientId,
          doctorId: doctorId,
          amount: amount,
          currency: currency,
          status: PaymentStatus.pending,
          paymentMethod: 'MyFatoorah',
          createdAt: DateTime.now(),
        ),
        patientName: patientName,
        patientMobile: patientMobile,
        
      );

      if (generatePaymentLinkResult.isSuccess) {
        return Result.success(generatePaymentLinkResult.data!);
      } else {
        return Result.error(
          generatePaymentLinkResult.errorMessage ??
              "Failed to generate payment link",
        );
      }
    }
    // Add a fallback return to satisfy the analyzer
    // This should never be reached, but is required for non-nullable return type
    // ignore: dead_code
    return Result.error("Unknown error occurred in createAndGeneratePayment");
  }

  // Generate payment link via MyFatoorah API
  Future<Result<Payment>> generatePaymentLink({
    required Payment payment,
    required String patientName,
    required String patientMobile,
  }) async {
    final result = await _myFatoorahService.generatePaymentLink(
      amount: payment.amount,
      currency: payment.currency,
      customerName: patientName,
      customerMobile: patientMobile,
      customerEmail: 'test@example.com',
      orderId: payment.id,
      callbackUrl: PaymentConfig.callbackUrl,
    );

    if (result.isSuccess) {
      final responseData = result.data!;
      final paymentUrl = responseData['PaymentURL'] as String?;
      final invoiceId = responseData['InvoiceId'] as String?;

      if (paymentUrl != null && invoiceId != null) {
        final updatedPayment = payment.copyWith(
          paymentLink: paymentUrl,
          invoiceId: invoiceId,
          status: PaymentStatus.pending,
        );
        await _firebaseService.firestore
            .collection('payments')
            .doc(payment.id)
            .update(updatedPayment.toMap());
        return Result.success(updatedPayment);
      } else {
        return Result.error(
          'PaymentURL or InvoiceId missing in MyFatoorah response',
        );
      }
    } else {
      return Result.error(
        result.errorMessage ??
            'Failed to generate payment link via MyFatoorahService',
      );
    }
  }

  // Send payment link via SMS/WhatsApp
  Future<Result<bool>> sendPaymentLink({required Payment payment}) async {

    final patientDoc =
        await _firebaseService.firestore
            .collection('patients')
            .doc(payment.patientId)
            .get();

    if (!patientDoc.exists) {
      throw Exception('Patient not found');
    }

    final patient = Patient.fromMap(patientDoc.data()!, patientDoc.id);

    final appointmentDoc =
        await _firebaseService.firestore
            .collection('appointments')
            .doc(payment.appointmentId)
            .get();

    String appointmentDate = 'your appointment';
    if (appointmentDoc.exists) {
      final appointmentData = appointmentDoc.data()!;
      if (appointmentData['dateTime'] != null) {
        final date =
            appointmentData['dateTime'] is Timestamp
                ? (appointmentData['dateTime'] as Timestamp).toDate()
                : DateTime.parse(appointmentData['dateTime']);

        final dateFormat = DateFormat('MMM d, yyyy');
        appointmentDate = dateFormat.format(date);
      }
    }

    final messageText = PaymentConfig.paymentMessageTemplate(
      patientName: patient.name,
      appointmentDate: appointmentDate,
      amount: '${payment.amount.toStringAsFixed(3)} ${payment.currency}',
      paymentLink: payment.paymentLink!,
    );

    final result = await messagingService.sendSms(
      mobileNumber: '965${patient.phone}',
      message: messageText,
    );

    if (result.isSuccess) {
      await _firebaseService.firestore
          .collection('payments')
          .doc(payment.id)
          .update({
            'linkSent': true,
            'metadata': {
              ...payment.metadata ?? {},
              'linkSentAt': DateTime.now().toIso8601String(),
            },
          });
    }

    return Result.success(true);
  }

  // Check payment status
  Future<Result<PaymentStatus>> checkPaymentStatus(String paymentId) async {
    final payment = await _getPaymentById(paymentId);
    if (payment == null || payment.invoiceId == null) {
      return Result.error('Payment or invoice ID not found');
    }

    final result = await _myFatoorahService.getPaymentStatus(
      invoiceId: payment.invoiceId!,
    );

    if (result.isSuccess) {
      final responseData = result.data!;
      final invoiceStatus = responseData['InvoiceStatus'] as String?;
      final transactionId = responseData['TransactionId'] as String?;

      if (invoiceStatus != null) {
        final newStatus = _mapInvoiceStatus(invoiceStatus);
        await _updatePaymentStatus(paymentId, newStatus, transactionId);
        if (newStatus == PaymentStatus.successful) {
          await _updateAppointmentPaymentStatus(payment.appointmentId);
        }
        return Result.success(newStatus);
      } else {
        return Result.error('InvoiceStatus missing in MyFatoorah response');
      }
    } else {
      await _updatePaymentStatus(paymentId, PaymentStatus.failed, null);
      return Result.error(
        result.errorMessage ??
            'Failed to check payment status via MyFatoorahService',
      );
    }
  }

  // Get all payments
  Future<List<Payment>> getAllPayments() async {
    final snapshot =
        await _firebaseService.firestore
            .collection('payments')
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => Payment.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get payments by patient
  Future<List<Payment>> getPaymentsByPatient(String patientId) async {
    final snapshot =
        await _firebaseService.firestore
            .collection('payments')
            .where('patientId', isEqualTo: patientId)
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => Payment.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Private helper methods
  Future<List<Payment>> _getPaymentsByAppointment(String appointmentId) async {
    final snapshot =
        await _firebaseService.firestore
            .collection('payments')
            .where('appointmentId', isEqualTo: appointmentId)
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs
        .map((doc) => Payment.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<Payment?> _getPaymentById(String id) async {
    final doc =
        await _firebaseService.firestore.collection('payments').doc(id).get();

    if (!doc.exists) return null;
    return Payment.fromMap(doc.data()!, doc.id);
  }

  Future<void> _updatePaymentStatus(
    String id,
    PaymentStatus status,
    String? transactionId,
  ) async {
    final updateData = <String, dynamic>{
      'status': status.toString().split('.').last,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (status == PaymentStatus.successful) {
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    if (transactionId != null) {
      updateData['transactionId'] = transactionId;
    }

    await _firebaseService.firestore
        .collection('payments')
        .doc(id)
        .update(updateData);
  }

  Future<void> _updateAppointmentPaymentStatus(String appointmentId) async {
    await _firebaseService.firestore
        .collection('appointments')
        .doc(appointmentId)
        .update({'paymentStatus': 'paid'});
  }

  PaymentStatus _mapInvoiceStatus(String invoiceStatus) {
    switch (invoiceStatus.toLowerCase()) {
      case 'paid':
        return PaymentStatus.successful;
      case 'unpaid':
        return PaymentStatus.pending;
      case 'failed':
      case 'expired':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }
}
