import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/features/appointment/model/appointment.dart'
    as appointment_model;
import 'package:clinic_eye/features/appointment/view/appointment_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/dependencies.dart';
import 'action_buttons.dart';
import 'appointment_info_card.dart';
import 'patient_card.dart';
import 'payment_card.dart';

// Provider to fetch appointment details
final appointmentDetailsProvider =
    FutureProvider.family<Result<appointment_model.Appointment>, String>((
      ref,
      appointmentId,
    ) {
      final appointmentController = ref.watch(appointmentControllerProvider);
      return appointmentController.getAppointmentById(appointmentId);
    });

class AppointmentDetailsView extends ConsumerWidget {
  final String appointmentId;

  const AppointmentDetailsView({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(
      appointmentDetailsProvider(appointmentId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Appointment',
            onPressed: () =>
                _navigateToEditAppointment(context, ref, appointmentId),
          ),
        ],
      ),
      body: appointmentAsync.when(
        data: (result) {
          if (!result.isSuccess) {
            return Center(child: Text('Error: ${result.errorMessage}'));
          }
          final appointment = result.data!;
          return _buildAppointmentDetails(context, ref, appointment);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildAppointmentDetails(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppointmentInfoCard(appointment: appointment),
          const SizedBox(height: 24),
          PatientCard(patientId: appointment.patientId),
          const SizedBox(height: 24),
          PaymentCard(appointment: appointment),
          const SizedBox(height: 24),
          ActionButtons(appointment: appointment),
        ],
      ),
    );
  }

  void _navigateToEditAppointment(
    BuildContext context,
    WidgetRef ref,
    String appointmentId,
  ) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AppointmentFormView(appointmentId: appointmentId),
          ),
        )
        .then((_) => ref.invalidate(appointmentDetailsProvider(appointmentId)));
  }
}
