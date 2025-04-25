// controllers/doctor_controller.dart
import 'package:clinic_eye/features/doctor/model/doctor.dart';

import '../../../core/services/firebase/firebase_service.dart';

class DoctorController {
  final FirebaseService _firebaseService;

  DoctorController(this._firebaseService);

  // Get all doctors
  Future<List<Doctor>> getAllDoctors() async {
    final snapshot = await _firebaseService.getCollection('doctors');
    return snapshot.docs
        .map(
          (doc) => Doctor.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Get available doctors
  Future<List<Doctor>> getAvailableDoctors() async {
    final snapshot = await _firebaseService.queryCollection('doctors', [
      QueryFilter(field: 'isAvailable', isEqualTo: true),
    ]);

    return snapshot.docs
        .map(
          (doc) => Doctor.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Get doctor by ID
  Future<Doctor?> getDoctorById(String id) async {
    final doc = await _firebaseService.getDocument('doctors', id);
    if (!doc.exists) return null;
    return Doctor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // Add new doctor
  Future<Doctor> addDoctor(Doctor doctor) async {
    // Validate business rules
    await _validateDoctor(doctor);

    // Create doctor document
    final docRef = await _firebaseService.addDocument(
      'doctors',
      doctor.toMap(),
    );

    return doctor.copyWith(id: docRef.id);
  }

  // Update doctor
  Future<Doctor> updateDoctor(Doctor doctor) async {
    // Check if doctor exists
    final existing = await getDoctorById(doctor.id);
    if (existing == null) {
      throw Exception('Doctor not found');
    }

    // Validate doctor data
    await _validateDoctor(doctor, isUpdate: true);

    // Update document
    await _firebaseService.updateDocument('doctors', doctor.id, doctor.toMap());

    return doctor;
  }

  // Delete doctor
  Future<bool> deleteDoctor(String id) async {
    // Check if doctor exists
    final existing = await getDoctorById(id);
    if (existing == null) {
      throw Exception('Doctor not found');
    }

    // Check for related appointments before delete
    final appointmentsSnapshot = await _firebaseService.queryCollection(
      'appointments',
      [QueryFilter(field: 'doctorId', isEqualTo: id)],
    );

    if (appointmentsSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete doctor with existing appointments');
    }

    // Perform delete
    await _firebaseService.deleteDocument('doctors', id);
    return true;
  }

  // Toggle doctor availability
  Future<Doctor> toggleAvailability(String id) async {
    final doctor = await getDoctorById(id);
    if (doctor == null) {
      throw Exception('Doctor not found');
    }

    final updatedDoctor = doctor.copyWith(isAvailable: !doctor.isAvailable);

    await _firebaseService.updateDocument('doctors', id, {
      'isAvailable': updatedDoctor.isAvailable,
    });

    return updatedDoctor;
  }

  // Filter doctors by specialty
  Future<List<Doctor>> getDoctorsBySpecialty(String specialty) async {
    final snapshot = await _firebaseService.queryCollection('doctors', [
      QueryFilter(field: 'specialty', isEqualTo: specialty),
    ]);

    return snapshot.docs
        .map(
          (doc) => Doctor.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Search doctors by name
  Future<List<Doctor>> searchDoctors(String query) async {
    if (query.isEmpty) return getAllDoctors();

    final allDoctors = await getAllDoctors();
    final searchLower = query.toLowerCase();

    return allDoctors
        .where(
          (doctor) =>
              doctor.name.toLowerCase().contains(searchLower) ||
              doctor.specialty.toLowerCase().contains(searchLower),
        )
        .toList();
  }

  // Private helper methods
  Future<void> _validateDoctor(Doctor doctor, {bool isUpdate = false}) async {
    // Check for required fields
    if (doctor.name.isEmpty) {
      throw Exception('Doctor name cannot be empty');
    }

    if (doctor.specialty.isEmpty) {
      throw Exception('Specialty cannot be empty');
    }

    if (doctor.phoneNumber.isEmpty) {
      throw Exception('Phone number cannot be empty');
    }

    // Check for duplicate name (except for updates)
    if (!isUpdate) {
      final existingDocs = await _firebaseService.queryCollection('doctors', [
        QueryFilter(field: 'name', isEqualTo: doctor.name),
      ]);

      if (existingDocs.docs.isNotEmpty) {
        throw Exception('A doctor with this name already exists');
      }
    } else {
      // For updates, check if another doctor has the same name
      final existingDocs = await _firebaseService.queryCollection('doctors', [
        QueryFilter(field: 'name', isEqualTo: doctor.name),
      ]);

      for (var doc in existingDocs.docs) {
        if (doc.id != doctor.id) {
          throw Exception('Another doctor with this name already exists');
        }
      }
    }
  }
}
