// models/sms_message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SmsMessage {
  final String mobile;
  final String message;
  final String sender;
  final int languageCode;
  final bool isTest;

  SmsMessage({
    required this.mobile,
    required this.message,
    required this.sender,
    this.languageCode =
        1, // 1: English, 2: Arabic (CP1256), 3: Arabic (UTF-8), 4: Unicode
    this.isTest = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'mobile': mobile,
      'message': message,
      'sender': sender,
      'lang': languageCode.toString(),
      'test': isTest ? '1' : '0',
    };
  }
}

class SmsRecordModel {
  final String id;
  final String recipient;
  final String message;
  final String sender;
  final String status;
  final DateTime createdAt;
  final String? messageId;
  final Map<String, dynamic>? metadata;

  SmsRecordModel({
    this.id = '',
    required this.recipient,
    required this.message,
    required this.sender,
    this.status = 'pending',
    DateTime? createdAt,
    this.messageId,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'recipient': recipient,
      'message': message,
      'sender': sender,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'messageId': messageId,
      'metadata': metadata,
    };
  }

  factory SmsRecordModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime createdAt;
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAt = DateTime.parse(map['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    return SmsRecordModel(
      id: documentId,
      recipient: map['recipient'] ?? '',
      message: map['message'] ?? '',
      sender: map['sender'] ?? '',
      status: map['status'] ?? 'unknown',
      createdAt: createdAt,
      messageId: map['messageId'],
      metadata: map['metadata'],
    );
  }
}
