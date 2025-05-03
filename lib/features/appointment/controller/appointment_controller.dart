import '../../../core/models/result.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../model/appointment.dart';

class AppointmentController {
  final FirebaseService _firebaseService;
  AppointmentController(this._firebaseService);
  // Get all appointments
  Future<Result<List<Appointment>>> getAllAppointments() async {
    print('Fetching all appointments from Firebase'); // Debug log

    try {
      final snapshot = await _firebaseService.queryCollection('appointments', []);
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
}
