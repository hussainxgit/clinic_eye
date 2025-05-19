import 'package:clinic_eye/core/models/result.dart';
import 'package:clinic_eye/core/views/widgets/common/confirm_dialog.dart';
import 'package:clinic_eye/features/appointment/model/appointment.dart'
    as appointment_model;
import 'package:clinic_eye/features/appointment/provider/appointment_provider.dart';
import 'package:clinic_eye/features/appointment/view/appointment_form_view.dart';
import 'package:clinic_eye/features/patient/model/patient.dart';
import 'package:clinic_eye/features/payment/model/payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/dependencies.dart';
import '../../patient/provider/patient_provider.dart';
import '../model/appointment.dart' hide PaymentStatus;

// Extensions for AppointmentStatus
extension AppointmentStatusX on appointment_model.AppointmentStatus {
  Color get color {
    switch (this) {
      case appointment_model.AppointmentStatus.scheduled:
        return Colors.blue;
      case appointment_model.AppointmentStatus.completed:
        return Colors.green;
      case appointment_model.AppointmentStatus.cancelled:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case appointment_model.AppointmentStatus.scheduled:
        return Icons.schedule;
      case appointment_model.AppointmentStatus.completed:
        return Icons.check_circle;
      case appointment_model.AppointmentStatus.cancelled:
        return Icons.cancel;
    }
  }

  String get description {
    switch (this) {
      case appointment_model.AppointmentStatus.scheduled:
        return 'This appointment is scheduled and confirmed';
      case appointment_model.AppointmentStatus.completed:
        return 'This appointment has been completed';
      case appointment_model.AppointmentStatus.cancelled:
        return 'This appointment has been cancelled';
    }
  }
}

