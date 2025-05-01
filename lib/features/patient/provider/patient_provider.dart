import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../../../core/models/result.dart';
import '../model/patient.dart';

final getAllPatientsProvider = FutureProvider<Result<List<Patient>>>((ref) {
  final patientController = ref.watch(patientControllerProvider);
  return patientController.getAllPatients();
});

final updatePatientProvider = FutureProvider.family<Result<Patient>, Patient>((
  ref,
  patient,
) {
  final patientController = ref.watch(patientControllerProvider);
  return patientController.updatePatient(patient);
});

final addPatientProvider = FutureProvider.family<Result<Patient>, Patient>((
  ref,
  patient,
) {
  final patientController = ref.watch(patientControllerProvider);
  return patientController.addPatient(patient);
});
