import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../../../core/models/result.dart';
import '../model/appointment.dart';

final getAllAppointmentsProvider = FutureProvider<Result<List<Appointment>>>((
  ref,
) {
  final appointmentController = ref.watch(appointmentControllerProvider);
  return appointmentController.getAllAppointments();
});
