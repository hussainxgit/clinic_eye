import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../../../core/models/result.dart';
import '../model/doctor.dart';

final getAllDoctorsProvider = FutureProvider<Result<List<Doctor>>>((ref) {
  final doctorController = ref.watch(doctorControllerProvider);
  return doctorController.getAllDoctors();
});

final updateDoctorProvider = FutureProvider.family<Result<Doctor>, Doctor>((
  ref,
  doctor,
) {
  final doctorController = ref.watch(doctorControllerProvider);
  return doctorController.updateDoctor(doctor);
});

final addDoctorProvider = FutureProvider.family<Result<Doctor>, Doctor>((
  ref,
  doctor,
) {
  final doctorController = ref.watch(doctorControllerProvider);
  return doctorController.addDoctor(doctor);
});
