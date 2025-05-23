import '../../../core/models/result.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../../slot/model/time_slot.dart';
import '../model/appointment.dart';

class AppointmentController {
  final FirebaseService _firebaseService;

  AppointmentController(this._firebaseService);

  // Get all appointments - uses index on dateTime
  Future<Result<List<Appointment>>> getAllAppointments() async {
    try {
      final snapshot = await _firebaseService.firestore
          .collection('appointments')
          .orderBy('dateTime', descending: true)
          .get();

      final appointments = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointment by ID - no index needed for document lookup
  Future<Result<Appointment>> getAppointmentById(String id) async {
    try {
      final doc = await _firebaseService.firestore
          .collection('appointments')
          .doc(id)
          .get();

      if (!doc.exists) {
        return Result.error('Appointment not found');
      }

      final appointment = Appointment.fromMap(doc.data()!, doc.id);
      return Result.success(appointment);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Create appointment - no index needed for document creation
  Future<Result<Appointment>> createAppointment(Appointment appointment) async {
    try {
      // Validate time slot availability
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

      // Update time slot booking count
      await _incrementTimeSlotBooking(appointment.timeSlotId);

      return Result.success(appointment.copyWith(id: docRef.id));
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Update appointment - no index needed for document update
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
      await _firebaseService.firestore
          .collection('appointments')
          .doc(appointment.id)
          .update({
            ...appointment.toMap(),
            'updatedAt': DateTime.now().toIso8601String(),
          });

      return Result.success(appointment);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Cancel appointment - no index needed for document update
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
      await _firebaseService.firestore
          .collection('appointments')
          .doc(id)
          .update({
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

  // Get available time slots - uses composite index on doctorId, date, isActive
  Future<Result<List<TimeSlot>>> getAvailableTimeSlots(
    String doctorId,
    DateTime date,
  ) async {
    try {
      // Format date to start and end of day for query
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Query time slots by doctor and date - uses composite index
      final snapshot = await _firebaseService.firestore
          .collection('time_slots')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .where('isActive', isEqualTo: true)
          .orderBy('date')
          .orderBy('startTime')
          .get();

      final timeSlots = snapshot.docs
          .map((doc) => TimeSlot.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      return Result.success(timeSlots);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Check time slot availability - no index needed for document lookup
  Future<Result<bool>> isTimeSlotAvailable(
    String timeSlotId,
    DateTime date,
  ) async {
    try {
      final doc = await _firebaseService.firestore
          .collection('time_slots')
          .doc(timeSlotId)
          .get();

      if (!doc.exists) {
        return Result.error('Time slot not found');
      }

      final data = doc.data()!;
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

  // Get appointments by patient - uses composite index on patientId, dateTime
  Future<Result<List<Appointment>>> getAppointmentsByPatient(
    String patientId,
  ) async {
    try {
      final snapshot = await _firebaseService.firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('dateTime', descending: true)
          .get();

      final appointments = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointments by doctor - uses composite index on doctorId, dateTime
  Future<Result<List<Appointment>>> getAppointmentsByDoctor(
    String doctorId,
  ) async {
    try {
      final snapshot = await _firebaseService.firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('dateTime', descending: true)
          .get();

      final appointments = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Get appointments by date - uses index on dateTime
  Future<Result<List<Appointment>>> getAppointmentsByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firebaseService.firestore
          .collection('appointments')
          .where(
            'dateTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
          )
          .where('dateTime', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .orderBy('dateTime')
          .get();

      final appointments = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(appointments);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Private helper methods
  Future<void> _incrementTimeSlotBooking(String timeSlotId) async {
    return await _firebaseService.firestore.runTransaction((transaction) async {
      final docRef = _firebaseService.firestore
          .collection('time_slots')
          .doc(timeSlotId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw Exception('Time slot not found');
      }

      final data = doc.data()!;
      final currentBookings = data['bookedPatients'] ?? 0;
      final maxPatients = data['maxPatients'] ?? 1;

      if (currentBookings >= maxPatients) {
        throw Exception('Time slot is fully booked');
      }

      transaction.update(docRef, {'bookedPatients': currentBookings + 1});
    });
  }

  Future<void> _decrementTimeSlotBooking(String timeSlotId) async {
    return await _firebaseService.firestore.runTransaction((transaction) async {
      final docRef = _firebaseService.firestore
          .collection('time_slots')
          .doc(timeSlotId);
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        throw Exception('Time slot not found');
      }

      final data = doc.data()!;
      final currentBookings = data['bookedPatients'] ?? 0;

      if (currentBookings <= 0) {
        return; // Already at zero, no need to decrement
      }

      transaction.update(docRef, {'bookedPatients': currentBookings - 1});
    });
  }
}

  // Create payment for appointment - no index needed
  // Future<Result<void>> createPaymentForAppointment(
  //   Appointment appointment,
  // ) async {
  //   try {
  //     // Get service amount based on doctor's specialty or a default value
  //     double amount = 15.0; // Default consultation fee

  //     // Create payment record
  //     await _paymentService.createPayment(
  //       appointmentId: appointment.id,
  //       patientId: appointment.patientId,
  //       doctorId: appointment.doctorId,
  //       amount: amount,
  //     );

  //     return Result.success(null);
  //   } catch (e) {
  //     return Result.error(e.toString());
  //   }
  // }