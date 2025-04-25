// lib/features/payment/models/payment.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, successful, failed, refunded, cancelled }

class Payment {
  final String id;
  final String appointmentId;
  final String patientId;
  final String doctorId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String paymentMethod;
  final String? invoiceId;
  final String? transactionId;
  final String? paymentLink;
  final bool linkSent;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? lastUpdated;
  final Map<String, dynamic>? metadata;

  Payment({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.invoiceId,
    this.transactionId,
    this.paymentLink,
    this.linkSent = false,
    required this.createdAt,
    this.completedAt,
    this.lastUpdated,
    this.metadata,
  });

  Payment copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? doctorId,
    double? amount,
    String? currency,
    PaymentStatus? status,
    String? paymentMethod,
    String? invoiceId,
    String? transactionId,
    String? paymentLink,
    bool? linkSent,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return Payment(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      invoiceId: invoiceId ?? this.invoiceId,
      transactionId: transactionId ?? this.transactionId,
      paymentLink: paymentLink ?? this.paymentLink,
      linkSent: linkSent ?? this.linkSent,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'patientId': patientId,
      'doctorId': doctorId,
      'amount': amount,
      'currency': currency,
      'status': status.toString().split('.').last,
      'paymentMethod': paymentMethod,
      'invoiceId': invoiceId,
      'transactionId': transactionId,
      'paymentLink': paymentLink,
      'linkSent': linkSent,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map, String docId) {
    return Payment(
      id: docId,
      appointmentId: map['appointmentId'] ?? '',
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      amount:
          (map['amount'] is int)
              ? (map['amount'] as int).toDouble()
              : (map['amount'] as double? ?? 0.0),
      currency: map['currency'] ?? 'KWD',
      status: _parseStatus(map['status'] ?? 'pending'),
      paymentMethod: map['paymentMethod'] ?? 'online',
      invoiceId: map['invoiceId'],
      transactionId: map['transactionId'],
      paymentLink: map['paymentLink'],
      linkSent: map['linkSent'] ?? false,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      completedAt: _parseDateTime(map['completedAt']),
      lastUpdated: _parseDateTime(map['lastUpdated']),
      metadata: map['metadata'],
    );
  }

  static PaymentStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'successful':
        return PaymentStatus.successful;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    }

    return null;
  }
}
