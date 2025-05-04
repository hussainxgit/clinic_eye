// lib/features/slot/provider/slot_provider.dart
import 'package:clinic_eye/core/config/dependencies.dart';
import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/features/slot/controller/slot_controller.dart';
import 'package:clinic_eye/features/slot/model/slot.dart';
import 'package:clinic_eye/features/slot/model/time_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final slotControllerProvider = Provider<SlotController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return SlotController(firebaseService);
});

// Provider for getting slots by doctor ID
final doctorSlotsProvider = FutureProvider.family<Result<List<Slot>>, String>((
  ref,
  doctorId,
) {
  final slotController = ref.watch(slotControllerProvider);
  return slotController.getSlotsByDoctor(doctorId);
});

// Provider for getting time slots by slot ID
final slotTimeSlotsProvider =
    FutureProvider.family<Result<List<TimeSlot>>, String>((ref, slotId) {
      final slotController = ref.watch(slotControllerProvider);
      return slotController.getTimeSlotsBySlot(slotId);
    });

// State notifier for slot form state
class SlotFormState {
  final DateTime startDate;
  final DateTime endDate;
  final List<TimeOfDay> dailyTimeSlots;
  final Duration slotDuration;
  final int maxPatients;
  final List<int> excludedWeekdays;
  final bool isGenerating;

  SlotFormState({
    required this.startDate,
    required this.endDate,
    this.dailyTimeSlots = const [],
    this.slotDuration = const Duration(minutes: 30),
    this.maxPatients = 1,
    this.excludedWeekdays = const [],
    this.isGenerating = false,
  });

  SlotFormState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<TimeOfDay>? dailyTimeSlots,
    Duration? slotDuration,
    int? maxPatients,
    List<int>? excludedWeekdays,
    bool? isGenerating,
  }) {
    return SlotFormState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dailyTimeSlots: dailyTimeSlots ?? this.dailyTimeSlots,
      slotDuration: slotDuration ?? this.slotDuration,
      maxPatients: maxPatients ?? this.maxPatients,
      excludedWeekdays: excludedWeekdays ?? this.excludedWeekdays,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

class SlotFormNotifier extends StateNotifier<SlotFormState> {
  final SlotController _slotController;

  SlotFormNotifier(this._slotController)
    : super(
        SlotFormState(
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 14)),
        ),
      );

  void setDateRange(DateTime startDate, DateTime endDate) {
    state = state.copyWith(startDate: startDate, endDate: endDate);
  }

  void setSlotDuration(Duration duration) {
    state = state.copyWith(slotDuration: duration);
  }

  void setMaxPatients(int maxPatients) {
    state = state.copyWith(maxPatients: maxPatients);
  }

  void toggleWeekday(int weekday) {
    final newExcludedWeekdays = List<int>.from(state.excludedWeekdays);
    if (newExcludedWeekdays.contains(weekday)) {
      newExcludedWeekdays.remove(weekday);
    } else {
      newExcludedWeekdays.add(weekday);
    }
    state = state.copyWith(excludedWeekdays: newExcludedWeekdays);
  }

  void addTimeSlot(TimeOfDay timeSlot) {
    final newTimeSlots = List<TimeOfDay>.from(state.dailyTimeSlots)
      ..add(timeSlot);
    // Sort time slots by hour and minute
    newTimeSlots.sort((a, b) {
      if (a.hour != b.hour) {
        return a.hour.compareTo(b.hour);
      }
      return a.minute.compareTo(b.minute);
    });
    state = state.copyWith(dailyTimeSlots: newTimeSlots);
  }

  void removeTimeSlot(TimeOfDay timeSlot) {
    final newTimeSlots = List<TimeOfDay>.from(state.dailyTimeSlots)
      ..removeWhere(
        (t) => t.hour == timeSlot.hour && t.minute == timeSlot.minute,
      );
    state = state.copyWith(dailyTimeSlots: newTimeSlots);
  }

  Future<Result<int>> generateSlots(String doctorId) async {
    if (state.dailyTimeSlots.isEmpty) {
      return Result.error('Please add at least one time slot');
    }

    state = state.copyWith(isGenerating: true);

    final result = await _slotController.generateSlots(
      doctorId: doctorId,
      startDate: state.startDate,
      endDate: state.endDate,
      dailyTimeSlots: state.dailyTimeSlots,
      slotDuration: state.slotDuration,
      maxPatients: state.maxPatients,
      excludedWeekdays: state.excludedWeekdays,
    );

    state = state.copyWith(isGenerating: false);
    return result;
  }
}

final slotFormProvider = StateNotifierProvider<SlotFormNotifier, SlotFormState>(
  (ref) {
    final slotController = ref.watch(slotControllerProvider);
    return SlotFormNotifier(slotController);
  },
);
