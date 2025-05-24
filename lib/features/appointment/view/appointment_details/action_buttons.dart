import 'package:clinic_eye/features/appointment/model/appointment.dart'
    as appointment_model;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/dependencies.dart';
import '../../../../core/models/result.dart';
import '../../../../core/views/widgets/common/confirm_dialog.dart';
import '../../../patient/model/patient.dart';
import '../../../patient/provider/patient_provider.dart';
import '../../../payment/model/payment.dart';
import '../../provider/appointment_provider.dart';

class ActionButtons extends ConsumerWidget {
  final appointment_model.Appointment appointment;

  ActionButtons({super.key, required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canCancel =
        appointment.status == appointment_model.AppointmentStatus.scheduled;
    final bool canComplete =
        appointment.status == appointment_model.AppointmentStatus.scheduled;
    final bool canSendReminder =
        appointment.status == appointment_model.AppointmentStatus.scheduled;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _confirmCancelAppointment(context, ref, appointment),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancel Appointment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                if (canComplete)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _markAsCompleted(context, ref, appointment),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Completed'),
                  ),
                if (canSendReminder)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _sendReminderSms(context, ref, appointment),
                    icon: const Icon(Icons.message),
                    label: const Text('Send Reminder SMS'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (All the action button logic, including _confirmCancelAppointment,
  // _cancelAppointment, _markAsCompleted, and _sendReminderSms would be
  // moved here from the original file)
  // Provider to fetch appointment details
  final appointmentDetailsProvider =
      FutureProvider.family<Result<appointment_model.Appointment>, String>((
        ref,
        appointmentId,
      ) {
        final appointmentController = ref.watch(appointmentControllerProvider);
        return appointmentController.getAppointmentById(appointmentId);
      });

  // Provider to fetch patient details for the appointment
  final appointmentPatientProvider = FutureProvider.family<Patient?, String>((
    ref,
    patientId,
  ) async {
    final patientsResult = ref.watch(getAllPatientsProvider).value;
    if (patientsResult == null || !patientsResult.isSuccess) return null;

    final patients = patientsResult.data ?? [];
    try {
      return patients.firstWhere((p) => p.id == patientId);
    } catch (e) {
      return null;
    }
  });

  // Provider to fetch payment details for the appointment
  final appointmentPaymentProvider = FutureProvider.family<Payment?, String>((
    ref,
    appointmentId,
  ) async {
    try {
      final querySnapshot = await ref
          .read(firebaseServiceProvider)
          .firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: appointmentId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final doc = querySnapshot.docs.first;
      return Payment.fromMap(doc.data(), doc.id);
    } catch (e) {
      print('Error fetching payment: $e');
      return null;
    }
  });

  void _confirmCancelAppointment(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Cancel Appointment',
        content:
            'Are you sure you want to cancel this appointment? This action cannot be undone.',
        confirmText: 'Yes, Cancel',
        cancelText: 'No, Keep',
        onConfirm: () {
          Navigator.of(context).pop();
          _cancelAppointment(context, ref, appointment);
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _cancelAppointment(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) async {
    final result = await ref
        .read(appointmentControllerProvider)
        .cancelAppointment(appointment.id);
    if (!context.mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled successfully')),
      );
      ref.invalidate(appointmentDetailsProvider(appointment.id));
      ref.invalidate(allAppointmentsProvider);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${result.errorMessage}')));
    }
  }

  Future<void> _markAsCompleted(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) async {
    final updatedAppointment = appointment.copyWith(
      status: appointment_model.AppointmentStatus.completed,
      updatedAt: DateTime.now(),
    );
    final result = await ref
        .read(appointmentControllerProvider)
        .updateAppointment(updatedAppointment);
    if (!context.mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment marked as completed')),
      );
      ref.invalidate(appointmentDetailsProvider(appointment.id));
      ref.invalidate(allAppointmentsProvider);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${result.errorMessage}')));
    }
  }

  Future<void> _sendReminderSms(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) async {
    final patientAsync = await ref.read(
      appointmentPatientProvider(appointment.patientId).future,
    );
    if (patientAsync == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient information not available')),
        );
      }
      return;
    }
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final message =
        'Dear ${patientAsync.name}, this is a reminder for your appointment on '
        '${dateFormat.format(appointment.dateTime)} at ${timeFormat.format(appointment.dateTime)} '
        'with Dr. ${appointment.doctorName}. Please arrive 10 minutes early.';
    try {
      final result = await ref
          .read(messegingControllerProvider)
          .sendSms(phoneNumber: patientAsync.phone, message: message);
      if (!context.mounted) return;
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder SMS sent successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reminder SMS')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending SMS: $e')));
      }
    }
  }
}
