import 'package:clinic_eye/features/payment/model/payment.dart';

class PaymentResponse {
  final bool success;
  final String? invoiceId;
  final String? invoiceUrl;
  final String? customerReference;
  final String? transactionId;
  final String? errorMessage;
  final PaymentStatus status;
  final Map<String, dynamic>? metadata;

  PaymentResponse({
    required this.success,
    this.invoiceId,
    this.invoiceUrl,
    this.customerReference,
    this.transactionId,
    this.errorMessage,
    this.status = PaymentStatus.pending,
    this.metadata,
  });
}
