import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../../../core/models/result.dart';
import '../../slot/model/time_slot.dart';
import '../model/appointment.dart';

// Provider for creating an appointment
final createAppointmentProvider =
    FutureProvider.family<Result<Appointment>, Appointment>((ref, appointment) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.createAppointment(appointment);
    });

// Provider for updating an appointment
final updateAppointmentProvider =
    FutureProvider.family<Result<Appointment>, Appointment>((ref, appointment) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.updateAppointment(appointment);
    });

// Provider for getting an appointment by ID
final getAppointmentByIdProvider =
    FutureProvider.family<Result<Appointment>, String>((ref, id) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.getAppointmentById(id);
    });

// Provider for getting available time slots
final availableTimeSlotsProvider =
    FutureProvider.family<Result<List<TimeSlot>>, Map<String, dynamic>>((
      ref,
      params,
    ) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.getAvailableTimeSlots(
        params['doctorId'] as String,
        params['date'] as DateTime,
      );
    });

// Provider for cancelling an appointment
final cancelAppointmentProvider = FutureProvider.family<Result<void>, String>((
  ref,
  id,
) {
  final appointmentController = ref.watch(appointmentControllerProvider);
  return appointmentController.cancelAppointment(id);
});

// Provider for checking if a time slot is available
final isTimeSlotAvailableProvider =
    FutureProvider.family<Result<bool>, Map<String, dynamic>>((ref, params) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.isTimeSlotAvailable(
        params['timeSlotId'] as String,
        params['date'] as DateTime,
      );
    });

// Provider for getting appointments by patient
final appointmentsByPatientProvider =
    FutureProvider.family<Result<List<Appointment>>, String>((ref, patientId) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.getAppointmentsByPatient(patientId);
    });

// Provider for getting appointments by doctor
final appointmentsByDoctorProvider =
    FutureProvider.family<Result<List<Appointment>>, String>((ref, doctorId) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.getAppointmentsByDoctor(doctorId);
    });

// Provider for getting appointments by date
final appointmentsByDateProvider =
    FutureProvider.family<Result<List<Appointment>>, DateTime>((ref, date) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.getAppointmentsByDate(date);
    });

// Provider for getting all appointments
final allAppointmentsProvider = FutureProvider<Result<List<Appointment>>>((
  ref,
) {
  final appointmentController = ref.watch(appointmentControllerProvider);
  return appointmentController.getAllAppointments();
});