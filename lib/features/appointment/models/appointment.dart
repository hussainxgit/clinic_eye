// lib/features/appointment/models/appointment.dart
enum AppointmentStatus { scheduled, completed, cancelled }

enum PaymentStatus { paid, unpaid }

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String slotId;
  final String timeSlotId;
  final DateTime dateTime;
  final AppointmentStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.slotId,
    required this.timeSlotId,
    required this.dateTime,
    this.status = AppointmentStatus.scheduled,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Appointment copyWith({
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? slotId,
    String? timeSlotId,
    DateTime? dateTime,
    AppointmentStatus? status,
    PaymentStatus? paymentStatus,
    String? paymentId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      slotId: slotId ?? this.slotId,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'slotId': slotId,
      'timeSlotId': timeSlotId,
      'dateTime': dateTime.toIso8601String(),
      'status': status.toString().split('.').last,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'paymentId': paymentId,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      slotId: map['slotId'] ?? '',
      timeSlotId: map['timeSlotId'] ?? '',
      dateTime: DateTime.parse(map['dateTime']),
      status: _parseStatus(map['status'] ?? 'scheduled'),
      paymentStatus: _parsePaymentStatus(map['paymentStatus'] ?? 'unpaid'),
      paymentId: map['paymentId'],
      notes: map['notes'],
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  static AppointmentStatus _parseStatus(String status) {
    switch (status) {
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.scheduled;
    }
  }

  static PaymentStatus _parsePaymentStatus(String status) {
    return status == 'paid' ? PaymentStatus.paid : PaymentStatus.unpaid;
  }

  bool isSameDay(DateTime date) {
    return dateTime.year == date.year &&
        dateTime.month == date.month &&
        dateTime.day == date.day;
  }
}
