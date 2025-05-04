import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/result.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../../payment/model/payment.dart';
import '../../payment/services/payment_service.dart';
import '../../slot/model/time_slot.dart';
import '../model/appointment.dart';

class AppointmentController {
  final FirebaseService _firebaseService;
  final PaymentService _paymentService;

  AppointmentController(this._firebaseService)
    : _paymentService = PaymentService(_firebaseService);

  // Get all appointments
  Future<Result<List<Appointment>>> getAllAppointments() async {
    try {
      final snapshot = await _firebaseService.queryCollection(
        'appointments',
        [],
        orderBy: 'dateTime',
        descending: true,
      );

      final appointments =
          snapshot.docs
              .map(
                (doc) => Appointment.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointment by ID
  Future<Result<Appointment>> getAppointmentById(String id) async {
    try {
      final doc = await _firebaseService.getDocument('appointments', id);

      if (!doc.exists) {
        return Result.error('Appointment not found');
      }

      final appointment = Appointment.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
      return Result.success(appointment);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Create new appointment
  Future<Result<Appointment>> createAppointment(Appointment appointment) async {
    try {
      // Validate the time slot is available
      final timeSlotResult = await isTimeSlotAvailable(
        appointment.timeSlotId,
        appointment.dateTime,
      );

      if (!timeSlotResult.isSuccess) {
        return Result.error(
          timeSlotResult.errorMessage ??
              'Failed to check time slot availability',
        );
      }

      if (!timeSlotResult.data!) {
        return Result.error('The selected time slot is no longer available');
      }

      // Create appointment in Firestore
      final docRef = await _firebaseService.addDocument(
        'appointments',
        appointment.toMap(),
      );

      // Update the time slot to increment booked patients
      await _incrementTimeSlotBooking(appointment.timeSlotId);

      // Return success with the appointment ID
      return Result.success(appointment.copyWith(id: docRef.id));
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Update existing appointment
  Future<Result<Appointment>> updateAppointment(Appointment appointment) async {
    try {
      // Check if appointment exists
      final existingAppointmentResult = await getAppointmentById(
        appointment.id,
      );
      if (!existingAppointmentResult.isSuccess) {
        return Result.error(
          existingAppointmentResult.errorMessage ?? 'Appointment not found',
        );
      }

      final existingAppointment = existingAppointmentResult.data!;

      // If time slot changed, validate new slot and update bookings
      if (existingAppointment.timeSlotId != appointment.timeSlotId) {
        // Check if new time slot is available
        final timeSlotResult = await isTimeSlotAvailable(
          appointment.timeSlotId,
          appointment.dateTime,
        );

        if (!timeSlotResult.isSuccess) {
          return Result.error(
            timeSlotResult.errorMessage ??
                'Failed to check time slot availability',
          );
        }

        if (!timeSlotResult.data!) {
          return Result.error('The selected time slot is no longer available');
        }

        // Update old and new time slots
        await _decrementTimeSlotBooking(existingAppointment.timeSlotId);
        await _incrementTimeSlotBooking(appointment.timeSlotId);
      }

      // Update appointment in Firestore
      await _firebaseService.updateDocument('appointments', appointment.id, {
        ...appointment.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return Result.success(appointment);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Cancel appointment
  Future<Result<void>> cancelAppointment(String id) async {
    try {
      // Check if appointment exists
      final appointmentResult = await getAppointmentById(id);
      if (!appointmentResult.isSuccess) {
        return Result.error(
          appointmentResult.errorMessage ?? 'Appointment not found',
        );
      }

      final appointment = appointmentResult.data!;

      // Update appointment status
      await _firebaseService.updateDocument('appointments', id, {
        'status': AppointmentStatus.cancelled.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update time slot booking
      await _decrementTimeSlotBooking(appointment.timeSlotId);

      return Result.success(null);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get available time slots for a doctor on a specific date
  Future<Result<List<TimeSlot>>> getAvailableTimeSlots(
    String doctorId,
    DateTime date,
  ) async {
    try {
      // Format date to start and end of day for query
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Query time slots by doctor and date
      final snapshot = await _firebaseService.queryCollection('time_slots', [
        QueryFilter(field: 'doctorId', isEqualTo: doctorId),
        QueryFilter(
          field: 'date',
          isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
        ),
        QueryFilter(
          field: 'date',
          isLessThanOrEqualTo: endOfDay.toIso8601String(),
        ),
        QueryFilter(field: 'isActive', isEqualTo: true),
      ], orderBy: 'startTime');

      // Convert to TimeSlot objects
      final timeSlots =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return TimeSlot.fromMap({...data, 'id': doc.id});
          }).toList();

      return Result.success(timeSlots);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Check if a time slot is available
  Future<Result<bool>> isTimeSlotAvailable(
    String timeSlotId,
    DateTime date,
  ) async {
    try {
      // Check if the time slot exists and is active
      final doc = await _firebaseService.getDocument('time_slots', timeSlotId);
      if (!doc.exists) {
        return Result.error('Time slot not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final timeSlot = TimeSlot.fromMap({...data, 'id': doc.id});

      // Check if slot is active and not fully booked
      if (!timeSlot.isActive) {
        return Result.success(false);
      }

      if (timeSlot.isFullyBooked) {
        return Result.success(false);
      }

      // Compare dates
      final slotDate = DateTime.parse(data['date']);
      if (slotDate.year != date.year ||
          slotDate.month != date.month ||
          slotDate.day != date.day) {
        return Result.error('Time slot date does not match appointment date');
      }

      return Result.success(true);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointments by patient
  Future<Result<List<Appointment>>> getAppointmentsByPatient(
    String patientId,
  ) async {
    try {
      final snapshot = await _firebaseService.queryCollection(
        'appointments',
        [QueryFilter(field: 'patientId', isEqualTo: patientId)],
        orderBy: 'dateTime',
        descending: true,
      );

      final appointments =
          snapshot.docs
              .map(
                (doc) => Appointment.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointments by doctor
  Future<Result<List<Appointment>>> getAppointmentsByDoctor(
    String doctorId,
  ) async {
    try {
      final snapshot = await _firebaseService.queryCollection(
        'appointments',
        [QueryFilter(field: 'doctorId', isEqualTo: doctorId)],
        orderBy: 'dateTime',
        descending: true,
      );

      final appointments =
          snapshot.docs
              .map(
                (doc) => Appointment.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointments by date
  Future<Result<List<Appointment>>> getAppointmentsByDate(DateTime date) async {
    try {
      // Format date to start and end of day for query
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firebaseService.queryCollection('appointments', [
        QueryFilter(
          field: 'dateTime',
          isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
        ),
        QueryFilter(
          field: 'dateTime',
          isLessThanOrEqualTo: endOfDay.toIso8601String(),
        ),
      ], orderBy: 'dateTime');

      final appointments =
          snapshot.docs
              .map(
                (doc) => Appointment.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Create payment for appointment
  Future<Result<void>> createPaymentForAppointment(
    Appointment appointment,
  ) async {
    try {
      // Get service amount based on doctor's specialty or a default value
      double amount = 15.0; // Default consultation fee

      // Create payment record
      await _paymentService.createPayment(
        appointmentId: appointment.id,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        amount: amount,
      );

      return Result.success(null);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Private helper methods
  Future<void> _incrementTimeSlotBooking(String timeSlotId) async {
    return await _firebaseService.runTransaction((transaction) async {
      // Get time slot document
      final docRef = _firebaseService.firestore
          .collection('time_slots')
          .doc(timeSlotId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw Exception('Time slot not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final currentBookings = data['bookedPatients'] ?? 0;
      final maxPatients = data['maxPatients'] ?? 1;

      if (currentBookings >= maxPatients) {
        throw Exception('Time slot is fully booked');
      }

      // Increment booked patients
      transaction.update(docRef, {'bookedPatients': currentBookings + 1});
    });
  }

  Future<void> _decrementTimeSlotBooking(String timeSlotId) async {
    return await _firebaseService.runTransaction((transaction) async {
      // Get time slot document
      final docRef = _firebaseService.firestore
          .collection('time_slots')
          .doc(timeSlotId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw Exception('Time slot not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final currentBookings = data['bookedPatients'] ?? 0;

      if (currentBookings <= 0) {
        return; // Already at zero, no need to decrement
      }

      // Decrement booked patients
      transaction.update(docRef, {'bookedPatients': currentBookings - 1});
    });
  }
}
