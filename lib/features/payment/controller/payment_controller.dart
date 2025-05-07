// services/payment/payment_service.dart
import 'package:clinic_eye/core/models/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../messaging/controller/messeging_controller.dart';
import '../config/payment_config.dart';
import '../../patient/model/patient.dart';
import '../model/payment.dart';
import '../../../core/services/firebase/firebase_service.dart';

class PaymentController {
  final FirebaseService _firebaseService;
  final http.Client _httpClient;

  PaymentController(this._firebaseService) : _httpClient = http.Client();

  // Create payment record in Firestore
  Future<Result<Payment>> createPayment({
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
        return Result.success(latestPayment);
      }
    }

    // Create new payment record
    final newPayment = Payment(
      id: '',
      appointmentId: appointmentId,
      patientId: patientId,
      doctorId: doctorId,
      amount: amount,
      currency: currency,
      status: PaymentStatus.pending,
      paymentMethod: 'myfatoorah',
      createdAt: DateTime.now(),
    );

    final docRef = await _firebaseService.firestore
        .collection('payments')
        .add(newPayment.toMap());

    return Result.success(newPayment.copyWith(id: docRef.id));
  }

  // Generate payment link via MyFatoorah API
  Future<Result<Payment>> generatePaymentLink({
    required String paymentId,
    required String patientName,
    required String patientMobile,
  }) async {
    final payment = await _getPaymentById(paymentId);
    if (payment == null) {
      throw Exception('Payment not found');
    }

    final url = '${PaymentConfig.baseUrl}/v2/SendPayment';
    final response = await _httpClient.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${PaymentConfig.apiKey}',
      },
      body: jsonEncode({
        'NotificationOption': 'LNK', // Return link only, don't send email/SMS
        'CustomerName': patientName,
        'DisplayCurrencyIso': payment.currency,
        'MobileCountryCode': '+965',
        'CustomerMobile': patientMobile,
        'InvoiceValue': payment.amount,
        'CallBackUrl': PaymentConfig.webhookUrl,
        'ErrorUrl': PaymentConfig.webhookUrl,
        'Language': 'en',
        'CustomerReference': payment.appointmentId,
        'InvoiceItems': [
          {
            'ItemName': 'Eye Clinic Appointment',
            'Quantity': 1,
            'UnitPrice': payment.amount,
          },
        ],
      }),
    );
    print('Response: ${response.body}');
    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['IsSuccess'] == true) {
        final data = responseData['Data'];
        final updatedPayment = payment.copyWith(
          invoiceId: data['InvoiceId'].toString(),
          paymentLink: data['InvoiceURL'],
          metadata: {
            ...payment.metadata ?? {},
            'invoiceCreatedAt': DateTime.now().toIso8601String(),
          },
        );

        // Update the payment record
        await _firebaseService.firestore
            .collection('payments')
            .doc(payment.id)
            .update(updatedPayment.toMap());

        return Result.success(updatedPayment);
      } else {
        final errorMsg =
            responseData['ValidationErrors']?[0]?['Error'] ??
            responseData['Message'] ??
            'Failed to create payment link';
        throw Exception(errorMsg);
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
    }
  }

  // Send payment link via SMS/WhatsApp
  Future<Result<bool>> sendPaymentLink({
    required String paymentId,
  }) async {
    final payment = await _getPaymentById(paymentId);
    if (payment == null || payment.paymentLink == null) {
      throw Exception('Payment or payment link not found');
    }

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

    // Create message text
    print( 'Create message text for Patient Name: ${patient.name}');
    final messageText = PaymentConfig.paymentMessageTemplate(
      patientName: patient.name,
      appointmentDate: appointmentDate,
      amount: '${payment.amount.toStringAsFixed(3)} ${payment.currency}',
      paymentLink: payment.paymentLink!,
    );

    // Send SMS
    print('Sending SMS to ${patient.phone} with message: $messageText');
    final messegingController = MessegingController(_firebaseService);
    final result = await messegingController.sendSms(
      phoneNumber: '965${patient.phone}',
      message: messageText,
    );

    if (result.isSuccess) {
      // Update payment record as link sent
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
  Future<PaymentStatus> checkPaymentStatus(String paymentId) async {
    final payment = await _getPaymentById(paymentId);
    if (payment == null || payment.invoiceId == null) {
      throw Exception('Payment or invoice ID not found');
    }

    final url = '${PaymentConfig.baseUrl}/v2/GetPaymentStatus';
    final response = await _httpClient.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${PaymentConfig.apiKey}',
      },
      body: jsonEncode({'Key': payment.invoiceId, 'KeyType': 'InvoiceId'}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['IsSuccess'] == true) {
        final data = responseData['Data'];
        final invoiceStatus = data['InvoiceStatus'];
        final transactionId = data['InvoiceTransactions']?[0]?['TransactionId'];

        final newStatus = _mapInvoiceStatus(invoiceStatus);

        // If status has changed, update the payment record
        if (newStatus != payment.status) {
          await _updatePaymentStatus(
            payment.id,
            newStatus,
            transactionId?.toString(),
          );

          // If payment is successful, update the appointment payment status
          if (newStatus == PaymentStatus.successful) {
            await _updateAppointmentPaymentStatus(payment.appointmentId);
          }
        }

        return newStatus;
      } else {
        throw Exception(
          responseData['Message'] ?? 'Failed to check payment status',
        );
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode}');
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
