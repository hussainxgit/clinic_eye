import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../model/patient.dart';
import '../provider/patient_provider.dart';

class PatientFormScreen extends ConsumerWidget {
  final Patient? patient;
  final bool isEditing;

  const PatientFormScreen({super.key, this.patient, this.isEditing = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController(
      text: patient?.name ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: patient?.phone ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: patient?.email ?? '',
    );
    final TextEditingController addressController = TextEditingController(
      text: patient?.address ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: patient?.notes ?? '',
    );

    // Gender selection
    final ValueNotifier<PatientGender> selectedGender = ValueNotifier(
      patient?.gender ?? PatientGender.male,
    );

    // Status selection
    final ValueNotifier<PatientStatus> selectedStatus = ValueNotifier(
      patient?.status ?? PatientStatus.active,
    );

    // Date of birth
    final ValueNotifier<DateTime?> selectedDate = ValueNotifier(
      patient?.dateOfBirth,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Patient' : 'Add New Patient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Patient Details' : 'Add New Patient',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const Divider(),
              const SizedBox(height: 16.0),

              // Personal Information Section
              Text(
                'Personal Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16.0),

              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12.0),

              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number *'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12.0),

              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12.0),

              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 20.0),

              // Gender Selection
              Text('Gender', style: Theme.of(context).textTheme.titleMedium),
              ValueListenableBuilder<PatientGender>(
                valueListenable: selectedGender,
                builder: (context, gender, _) {
                  return Row(
                    children: [
                      Radio<PatientGender>(
                        value: PatientGender.male,
                        groupValue: gender,
                        onChanged: (value) {
                          selectedGender.value = PatientGender.male;
                        },
                      ),
                      const Text('Male'),
                      const SizedBox(width: 24.0),
                      Radio<PatientGender>(
                        value: PatientGender.female,
                        groupValue: gender,
                        onChanged: (value) {
                          selectedGender.value = PatientGender.female;
                        },
                      ),
                      const Text('Female'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16.0),

              // Date of Birth
              Text(
                'Date of Birth',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8.0),
              ValueListenableBuilder<DateTime?>(
                valueListenable: selectedDate,
                builder: (context, date, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          date != null
                              ? DateFormat('MMMM d, yyyy').format(date)
                              : 'Not set',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            selectedDate.value = picked;
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(date != null ? 'Change' : 'Select'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20.0),

              // Status Selection (only for editing)
              if (isEditing) ...[
                Text(
                  'Patient Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ValueListenableBuilder<PatientStatus>(
                  valueListenable: selectedStatus,
                  builder: (context, status, _) {
                    return Row(
                      children: [
                        Radio<PatientStatus>(
                          value: PatientStatus.active,
                          groupValue: status,
                          onChanged: (value) {
                            selectedStatus.value = PatientStatus.active;
                          },
                        ),
                        const Text('Active'),
                        const SizedBox(width: 24.0),
                        Radio<PatientStatus>(
                          value: PatientStatus.inactive,
                          groupValue: status,
                          onChanged: (value) {
                            selectedStatus.value = PatientStatus.inactive;
                          },
                        ),
                        const Text('Inactive'),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16.0),
              ],

              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 24.0),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final patientData = Patient(
                        id: patient?.id ?? '',
                        name: nameController.text,
                        phone: phoneController.text,
                        email:
                            emailController.text.isNotEmpty
                                ? emailController.text
                                : null,
                        address:
                            addressController.text.isNotEmpty
                                ? addressController.text
                                : null,
                        gender: selectedGender.value,
                        dateOfBirth: selectedDate.value,
                        registeredAt: patient?.registeredAt ?? DateTime.now(),
                        status: selectedStatus.value,
                        notes:
                            notesController.text.isNotEmpty
                                ? notesController.text
                                : null,
                        avatarUrl: patient?.avatarUrl,
                      );
                      if (isEditing) {
                        final result = await ref.read(
                          updatePatientProvider(patientData).future,
                        );
                        if (!context.mounted) {
                          return; // Guard with mounted check
                        }
                        if (result.isSuccess) {
                          // Success handling
                          ref.invalidate(getAllPatientsProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Patient updated successfully'),
                            ),
                          );
                        } else {
                          // Error handling
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${result.errorMessage}'),
                            ),
                          );
                        }
                      } else {
                        final result = await ref.read(
                          addPatientProvider(patientData).future,
                        );
                        if (!context.mounted) {
                          return; // Guard with mounted check
                        }
                        if (result.isSuccess) {
                          // Success handling
                          ref.invalidate(getAllPatientsProvider);
                          // Clear the form fields after submission
                          formKey.currentState?.reset();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Patient added successfully'),
                            ),
                          );
                        } else {
                          // Error handling
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${result.errorMessage}'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Text(isEditing ? 'Update Patient' : 'Add Patient'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
