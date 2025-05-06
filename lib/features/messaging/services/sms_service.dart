// services/messaging/sms_service.dart
import 'dart:convert';
import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/features/messaging/model/sms_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../model/sms_message.dart';
import '../model/sms_response.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../config/sms_config.dart';

class SmsService {
  final FirebaseService _firebaseService;
  final http.Client _httpClient;

  SmsService(this._firebaseService) : _httpClient = http.Client();

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

      // Send the SMS
      final response = await _sendSmsRequest(smsMessage);

      if (!response.isSuccess) {
        // Update the record with failed status
        await _firebaseService.firestore
            .collection('sms_messages')
            .doc(docRef.id)
            .update({
              'status': 'failed',
              'metadata': {
                ...record.metadata ?? {},
                'error': response.errorMessage,
                'timestamp': DateTime.now().toIso8601String(),
              },
            });

        return Result.error(response.errorMessage);
      }

      // Update the record with the success result
      await _firebaseService.firestore
          .collection('sms_messages')
          .doc(docRef.id)
          .update({
            'status': 'sent',
            'messageId': response.messageId,
            'metadata': {
              ...record.metadata ?? {},
              'response': {
                'numbersProcessed': response.numbersProcessed,
                'pointsCharged': response.pointsCharged,
                'balanceAfter': response.balanceAfter,
                'timestamp': response.timestamp,
              },
            },
          });

      return Result.success(true);
    } catch (e) {
      print('Error sending SMS: $e');
      return Result.error(e.toString());
    }
  }

  /// Send the actual SMS request to the KWT SMS API
  Future<SmsResponse> _sendSmsRequest(SmsMessage message) async {
    try {
      final payload = {
        ...message.toMap(),
        'username': SmsConfig.apiUsername,
        'password': SmsConfig.apiPassword,
      };

      final response = await _httpClient.post(
        Uri.parse(SmsConfig.sendEndpoint),
        body: payload,
      );
      print(payload);
      print('Response: ${response.body}');
      print('Status Code: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = response.body.trim();

        // Check if the response is in the format "OK:messageId:numbers:charged:balance:timestamp"
        if (responseBody.startsWith('OK:')) {
          final parts = responseBody.split(':');
          if (parts.length >= 6) {
            return SmsResponse(
              isSuccess: true,
              messageId: parts[1],
              numbersProcessed: int.tryParse(parts[2]),
              pointsCharged: int.tryParse(parts[3]),
              balanceAfter: int.tryParse(parts[4]),
              timestamp: int.tryParse(parts[5]),
            );
          }
        }

        // Try parsing as JSON if it's not in the string format
        try {
          final jsonResponse = json.decode(responseBody);
          return SmsResponse.fromMap(jsonResponse);
        } catch (jsonError) {
          // If we can't parse as JSON and it starts with "OK", consider it a success
          if (responseBody.startsWith('OK')) {
            return SmsResponse(
              isSuccess: true,
              messageId: responseBody.substring(3).trim(),
            );
          }

          // Otherwise, return the error message
          return SmsResponse(
            isSuccess: false,
            errorMessage: 'Failed to parse API response: $responseBody',
          );
        }
      } else {
        return SmsResponse(
          isSuccess: false,
          errorMessage:
              'HTTP Error: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return SmsResponse(
        isSuccess: false,
        errorMessage: 'Error sending SMS: $e',
      );
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
