// lib/features/slot/controller/slot_controller.dart
import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/core/services/firebase/firebase_service.dart';
import 'package:clinic_eye/features/slot/model/slot.dart';
import 'package:clinic_eye/features/slot/model/time_slot.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class SlotController {
  final FirebaseService _firebaseService;

  SlotController(this._firebaseService);

  // Create a new slot
  Future<Result<Slot>> createSlot(Slot slot) async {
    try {
      final docRef = await _firebaseService.addDocument('slots', slot.toMap());
      return Result.success(slot.copyWith(id: docRef.id));
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Create a new time slot
  Future<Result<TimeSlot>> createTimeSlot(TimeSlot timeSlot) async {
    try {
      // Validate the time slot
      timeSlot.validate();

      final docRef = await _firebaseService.addDocument(
        'time_slots',
        timeSlot.toMap(),
      );
      return Result.success(timeSlot.copyWith(id: docRef.id));
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get slots by doctor ID
  // Update the getSlotsByDoctor method:
  Future<Result<List<Slot>>> getSlotsByDoctor(String doctorId) async {
    try {
      // Remove the orderBy parameter to avoid needing a composite index
      final snapshot = await _firebaseService.queryCollection(
        'slots',
        [QueryFilter(field: 'doctorId', isEqualTo: doctorId)],
        // We'll sort the results in memory instead
      );

      final slots =
          snapshot.docs
              .map((doc) => Slot.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

      // Sort slots by date in memory
      slots.sort((a, b) => a.date.compareTo(b.date));

      return Result.success(slots);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get time slots by slot ID
  Future<Result<List<TimeSlot>>> getTimeSlotsBySlot(String slotId) async {
    try {
      final snapshot = await _firebaseService.queryCollection('time_slots', [
        QueryFilter(field: 'slotId', isEqualTo: slotId),
      ]);

      final timeSlots =
          snapshot.docs
              .map(
                (doc) => TimeSlot.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();

      return Result.success(timeSlots);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Generate slots and time slots for a date range
  Future<Result<int>> generateSlots({
    required String doctorId,
    required DateTime startDate,
    required DateTime endDate,
    required List<TimeOfDay> dailyTimeSlots,
    required Duration slotDuration,
    required int maxPatients,
    required List<int> excludedWeekdays, // 1 = Monday, 7 = Sunday
  }) async {
    try {
      int createdCount = 0;
      final uuid = Uuid();

      // Iterate through each day in the range
      for (
        DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))
      ) {
        // Skip excluded weekdays (1 = Monday, ..., 7 = Sunday)
        if (excludedWeekdays.contains(date.weekday)) {
          continue;
        }

        // Create a slot for this day
        final slot = Slot(
          id: uuid.v4(),
          doctorId: doctorId,
          date: date,
          isActive: true,
        );

        final slotResult = await createSlot(slot);

        if (slotResult.isError) {
          continue; // Skip if slot creation failed
        }

        // Create time slots for this day
        for (final startTime in dailyTimeSlots) {
          final timeSlot = TimeSlot(
            id: uuid.v4(),
            slotId: slotResult.data!.id,
            doctorId: doctorId,
            date: date,
            startTime: startTime,
            duration: slotDuration,
            maxPatients: maxPatients,
            isActive: true,
          );

          final timeSlotResult = await createTimeSlot(timeSlot);

          if (timeSlotResult.isSuccess) {
            createdCount++;
          }
        }
      }

      return Result.success(createdCount);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Toggle slot availability
  Future<Result<Slot>> toggleSlotAvailability(String slotId) async {
    try {
      final doc = await _firebaseService.getDocument('slots', slotId);
      final slot = Slot.fromMap(doc.data() as Map<String, dynamic>);

      final updatedSlot = slot.copyWith(isActive: !slot.isActive);
      await _firebaseService.updateDocument(
        'slots',
        slotId,
        updatedSlot.toMap(),
      );

      return Result.success(updatedSlot);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Delete slot and its time slots
  Future<Result<void>> deleteSlot(String slotId) async {
    try {
      // First get all time slots for this slot
      final timeSlots = await getTimeSlotsBySlot(slotId);

      if (timeSlots.isSuccess) {
        // Delete all time slots
        for (final timeSlot in timeSlots.data!) {
          await _firebaseService.deleteDocument('time_slots', timeSlot.id);
        }
      }

      // Delete the slot
      await _firebaseService.deleteDocument('slots', slotId);

      return Result.success(null);
    } catch (e) {
      return Result.error(e.toString());
    }
  }
}
