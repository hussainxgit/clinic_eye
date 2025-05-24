import 'package:clinic_eye/core/config/dependencies.dart';
import 'package:clinic_eye/features/appointment/model/appointment.dart'
    as appointment_model;
import 'package:clinic_eye/features/messaging/services/kwt_sms_service.dart';
import 'package:clinic_eye/features/patient/model/patient.dart';
import 'package:clinic_eye/features/patient/provider/patient_provider.dart';
import 'package:clinic_eye/features/payment/model/payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/result.dart';

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

class PaymentCard extends ConsumerWidget {
  final appointment_model.Appointment appointment;

  PaymentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(appointmentPaymentProvider(appointment.id));

    return paymentAsync.when(
      data: (payment) => payment != null
          ? _buildPaymentDetails(context, ref, payment)
          : _buildNoPaymentCard(context, ref, appointment),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading payment: $error'),
        ),
      ),
    );
  }

  // ... (Rest of the payment card logic, including _buildPaymentDetails,
  // _buildNoPaymentCard, _createPayment, _checkPaymentStatus and helper methods
  // would be moved here from the original file)
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

  Future<void> _createPayment(
    BuildContext context,
    WidgetRef ref,
    appointment_model.Appointment appointment,
  ) async {
    final loadingOverlay = _showLoadingOverlay(context);
    final patient = await _getPatientInfo(ref, appointment.patientId);
    if (patient == null) {
      _dismissLoadingOverlay(loadingOverlay);
      _showErrorMessage(context, 'Patient information not available');
      return;
    }

    final generatePaymentLinkResult = await ref
        .read(paymentControllerProvider)
        .generatePaymentLink(
          patientId: appointment.patientId,
          doctorId: appointment.doctorId,
          customerName: appointment.patientName,
          customerMobile: patient.phone,
          appointmentId: appointment.id,
          amount: 25.0,
        );
    if (!context.mounted) return;
    final sendLinkResult = await ref
        .read(kwtSmsServiceProvider)
        .sendAppointmentPayment(
          mobileNumber: patient.phone,
          patientName: patient.name,
          appointmentDate: appointment.dateTime,
          paymentLink: generatePaymentLinkResult.data!.paymentLink!,
          amount: generatePaymentLinkResult.data!.amount,
        );

    if (sendLinkResult.isError) {
      _dismissLoadingOverlay(loadingOverlay);
      if (!context.mounted) return;
      _showErrorMessage(
        context,
        'Failed to send payment link: ${sendLinkResult.errorMessage}',
      );
      return;
    }

    _dismissLoadingOverlay(loadingOverlay);
    if (!context.mounted) return;
    _showSuccessMessage(context, 'Payment link sent successfully');
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
          .checkPaymentStatus(paymentId: payment.id);
      if (!context.mounted) return;
      if (status.isSuccess) {
        ref.invalidate(appointmentPaymentProvider(payment.appointmentId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment status: ${status.data!.status.name}'),
          ),
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

  // Show loading overlay
  OverlayEntry _showLoadingOverlay(BuildContext context) {
    final overlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    Overlay.of(context).insert(overlay);
    return overlay;
  }

  // Get patient information
  Future<Patient?> _getPatientInfo(WidgetRef ref, String patientId) async {
    return await ref.read(appointmentPatientProvider(patientId).future);
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

  _buildPaymentDetails(BuildContext context, WidgetRef ref, Payment payment) {
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
            Text('Amount: \$${payment.amount.toStringAsFixed(2)}'),
            Text('Status: ${payment.status.name}'),
            Text('Created At: ${DateFormat.yMMMd().format(payment.createdAt)}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _checkPaymentStatus(context, ref, payment),
              icon: const Icon(Icons.refresh),
              label: const Text('Check Payment Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
