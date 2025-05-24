import 'package:clinic_eye/features/patient/model/patient.dart';
import 'package:clinic_eye/features/patient/provider/patient_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class PatientCard extends ConsumerWidget {
  final String patientId;

  const PatientCard({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(appointmentPatientProvider(patientId));

    return patientAsync.when(
      data: (patient) => patient != null
          ? _buildPatientInfo(context, patient)
          : const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Patient information not available'),
              ),
            ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading patient: $error'),
        ),
      ),
    );
  }

  Widget _buildPatientInfo(BuildContext context, Patient patient) {
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
                  backgroundImage: patient.avatarUrl != null
                      ? NetworkImage(patient.avatarUrl!)
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: patient.avatarUrl == null
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
}
