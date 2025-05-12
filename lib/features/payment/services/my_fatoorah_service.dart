import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:clinic_eye/core/models/result.dart';

class MyFatoorahService {
  final http.Client _httpClient;

  MyFatoorahService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Future<Result<Map<String, dynamic>>> generatePaymentLink({
    required double amount,
    required String currency,
    required String customerName,
    required String customerMobile,
    required String customerEmail, // MyFatoorah often requires email
    required String orderId, // Your internal payment/order ID
    required String callbackUrl,
    String language = 'en',
  }) async {
    final url = '\${PaymentConfig.baseUrl}/v2/SendPayment';
    final headers = {
      'Authorization': 'Bearer \${PaymentConfig.apiKey}',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'CustomerName': customerName,
      'NotificationOption': 'LNK', // To get a payment link
      'InvoiceValue': amount,
      'CurrencyIso': currency,
      'CallBackUrl': callbackUrl,
      'ErrorUrl': callbackUrl, // Or a specific error URL
      'Language': language,
      'CustomerMobile': customerMobile,
      'CustomerEmail': customerEmail,
      'DisplayCurrencyIso': currency,
      // 'PaymentMethodId': 2, // Optional: Specify a payment method ID, e.g., 2 for KNET
      'UserDefinedField': orderId, // Can be used to store your internal paymentId
      // Add other necessary fields as per MyFatoorah documentation
    });

    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('MyFatoorah SendPayment Request: \$body');
      print('MyFatoorah SendPayment Response: \${response.body}');
      print('MyFatoorah SendPayment Status Code: \${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['IsSuccess'] == true && responseData['Data'] != null && responseData['Data']['PaymentURL'] != null) {
          return Result.success(responseData['Data']); // Contains InvoiceId, PaymentURL etc.
        } else {
          return Result.error(responseData['Message'] ?? 'Failed to generate payment link from MyFatoorah');
        }
      } else {
        return Result.error('MyFatoorah API Error: \${response.statusCode} - \${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error calling MyFatoorah SendPayment API: \$e');
      return Result.error('Exception during MyFatoorah API call: \$e');
    }
  }

  Future<Result<Map<String, dynamic>>> getPaymentStatus({
    required String invoiceId, // Or other key type as per MyFatoorah docs
  }) async {
    final url = '\${PaymentConfig.baseUrl}/v2/GetPaymentStatus';
    final headers = {
      'Authorization': 'Bearer \${PaymentConfig.apiKey}',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'Key': invoiceId,
      'KeyType': 'InvoiceId', // Can be 'PaymentId' or 'InvoiceId'
    });

    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      
      print('MyFatoorah GetPaymentStatus Request: \$body');
      print('MyFatoorah GetPaymentStatus Response: \${response.body}');
      print('MyFatoorah GetPaymentStatus Status Code: \${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['IsSuccess'] == true && responseData['Data'] != null) {
          return Result.success(responseData['Data']); // Contains InvoiceStatus, InvoiceReference, etc.
        } else {
          return Result.error(responseData['Message'] ?? 'Failed to get payment status from MyFatoorah');
        }
      } else {
        return Result.error('MyFatoorah API Error: \${response.statusCode} - \${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error calling MyFatoorah GetPaymentStatus API: \$e');
      return Result.error('Exception during MyFatoorah API call: \$e');
    }
  }
}

// Provider for MyFatoorahService
final myFatoorahServiceProvider = Provider<MyFatoorahService>((ref) {
  return MyFatoorahService();
});