// Extensions for PaymentStatus
extension PaymentStatusX on PaymentStatus {
  Color get color {
    switch (this) {
      case PaymentStatus.successful:
        return Colors.green;
      case PaymentStatus.failed:
      case PaymentStatus.cancelled:
        return Colors.red;
      case PaymentStatus.refunded:
        return Colors.amber;
      case PaymentStatus.pending:
        return Colors.blue;
    }
  }
}

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
    final querySnapshot =
        await ref
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
            onPressed:
                () => _navigateToEditAppointment(context, ref, appointmentId),
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
    final patientAsync = ref.watch(
      appointmentPatientProvider(appointment.patientId),
    );
    final paymentAsync = ref.watch(appointmentPaymentProvider(appointment.id));
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(context, appointment),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointment Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(dateFormat.format(appointment.dateTime)),
                          ],
                        ),
                      ),
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(timeFormat.format(appointment.dateTime)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.medical_services, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(appointment.doctorName),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (appointment.notes != null &&
                      appointment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(appointment.notes!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          patientAsync.when(
            data:
                (patient) =>
                    patient != null
                        ? _buildPatientCard(context, patient)
                        : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Patient information not available'),
                          ),
                        ),
            loading:
                () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            error:
                (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error loading patient: $error'),
                  ),
                ),
          ),
          const SizedBox(height: 24),
          paymentAsync.when(
            data:
                (payment) =>
                    payment != null
                        ? _buildPaymentCard(context, ref, payment, appointment)
                        : _buildNoPaymentCard(context, ref, appointment),
            loading:
                () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            error:
                (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error loading payment: $error'),
                  ),
                ),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(context, ref, appointment),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    appointment_model.Appointment appointment,
  ) {
    final statusColor = appointment.status.color;
    final statusIcon = appointment.status.icon;
    final statusDescription = appointment.status.description;

    return Card(
      elevation: 3,
      color: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, size: 36, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${appointment.status.name.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color:
                    appointment.paymentStatus ==
                            appointment_model.PaymentStatus.paid
                        ? Colors.green
                        : Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                appointment.paymentStatus ==
                        appointment_model.PaymentStatus.paid
                    ? 'PAID'
                    : 'UNPAID',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      patient.avatarUrl != null
                          ? NetworkImage(patient.avatarUrl!)
                          : null,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child:
                      patient.avatarUrl == null
                          ? Text(patient.name[0].toUpperCase())
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16),
                          const SizedBox(width: 4),
                          Text(patient.phone),
                        ],
                      ),
                      if (patient.email != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 16),
                            const SizedBox(width: 4),
                            Text(patient.email!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    WidgetRef ref,
    Payment payment,
    appointment_model.Appointment appointment,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final statusColor = payment.status.color;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount', style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${payment.amount.toStringAsFixed(3)} ${payment.currency}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status', style: Theme.of(context).textTheme.titleSmall),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Method',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(payment.paymentMethod.toUpperCase()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Created', style: Theme.of(context).textTheme.titleSmall),
                Text(dateFormat.format(payment.createdAt)),
              ],
            ),
            if (payment.completedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Completed',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(dateFormat.format(payment.completedAt!)),
                ],
              ),
            ],
            if (payment.status == PaymentStatus.pending &&
                payment.paymentLink != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          () => _resendPaymentLink(context, ref, payment),
                      icon: const Icon(Icons.send),
                      label: const Text('Resend Payment Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          () => _checkPaymentStatus(context, ref, payment),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Payment Status'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoPaymentCard(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text('No payment information found for this appointment.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _createPayment(context, ref, appointment),
              icon: const Icon(Icons.payment),
              label: const Text('Create Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) {
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
                    onPressed:
                        () => _confirmCancelAppointment(
                          context,
                          ref,
                          appointment,
                        ),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Cancel Appointment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                if (canComplete)
                  OutlinedButton.icon(
                    onPressed:
                        () => _markAsCompleted(context, ref, appointment),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Completed'),
                  ),
                if (canSendReminder)
                  OutlinedButton.icon(
                    onPressed:
                        () => _sendReminderSms(context, ref, appointment),
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

  void _confirmCancelAppointment(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => ConfirmDialog(
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
      ref.invalidate(appointmentDetailsProvider(appointmentId));
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
      ref.invalidate(appointmentDetailsProvider(appointmentId));
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

  Future<void> _createPayment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    // Show loading indicator

    final loadingOverlay = _showLoadingOverlay(context);

    try {
      // Get patient information
      final patient = await _getPatientInfo(ref, appointment.patientId);
      if (patient == null) {
        _dismissLoadingOverlay(loadingOverlay);
        if (!context.mounted) return;
        _showErrorMessage(context, 'Patient information not available');
        return;
      }

      // Create payment
      final payment = await _processPayment(ref, appointment, patient).then((
        result,
      ) {
        if (result.isSuccess) {
          return result.data!;
        } else {
          if (!context.mounted) return null;
          _showErrorMessage(context, 'Error: ${result.errorMessage}');
          return null;
        }
      });

      // Send payment link via SMS
      if (!context.mounted) return;
      final success = await _sendPaymentLink(
        ref,
        context,
        payment!,
        patient.name,
      );

      // Refresh payment provider to update UI
      ref.invalidate(appointmentPaymentProvider(appointment.id));

      _dismissLoadingOverlay(loadingOverlay);

      if (success) {
        if (!context.mounted) return;
        _showSuccessMessage(context, 'Payment link sent to ${patient.name}');
      }
    } catch (e) {
      _dismissLoadingOverlay(loadingOverlay);
      if (!context.mounted) return;
      _showErrorMessage(context, 'Error: $e');
    }
  }

  // Get patient information
  Future<Patient?> _getPatientInfo(WidgetRef ref, String patientId) async {
    return await ref.read(appointmentPatientProvider(patientId).future);
  }

  // Process payment creation
  Future<Result<Payment>> _processPayment(
    WidgetRef ref,
    Appointment appointment,
    Patient patient,
  ) async {
    final paymentResult = await ref
        .read(paymentControllerProvider)
        .createAndGeneratePayment(
          patientName: patient.name,
          patientMobile: patient.phone,
          appointmentId: appointment.id,
          patientId: appointment.patientId,
          doctorId: appointment.doctorId,
          amount: 25.0, // Consider making this configurable
        );

    if (!paymentResult.isSuccess || paymentResult.data == null) {
      if (!ref.context.mounted) return Result.error('widget not mounted');
      _showErrorMessage(ref.context, 'Error: ${paymentResult.errorMessage}');
      return Result.error('Error: ${paymentResult.errorMessage}');
    }

    return Result.success(paymentResult.data);
  }

  // Send payment link via SMS
  Future<bool> _sendPaymentLink(
    WidgetRef ref,
    BuildContext context,
    Payment payment,
    String patientName,
  ) async {
    if (!context.mounted) return false;

    final sendLinkResult = await ref
        .read(paymentControllerProvider)
        .sendPaymentLink(payment: payment);

    if (!context.mounted) return false;

    if (!sendLinkResult.isSuccess) {
      _showErrorMessage(context, 'Failed to send payment link');
      return false;
    }

    return true;
  }

  // Show loading overlay
  OverlayEntry _showLoadingOverlay(BuildContext context) {
    final overlay = OverlayEntry(
      builder:
          (context) => Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
    );

    Overlay.of(context).insert(overlay);
    return overlay;
  }

  // Dismiss loading overlay
  void _dismissLoadingOverlay(OverlayEntry loadingOverlay) {
    loadingOverlay.remove();
  }

  // Show error message
  void _showErrorMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Show success message
  void _showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _resendPaymentLink(
    BuildContext context,
    WidgetRef ref,
    Payment payment,
  ) async {
    try {
      final result = await ref
          .read(paymentControllerProvider)
          .sendPaymentLink(payment: payment);
      if (!context.mounted) return;
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment link resent successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result.errorMessage}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _checkPaymentStatus(
    BuildContext context,
    WidgetRef ref,
    Payment payment,
  ) async {
    print('Checking payment status for payment ID: ${payment.id}');
    try {
      final status = await ref
          .read(paymentControllerProvider)
          .checkPaymentStatus(payment.id);
      if (!context.mounted) return;
      if (status.isSuccess) {
        ref.invalidate(appointmentPaymentProvider(payment.appointmentId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment status: ${status.data.toString()}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${status.errorMessage}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking payment status: $e')),
        );
        print('Error checking payment status: $e');
      }
    }
  }
}
