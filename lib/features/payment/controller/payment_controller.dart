import 'package:clinic_eye/core/models/result.dart';
import '../../messaging/services/kwt_sms_service.dart';
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

  Future<Result<Payment>> generatePaymentLink({
    required String patientId,
    required String doctorId,
    required String appointmentId,
    required String customerName,
    required String customerMobile,
    required double amount,
    String? customerEmail,
  }) async {
    try {
      Payment payment = Payment(
        id: appointmentId,
        appointmentId: appointmentId,
        patientId: patientId,
        doctorId: doctorId,
        amount: amount,
        status: PaymentStatus.pending,
        createdAt: DateTime.now(),
      );
      final savePayment = await _firebaseService.addDocument(
        'payments',
        payment.toMap(),
      );
      final myFatoorahPaymentLink = await _myFatoorahService
          .generatePaymentLink(
            amount: amount,
            customerName: customerName,
            customerMobile: customerMobile,
            customerEmail: customerEmail,
            paymentId: savePayment.id,
          );

      print(
        myFatoorahPaymentLink.data!,
      );
      await _firebaseService.updateDocument(
        'payments',
        savePayment.id,
        payment.copyWith(
          id: savePayment.id,
          paymentLink: myFatoorahPaymentLink.data!['InvoiceURL'],
          invoiceId: myFatoorahPaymentLink.data!['InvoiceId'],
          transactionId: myFatoorahPaymentLink.data!['TransactionId'],
        ).toMap(),
      );
      
      print(
        payment.copyWith(
          id: savePayment.id,
          paymentLink: myFatoorahPaymentLink.data!['InvoiceURL'],
          invoiceId: myFatoorahPaymentLink.data!['InvoiceId'],
          transactionId: myFatoorahPaymentLink.data!['TransactionId'],
        ).toMap(),
      );
      if (myFatoorahPaymentLink.isSuccess) {
        return Result.success(
          payment.copyWith(
            id: savePayment.id,
            paymentLink: myFatoorahPaymentLink.data!['InvoiceURL'],
            invoiceId: myFatoorahPaymentLink.data!['InvoiceId'],
            transactionId: myFatoorahPaymentLink.data!['TransactionId'],
          ),
        );
      } else {
        return Result.error(myFatoorahPaymentLink.errorMessage);
      }
    } catch (e) {
      return Result.error(e.toString());
    }
  }
}
