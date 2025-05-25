// lib/features/slot/controller/slot_controller.dart
import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/core/services/firebase/firebase_service.dart';
import 'package:clinic_eye/features/slot/model/slot.dart';
import 'package:clinic_eye/features/slot/model/time_slot.dart';
import 'package:flutter/material.dart';

class SlotController {
  final FirebaseService _firebaseService;

  SlotController(this._firebaseService);

  // Create a new slot, letting Firebase generate the ID
  Future<Result<Slot>> createSlot({
    required String doctorId,
    required DateTime date,
    bool isActive = true,
  }) async {
    try {
      final slotData = {
        'doctorId': doctorId,
        'date': date.toIso8601String(),
        'isActive': isActive,
      };
      final docRef = await _firebaseService.addDocument('slots', slotData);
      // Construct the Slot object with the Firebase-generated ID
      final newSlot = Slot(
        id: docRef.id,
        doctorId: doctorId,
        date: date,
        isActive: isActive,
      );
      return Result.success(newSlot);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Create a new time slot, letting Firebase generate the ID
  Future<Result<TimeSlot>> createTimeSlot({
    required String slotId,
    required String doctorId,
    required DateTime date,
    required TimeOfDay startTime,
    required Duration duration,
    required int maxPatients,
    int bookedPatients = 0,
    bool isActive = true,
  }) async {
    try {
      // Validate parameters before sending to Firebase
      if (duration.inMinutes < 15) {
        return Result.error('Slot duration must be at least 15 minutes');
      }
      if (maxPatients <= 0) {
        return Result.error('Max patients must be greater than 0');
      }
      if (bookedPatients > maxPatients) {
        return Result.error('Booked patients cannot exceed max patients');
      }

      final timeSlotData = {
        'slotId': slotId,
        'doctorId': doctorId,
        'date': date.toIso8601String(),
        'startTime': '${startTime.hour}:${startTime.minute}',
        'duration': duration.inMinutes,
        'maxPatients': maxPatients,
        'bookedPatients': bookedPatients,
        'isActive': isActive,
      };

      final docRef = await _firebaseService.addDocument(
        'time_slots',
        timeSlotData,
      );
      // Construct the TimeSlot object with the Firebase-generated ID
      final newTimeSlot = TimeSlot(
        id: docRef.id,
        slotId: slotId,
        doctorId: doctorId,
        date: date,
        startTime: startTime,
        duration: duration,
        maxPatients: maxPatients,
        bookedPatients: bookedPatients,
        isActive: isActive,
      );
      return Result.success(newTimeSlot);
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
        final slotResult = await createSlot(
          doctorId: doctorId,
          date: date,
          isActive: true,
        );

        if (slotResult.isError) {
          // Optionally log the error: print('Error creating slot for $date: ${slotResult.error}');
          continue; // Skip if slot creation failed
        }
        
        final createdSlot = slotResult.data!;

        // Create time slots for this day
        for (final timeOfDay in dailyTimeSlots) {
          final timeSlotResult = await createTimeSlot(
            slotId: createdSlot.id, // Use ID from the newly created slot
            doctorId: doctorId,
            date: date,
            startTime: timeOfDay,
            duration: slotDuration,
            maxPatients: maxPatients,
            isActive: true,
            // bookedPatients defaults to 0 in createTimeSlot
          );

          if (timeSlotResult.isSuccess) {
            createdCount++;
          } else {
            // Optionally log the error: print('Error creating time slot for ${createdSlot.id} at $timeOfDay: ${timeSlotResult.error}');
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
