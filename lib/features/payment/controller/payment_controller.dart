import 'package:clinic_eye/core/models/result.dart';
import '../model/payment.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../services/my_fatoorah_service.dart';

class PaymentController {
  final FirebaseService _firebaseService;
  final MyFatoorahService _myFatoorahService;

  PaymentController(this._firebaseService, this._myFatoorahService);

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
      // 1. Create initial Payment object.
      // The 'id' field is initially the appointmentId. This will be stored in the Firebase document.
      // Later, the 'id' field of the Payment *instance* returned by this function
      // will be updated to the Firebase document ID.
      Payment initialPayment = Payment(
        id: appointmentId, // Using appointmentId as the ID field in the payment data
        appointmentId: appointmentId,
        patientId: patientId,
        doctorId: doctorId,
        amount: amount,
        status: PaymentStatus.pending,
        createdAt: DateTime.now(),
      );

      // 2. Add payment record to Firebase.
      // Assuming addDocument returns an object (e.g., DocumentReference or a custom wrapper)
      // that has an 'id' property representing the Firebase document ID.
      final addedDocInfo = await _firebaseService.addDocument(
        'payments',
        initialPayment.toMap(),
      );
      // The actual ID of the document in Firebase.
      final String firebaseDocId = addedDocInfo.id;

      // 3. Generate payment link from MyFatoorah.
      // Pass the Firebase document ID as 'paymentId' to MyFatoorah for tracking.
      final myFatoorahResult = await _myFatoorahService.generatePaymentLink(
        amount: amount,
        customerName: customerName,
        customerMobile: customerMobile,
        customerEmail: customerEmail,
        paymentId: firebaseDocId, // Using the actual Firebase document ID
      );

      if (!myFatoorahResult.isSuccess) {
        // Optional: Consider actions like deleting or marking the Firebase payment record as failed.
        // Current behavior (matching original): just return error.
        return Result.error(
          myFatoorahResult.errorMessage ??
              'Failed to generate MyFatoorah payment link.',
        );
      }

      final fatoorahData = myFatoorahResult.data;
      if (fatoorahData == null) {
        return Result.error(
          'MyFatoorah returned no data for successful payment link generation.',
        );
      }

      final invoiceURL = fatoorahData['InvoiceURL'] as String?;
      final invoiceIdValue =
          fatoorahData['InvoiceId']; // Could be String or int
      final transactionIdFromFatoorah =
          fatoorahData['TransactionId'] as String?;

      if (invoiceURL == null || invoiceIdValue == null) {
        return Result.error(
          'MyFatoorah response is missing InvoiceURL or InvoiceId.',
        );
      }

      // As per original logic, transactionId is stored as '' in Firebase.
      final String transactionIdForFirebase = '';

      // 4. Prepare data for updating the payment record in Firebase.
      // The Payment object's 'id' field is updated to firebaseDocId.
      Payment paymentToUpdate = initialPayment.copyWith(
        id: firebaseDocId, // Update the 'id' field in the document data to be the Firebase doc ID.
        paymentLink: invoiceURL,
        invoiceId: invoiceIdValue.toString(), // Ensure it's a string
        status: PaymentStatus
            .pending, // Status remains pending until payment confirmation
        transactionId: transactionIdForFirebase,
      );

      await _firebaseService.updateDocument(
        'payments',
        firebaseDocId, // Document to update
        paymentToUpdate.toMap(),
      );

      // 5. Prepare the Payment object to be returned.
      // This object will have the actual transactionId from MyFatoorah.
      Payment finalPayment = paymentToUpdate.copyWith(
        transactionId:
            transactionIdFromFatoorah, // Use actual transactionId for the return
      );

      return Result.success(finalPayment);
    } catch (e) {
      // Consider using a proper logger for errors in production
      // For example: _logger.error('Error in generatePaymentLink', error: e, stackTrace: stackTrace);
      return Result.error('An unexpected error occurred: ${e.toString()}');
    }
  }
}
