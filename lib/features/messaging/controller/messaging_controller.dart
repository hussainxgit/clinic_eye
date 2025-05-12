// services/messaging/sms_service.dart
import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/features/messaging/model/sms_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/sms_message.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../config/sms_config.dart';
import '../services/kwt_sms_service.dart'; // Import the new service

class MessegingController {
  final FirebaseService _firebaseService;
  final KwtSmsService _kwtSmsService; // Add KwtSmsService

  MessegingController(this._firebaseService, this._kwtSmsService); // Update constructor

  /// Send an SMS message to a single recipient
  Future<Result<bool>> sendSms({
    required String phoneNumber,
    required String message,
    String? sender,
    int? languageCode,
    bool isTest = SmsConfig.isTest,
  }) async {
    if (phoneNumber.isEmpty) {
      throw Exception('Phone number cannot be empty');
    }

    if (message.isEmpty) {
      throw Exception('Message content cannot be empty');
    }

    try {
      final formattedNumber = _formatMobileNumber(phoneNumber);

      // Create the message object
      final smsMessage = SmsMessage(
        mobile: formattedNumber,
        message: message,
        sender: sender ?? SmsConfig.defaultSenderId,
        languageCode: languageCode ?? SmsConfig.englishLanguage,
        isTest: isTest,
      );

      // Create a record for the message
      final record = SmsRecord(
        recipient: formattedNumber,
        message: message,
        sender: smsMessage.sender,
        status: 'pending',
        metadata: {
          'languageCode': smsMessage.languageCode,
          'isTest': smsMessage.isTest,
        },
      );

      // Save the record first
      final docRef = await _firebaseService.firestore
          .collection('sms_messages')
          .add(record.toMap());

      // Send the SMS via KwtSmsService
      final smsResult = await _kwtSmsService.sendSms(
        mobileNumber: formattedNumber, // Pass the formatted number
        message: smsMessage.message,
        senderId: smsMessage.sender,
        languageCode: smsMessage.languageCode,
        isTest: smsMessage.isTest,
      );

      if (!smsResult.isSuccess) {
        // Update the record with failed status
        await _firebaseService.firestore
            .collection('sms_messages')
            .doc(docRef.id)
            .update({
              'status': 'failed',
              'metadata': {
                ...record.metadata ?? {},
                'error': smsResult.errorMessage,
                'timestamp': DateTime.now().toIso8601String(),
              },
            });

        return Result.error(smsResult.errorMessage ?? "Failed to send SMS via KwtSmsService");
      }

      // Update the record with the success result from KwtSmsService
      final smsResponseData = smsResult.data!;
      await _firebaseService.firestore
          .collection('sms_messages')
          .doc(docRef.id)
          .update({
            'status': 'sent',
            'messageId': smsResponseData.messageId,
            'metadata': {
              ...record.metadata ?? {},
              'response': {
                'numbersProcessed': smsResponseData.numbersProcessed,
                'pointsCharged': smsResponseData.pointsCharged,
                'balanceAfter': smsResponseData.balanceAfter,
                'timestamp': smsResponseData.timestamp,
              },
            },
          });

      return Result.success(true);
    } catch (e) {
      print('Error sending SMS: $e');
      return Result.error(e.toString());
    }
  }

  /// Format mobile numbers by removing '+', '00', spaces and dots
  String _formatMobileNumber(String number) {
    return number
        .replaceAll(RegExp(r'[\+\s\.\-]'), '')
        .replaceAll(RegExp(r'^00'), '');
  }

  /// Get message history for a specific recipient or all messages
  Future<List<SmsRecord>> getMessageHistory({String? recipient}) async {
    try {
      Query query = _firebaseService.firestore
          .collection('sms_messages')
          .orderBy('createdAt', descending: true);

      if (recipient != null) {
        query = query.where('recipient', isEqualTo: recipient);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map(
            (doc) =>
                SmsRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('Error getting message history: $e');
      return [];
    }
  }
}

