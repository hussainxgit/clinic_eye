import 'package:clinic_eye/core/models/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../messaging/services/kwt_sms_service.dart';
import '../config/payment_config.dart';
import '../../patient/model/patient.dart';
import '../model/payment.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../services/my_fatoorah_service.dart';

class PaymentController {
  final FirebaseService _firebaseService;
  final MyFatoorahService _myFatoorahService;
  final KwtSmsService _messagingService;

  PaymentController(
    this._firebaseService,
    this._myFatoorahService,
    this._messagingService,
  );

  /// Create payment and generate payment link
  Future<Result<Payment>> createAndGeneratePayment({
    required String patientName,
    required String patientMobile,
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required double amount,
    String currency = PaymentConfig.defaultCurrency,
  }) async {
    try {
      // Check for existing payments
      final existingPayments = await _getPaymentsByAppointment(appointmentId);

      // Return successful payment if exists
      for (final payment in existingPayments) {
        if (payment.status == PaymentStatus.successful) {
          return Result.success(payment);
        }
      }

      // Use existing pending payment if available
      final pendingPayments =
          existingPayments
              .where((p) => p.status == PaymentStatus.pending)
              .toList();

      if (pendingPayments.isNotEmpty) {
        final pendingPayment = pendingPayments.first;

        // Update timestamp
        await _firebaseService.firestore
            .collection('payments')
            .doc(pendingPayment.id)
            .update({'createdAt': FieldValue.serverTimestamp()});

        return Result.success(pendingPayment);
      }

      // Create new payment with pre-generated ID
      final newPaymentRef =
          _firebaseService.firestore.collection('payments').doc();
      final payment = Payment(
        id: newPaymentRef.id,
        appointmentId: appointmentId,
        patientId: patientId,
        doctorId: doctorId,
        amount: amount,
        currency: currency,
        status: PaymentStatus.pending,
        paymentMethod: 'MyFatoorah',
        createdAt: DateTime.now(),
      );

      // Generate payment link
      final result = await _generatePaymentLink(
        payment: payment,
        patientName: patientName,
        patientMobile: patientMobile,
      );

      return result;
    } catch (e) {
      return Result.error('Error creating payment: $e');
    }
  }

  /// Generate payment link via MyFatoorah API
  Future<Result<Payment>> _generatePaymentLink({
    required Payment payment,
    required String patientName,
    required String patientMobile,
  }) async {
    try {
      final result = await _myFatoorahService.generatePaymentLink(
        amount: payment.amount,
        currency: payment.currency,
        customerName: patientName,
        customerMobile: patientMobile,
        customerEmail:
            'test@example.com', // Consider making this parameter optional
        orderId: payment.id,
        callbackUrl: PaymentConfig.callbackUrl,
      );

      if (!result.isSuccess || result.data == null) {
        return Result.error(
          result.errorMessage ?? 'Failed to generate payment link',
        );
      }

      final responseData = result.data!;
      final paymentUrl = responseData['PaymentURL'] as String?;
      final invoiceId = responseData['InvoiceId'] as String?;

      if (paymentUrl == null || invoiceId == null) {
        return Result.error('Payment URL or Invoice ID missing in response');
      }

      // Update payment with link and invoice ID
      final updatedPayment = payment.copyWith(
        paymentLink: paymentUrl,
        invoiceId: invoiceId,
      );

      // Save to Firestore
      await _firebaseService.firestore
          .collection('payments')
          .doc(payment.id)
          .set(updatedPayment.toMap());

      return Result.success(updatedPayment);
    } catch (e) {
      return Result.error('Error generating payment link: $e');
    }
  }

  /// Send payment link via SMS
  Future<Result<bool>> sendPaymentLink({required Payment payment}) async {
    try {
      // Validate payment
      if (payment.paymentLink == null) {
        return Result.error('Payment link is missing');
      }

      // Get patient info
      final patientDoc =
          await _firebaseService.firestore
              .collection('patients')
              .doc(payment.patientId)
              .get();

      if (!patientDoc.exists) {
        return Result.error('Patient not found');
      }

      final patient = Patient.fromMap(patientDoc.data()!, patientDoc.id);

      // Get appointment date for message
      final appointmentDate = await _getAppointmentDate(payment.appointmentId);

      // Prepare message
      final message = PaymentConfig.paymentMessageTemplate(
        patientName: patient.name,
        appointmentDate: appointmentDate,
        amount: '${payment.amount.toStringAsFixed(3)} ${payment.currency}',
        paymentLink: payment.paymentLink!,
      );

      // Send SMS
      final result = await _messagingService.sendSms(
        mobileNumber: _formatPhoneNumber(patient.phone),
        message: message,
      );

      if (!result.isSuccess) {
        return Result.error(result.errorMessage ?? 'Failed to send SMS');
      }

      // Update payment record
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

      return Result.success(true);
    } catch (e) {
      return Result.error('Error sending payment link: $e');
    }
  }

