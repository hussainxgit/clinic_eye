// lib/features/slot/models/time_slot.dart
import 'package:flutter/material.dart';

class TimeSlot {
  final String id;
  final String slotId;
  final String doctorId;
  final DateTime date;
  final TimeOfDay startTime;
  final Duration duration;
  final int maxPatients;
  final int bookedPatients;
  final bool isActive;

  bool get isFullyBooked => bookedPatients >= maxPatients;
  bool get isAvailable => isActive && !isFullyBooked;

  TimeOfDay get endTime {
    final end = DateTime(
      2022,
      1,
      1,
      startTime.hour,
      startTime.minute,
    ).add(duration);
    return TimeOfDay(hour: end.hour, minute: end.minute);
  }

  bool overlaps(TimeSlot other) {
    final thisStart = DateTime(2022, 1, 1, startTime.hour, startTime.minute);
    final thisEnd = thisStart.add(duration);
    final otherStart = DateTime(
      2022,
      1,
      1,
      other.startTime.hour,
      other.startTime.minute,
    );
    final otherEnd = otherStart.add(other.duration);

    return thisStart.isBefore(otherEnd) && thisEnd.isAfter(otherStart);
  }

  void validate() {
    if (duration.inMinutes < 15) {
      throw Exception('Slot duration must be at least 15 minutes');
    }
    if (maxPatients <= 0) {
      throw Exception('Max patients must be greater than 0');
    }
    if (bookedPatients > maxPatients) {
      throw Exception('Booked patients cannot exceed max patients');
    }
  }

  const TimeSlot({
    required this.id,
    required this.slotId,
    required this.doctorId,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.maxPatients,
    this.bookedPatients = 0,
    this.isActive = true,
  });

  TimeSlot copyWith({
    String? id,
    String? slotId,
    String? doctorId,
    DateTime? date,
    TimeOfDay? startTime,
    Duration? duration,
    int? maxPatients,
    int? bookedPatients,
    bool? isActive,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      maxPatients: maxPatients ?? this.maxPatients,
      bookedPatients: bookedPatients ?? this.bookedPatients,
      isActive: isActive ?? this.isActive,
    );
  }

  TimeSlot incrementBookings() {
    if (isFullyBooked) throw Exception('Slot is fully booked');
    if (!isActive) throw Exception('Slot is not active');

    return copyWith(bookedPatients: bookedPatients + 1);
  }

  TimeSlot decrementBookings() {
    if (bookedPatients <= 0) {
      throw Exception('No bookings to cancel');
    }

    return copyWith(bookedPatients: bookedPatients - 1);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slotId': slotId,
      'doctorId': doctorId,
      'date': date.toIso8601String(),
      'startTime': '${startTime.hour}:${startTime.minute}',
      'duration': duration.inMinutes,
      'maxPatients': maxPatients,
      'bookedPatients': bookedPatients,
      'isActive': isActive,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    final timeComponents = (map['startTime'] as String).split(':');
    return TimeSlot(
      id: map['id'] as String,
      slotId: map['slotId'] as String,
      doctorId: map['doctorId'] as String,
      date: DateTime.parse(map['date'] as String),
      startTime: TimeOfDay(
        hour: int.parse(timeComponents[0]),
        minute: int.parse(timeComponents[1]),
      ),
      duration: Duration(minutes: map['duration'] as int),
      maxPatients: map['maxPatients'] as int,
      bookedPatients: map['bookedPatients'] as int,
      isActive: map['isActive'] as bool,
    );
  }
}
