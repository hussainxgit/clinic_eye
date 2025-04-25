// models/sms_response_model.dart
class SmsResponse {
  final bool isSuccess;
  final String? messageId;
  final int? numbersProcessed;
  final int? pointsCharged;
  final int? balanceAfter;
  final int? timestamp;
  final String? errorMessage;

  SmsResponse({
    required this.isSuccess,
    this.messageId,
    this.numbersProcessed,
    this.pointsCharged,
    this.balanceAfter,
    this.timestamp,
    this.errorMessage,
  });

  factory SmsResponse.fromMap(Map<String, dynamic> map) {
    final isSuccess = map['result'] == 'OK';

    return SmsResponse(
      isSuccess: isSuccess,
      messageId: map['msg-id'],
      numbersProcessed: map['numbers'],
      pointsCharged: map['pointscharged'],
      balanceAfter: map['balance-after'],
      timestamp: map['unix-timestamp'],
      errorMessage: isSuccess ? null : map['error'],
    );
  }
}