  /// Check payment status with payment gateway
  Future<Result<PaymentStatus>> checkPaymentStatus(String paymentId) async {
    try {
      final payment = await _getPaymentById(paymentId);

      if (payment == null) {
        return Result.error('Payment not found');
      }

      if (payment.invoiceId == null) {
        return Result.error('Invoice ID not found');
      }

      final result = await _myFatoorahService.getPaymentStatus(
        invoiceId: payment.invoiceId!,
      );

      if (!result.isSuccess || result.data == null) {
        return Result.error(
          result.errorMessage ?? 'Failed to check payment status',
        );
      }

      final responseData = result.data!;
      final invoiceStatus = responseData['InvoiceStatus'] as String?;

      if (invoiceStatus == null) {
        return Result.error('Invoice status missing in response');
      }

      // Map status and update records
      final newStatus = _mapInvoiceStatus(invoiceStatus);
      final transactionId = responseData['TransactionId'] as String?;

      await _updatePaymentStatus(paymentId, newStatus, transactionId);

      // Update appointment if payment successful
      if (newStatus == PaymentStatus.successful) {
        await _updateAppointmentPaymentStatus(payment.appointmentId);
      }

      return Result.success(newStatus);
    } catch (e) {
      return Result.error('Error checking payment status: $e');
    }
  }

  // Get all payments
  Future<List<Payment>> getAllPayments() async {
    try {
      final snapshot =
          await _firebaseService.firestore
              .collection('payments')
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => Payment.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting all payments: $e');
      return [];
    }
  }

  // Get payments by patient
  Future<List<Payment>> getPaymentsByPatient(String patientId) async {
    try {
      final snapshot =
          await _firebaseService.firestore
              .collection('payments')
              .where('patientId', isEqualTo: patientId)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => Payment.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting payments by patient: $e');
      return [];
    }
  }

  // Private helper methods
  Future<List<Payment>> _getPaymentsByAppointment(String appointmentId) async {
    try {
      final snapshot =
          await _firebaseService.firestore
              .collection('payments')
              .where('appointmentId', isEqualTo: appointmentId)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => Payment.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting payments by appointment: $e');
      return [];
    }
  }

  Future<Payment?> _getPaymentById(String id) async {
    try {
      final doc =
          await _firebaseService.firestore.collection('payments').doc(id).get();

      if (!doc.exists) return null;
      return Payment.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting payment by ID: $e');
      return null;
    }
  }

  Future<void> _updatePaymentStatus(
    String id,
    PaymentStatus status,
    String? transactionId,
  ) async {
    try {
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
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }

  Future<void> _updateAppointmentPaymentStatus(String appointmentId) async {
    try {
      await _firebaseService.firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({'paymentStatus': 'paid'});
    } catch (e) {
      print('Error updating appointment payment status: $e');
    }
  }

  Future<String> _getAppointmentDate(String appointmentId) async {
    try {
      final appointmentDoc =
          await _firebaseService.firestore
              .collection('appointments')
              .doc(appointmentId)
              .get();

      if (!appointmentDoc.exists) {
        return 'your appointment';
      }

      final appointmentData = appointmentDoc.data()!;
      if (appointmentData['dateTime'] == null) {
        return 'your appointment';
      }

      final date =
          appointmentData['dateTime'] is Timestamp
              ? (appointmentData['dateTime'] as Timestamp).toDate()
              : DateTime.parse(appointmentData['dateTime']);

      final dateFormat = DateFormat('MMM d, yyyy');
      return dateFormat.format(date);
    } catch (e) {
      print('Error getting appointment date: $e');
      return 'your appointment';
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Add Kuwait country code if not present
    if (phoneNumber.startsWith('965')) {
      return phoneNumber;
    }

    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    return '965$digitsOnly';
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
