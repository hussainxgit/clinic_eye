import '../../../core/models/result.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../model/patient.dart';

class PatientController {
  final FirebaseService _firebaseService;

  PatientController(this._firebaseService);

  // Get all patients
  Future<Result<List<Patient>>> getAllPatients() async {
    print('Fetching all patients from Firebase'); // Debug log

    try {
      final snapshot = await _firebaseService.queryCollection('patients', []);
      final patients =
          snapshot.docs
              .map(
                (doc) =>
                    Patient.fromMap(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();
      return Result.success(patients);
    } catch (e) {
      return Result.error(e.toString());
    }
  }

  // Update patient
  Future<Result<Patient>> updatePatient(Patient patient) async {
    try {
      // Validate patient data
      await _validatePatient(patient, isUpdate: true);

      // Update document in Firestore
      await _firebaseService.updateDocument(
        'patients',
        patient.id,
        patient.toMap(),
      );

      // Return success result with the updated patient
      return Result.success(patient);
    } catch (e) {
      // Handle error and return failure result
      return Result.error(e.toString());
    }
  }

  // Add new patient
  Future<Result<Patient>> addPatient(Patient patient) async {
    try {
      // Validate patient data
      await _validatePatient(patient);

      // Add document to Firestore
      final docRef = await _firebaseService.addDocument(
        'patients',
        patient.toMap(),
      );

      // Return success result with the new patient
      return Result.success(patient.copyWith(id: docRef.id));
    } catch (e) {
      // Handle error and return failure result
      return Result.error(e.toString());
    }
  }

  // Delete patient
  Future<Result<void>> deletePatient(String id) async {
    try {
      // Delete document from Firestore
      await _firebaseService.deleteDocument('patients', id);
      return Result.success(null);
    } catch (e) {
      // Handle error and return failure result
      return Result.error(e.toString());
    }
  }

  // Private helper methods
  Future<void> _validatePatient(
    Patient patient, {
    bool isUpdate = false,
  }) async {
    // Validate patient data here (e.g., check for required fields)
    if (patient.name.isEmpty) {
      throw Exception('Name is required');
    }
    if (patient.phone.isEmpty) {
      throw Exception('Phone number is required');
    }
    if (patient.email != null && patient.email!.isEmpty) {
      throw Exception('Email is required');
    }
    if (patient.address != null && patient.address!.isEmpty) {
      throw Exception('Address is required');
    }
    // Check for duplicate name (except for updates)
    if (!isUpdate) {
      final snapshot = await _firebaseService.queryCollection('patients', [
        QueryFilter(field: 'name', isEqualTo: patient.name),
      ]);
      if (snapshot.docs.isNotEmpty) {
        throw Exception('Patient with this name already exists');
      }
    }
  }
}
