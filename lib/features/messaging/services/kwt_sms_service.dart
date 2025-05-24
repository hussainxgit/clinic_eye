import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/features/messaging/model/sms_response.dart';
import 'package:clinic_eye/features/messaging/config/sms_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KwtSmsService {
  final http.Client _httpClient;

  KwtSmsService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Future<Result<SmsResponse>> sendSms({
    required String mobileNumber,
    required String message,
    String? senderId,
    int? languageCode,
    bool isTest = SmsConfig.isTest,
  }) async {
    final payload = {
      'username': SmsConfig.apiUsername,
      'password': SmsConfig.apiPassword,
      'mobile': '965$mobileNumber',
      'message': message,
      'sender': senderId ?? SmsConfig.defaultSenderId,
      'lang': (languageCode ?? SmsConfig.englishLanguage).toString(),
      'test': isTest ? '1' : '0',
    };

    try {
      final response = await _httpClient.post(
        Uri.parse(SmsConfig.sendEndpoint),
        body: payload,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = response.body.trim();
        if (responseBody.startsWith('OK:')) {
          final parts = responseBody.split(':');
          if (parts.length >= 6) {
            return Result.success(SmsResponse(
              isSuccess: true,
              messageId: parts[1],
              numbersProcessed: int.tryParse(parts[2]),
              pointsCharged: int.tryParse(parts[3]),
              balanceAfter: int.tryParse(parts[4]),
              timestamp: int.tryParse(parts[5]),
            ));
          } else if (parts.length >= 2) { // Handle cases with fewer parts but still "OK:"
             return Result.success(SmsResponse(
              isSuccess: true,
              messageId: parts[1],
            ));
          }
        }
        
        // Try parsing as JSON if it's not in the string format (though KWT SMS seems to use string primarily)
        try {
          final jsonResponse = json.decode(responseBody);
          final smsResponse = SmsResponse.fromMap(jsonResponse);
          if (smsResponse.isSuccess) {
            return Result.success(smsResponse);
          } else {
            return Result.error(smsResponse.errorMessage ?? 'KWT SMS API returned an error');
          }
        } catch (jsonError) {
          // If not "OK:" and not valid JSON, it's an error
          return Result.error('Failed to parse KWT SMS API response: \$responseBody');
        }
      } else {
        return Result.error('KWT SMS API HTTP Error: \${response.statusCode} \${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error calling KWT SMS API: \$e');
      return Result.error('Exception during KWT SMS API call: \$e');
    }
  }

  Future<Result<SmsResponse>> sendAppointmentReminder({
    required String mobileNumber,
    required String patientName,
    required String appointmentDate,
    required String doctorName,
  }) {
    final message = SmsConfig.appointmentReminderTemplate(
      patientName,
      appointmentDate,
      doctorName,
    );
    return sendSms(
      mobileNumber: mobileNumber,
      message: message,
    );
  }

  Future<Result<SmsResponse>> sendAppointmentConfirmation({
    required String mobileNumber,
    required String patientName,
    required String appointmentDate,
    required String doctorName,
  }) {
    final message = SmsConfig.appointmentConfirmationTemplate(
      patientName,
      appointmentDate,
      doctorName,
    );
    return sendSms(
      mobileNumber: mobileNumber,
      message: message,
    );
  }

  Future<Result<SmsResponse>> sendAppointmentPayment({
    required String mobileNumber,
    required String patientName,
    required DateTime appointmentDate,
    required String paymentLink,
    required double amount,
  }) {
    final message = SmsConfig.appointmentPaymentTemplate(
      patientName,
      appointmentDate,
      paymentLink,
      amount,
    );
    return sendSms(
      mobileNumber: mobileNumber,
      message: message,
    );
  }
}

// Provider for KwtSmsService
final kwtSmsServiceProvider = Provider<KwtSmsService>((ref) {
  return KwtSmsService();
});
