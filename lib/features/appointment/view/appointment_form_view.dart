import 'package:clinic_eye/core/views/widgets/common/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/dependencies.dart';
import '../../../core/models/result.dart';
import '../../doctor/model/doctor.dart';
import '../../doctor/provider/doctor_provider.dart';
import '../../patient/model/patient.dart';
import '../../patient/provider/patient_provider.dart';
import '../../slot/model/time_slot.dart';
import '../model/appointment.dart';
import '../provider/appointment_provider.dart';

// State provider for form data - makes state management clearer
final appointmentFormProvider = StateProvider.autoDispose<AppointmentFormData>(
  (ref) => AppointmentFormData(),
);

// Data class to hold form state
class AppointmentFormData {
  final String? patientId;
  final String? doctorId;
  final DateTime? date;
  final TimeSlot? timeSlot;
  final String notes;

  AppointmentFormData({
    this.patientId,
    this.doctorId,
    this.date,
    this.timeSlot,
    this.notes = '',
  });

  AppointmentFormData copyWith({
    String? patientId,
    String? doctorId,
    DateTime? date,
    TimeSlot? timeSlot,
    String? notes,
  }) {
    return AppointmentFormData(
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      notes: notes ?? this.notes,
    );
  }

  bool get isValid =>
      patientId != null && doctorId != null && date != null && timeSlot != null;
}

class AppointmentFormView extends ConsumerStatefulWidget {
  final String? appointmentId;

  const AppointmentFormView({super.key, this.appointmentId});

  @override
  ConsumerState<AppointmentFormView> createState() =>
      _AppointmentFormViewState();
}

class _AppointmentFormViewState extends ConsumerState<AppointmentFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  List<TimeSlot> _availableTimeSlots = [];
  Patient? _selectedPatient;

  @override
  void initState() {
    super.initState();

    // If editing existing appointment, load its data
    if (widget.appointmentId != null) {
      _loadAppointmentData();
    }
  }

  // Load existing appointment data
  Future<void> _loadAppointmentData() async {
    setState(() => _isLoading = true);

    try {
      final appointmentResult = await ref
          .read(appointmentControllerProvider)
          .getAppointmentById(widget.appointmentId!);

      if (appointmentResult.isSuccess && appointmentResult.data != null) {
        final appointment = appointmentResult.data!;
        final formData = ref.read(appointmentFormProvider.notifier);

        // Update form state
        formData.state = AppointmentFormData(
          patientId: appointment.patientId,
          doctorId: appointment.doctorId,
          date: appointment.dateTime,
          notes: appointment.notes ?? '',
        );

        // Update notes controller
        _notesController.text = appointment.notes ?? '';

        // Load time slots
        await _loadTimeSlots();

        // Find the selected time slot
        if (_availableTimeSlots.isNotEmpty) {
          TimeSlot? selectedSlot = _availableTimeSlots.firstWhere(
            (slot) => slot.id == appointment.timeSlotId,
            orElse: () => _availableTimeSlots.first,
          );

          // Update the time slot in the form data
          formData.state = formData.state.copyWith(timeSlot: selectedSlot);
        }
      }
    } catch (e) {
      _showMessage('Failed to load appointment data', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load available time slots for selected doctor and date
  Future<void> _loadTimeSlots() async {
    final formData = ref.read(appointmentFormProvider);

    if (formData.doctorId == null || formData.date == null) {
      setState(() => _availableTimeSlots = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(appointmentControllerProvider)
          .getAvailableTimeSlots(formData.doctorId!, formData.date!);

      if (result.isSuccess) {
        setState(() => _availableTimeSlots = result.data ?? []);
      } else {
        _showMessage('Failed to load time slots', isError: true);
      }
    } catch (e) {
      _showMessage('Error loading time slots', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Submit form - simplified with clear steps
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final formData = ref.read(appointmentFormProvider);
    if (!formData.isValid) {
      _showMessage('Please complete all required fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get detailed patient and doctor objects
      _selectedPatient = await _getPatientById(formData.patientId!);
      final doctor = await _getDoctorById(formData.doctorId!);

      if (_selectedPatient == null || doctor == null) {
        _showMessage('Could not find patient or doctor details', isError: true);
        return;
      }

      // Create appointment object
      final appointment = _createAppointmentObject(
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        doctorId: doctor.id,
        doctorName: doctor.name,
        formData: formData,
      );

      // Submit to backend
      final result = await _submitAppointment(appointment);

      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        // Handle successful submission
        _handleSuccessfulSubmission(result.data!);
      } else {
        _showMessage(
          result.errorMessage ?? 'Failed to save appointment',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Error processing appointment', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper method to get patient by ID
  Future<Patient?> _getPatientById(String patientId) async {
    final patientsResult = ref.read(getAllPatientsProvider).value;
    if (patientsResult == null || !patientsResult.isSuccess) return null;

    final patients = patientsResult.data ?? [];
    return patients.firstWhere(
      (p) => p.id == patientId,
      orElse: () => throw Exception('Patient not found'),
    );
  }

  // Helper method to get doctor by ID
  Future<Doctor?> _getDoctorById(String doctorId) async {
    final doctorsResult = ref.read(getAllDoctorsProvider).value;
    if (doctorsResult == null || !doctorsResult.isSuccess) return null;

    final doctors = doctorsResult.data ?? [];
    return doctors.firstWhere(
      (d) => d.id == doctorId,
      orElse: () => throw Exception('Doctor not found'),
    );
  }

  // Create appointment object
  Appointment _createAppointmentObject({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required AppointmentFormData formData,
  }) {
    return Appointment(
      id: widget.appointmentId ?? '',
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: doctorName,
      slotId: formData.timeSlot!.slotId,
      timeSlotId: formData.timeSlot!.id,
      dateTime: DateTime(
        formData.date!.year,
        formData.date!.month,
        formData.date!.day,
        formData.timeSlot!.startTime.hour,
        formData.timeSlot!.startTime.minute,
      ),
      status: AppointmentStatus.scheduled,
      paymentStatus: PaymentStatus.unpaid,
      notes: formData.notes.isNotEmpty ? formData.notes : null,
    );
  }

  // Submit appointment to backend
  Future<Result<Appointment>> _submitAppointment(
    Appointment appointment,
  ) async {
    final isEditing = widget.appointmentId != null;

    if (isEditing) {
      return ref
          .read(appointmentControllerProvider)
          .updateAppointment(appointment);
    } else {
      return ref
          .read(appointmentControllerProvider)
          .createAppointment(appointment);
    }
  }

  // Handle successful submission
  void _handleSuccessfulSubmission(Appointment appointment) {
    final isEditing = widget.appointmentId != null;

    // Refresh appointment list
    ref.invalidate(allAppointmentsProvider);

    // Show appointment success message
    _showMessage(
      isEditing
          ? 'Appointment updated successfully'
          : 'Appointment created successfully',
      isError: false,
    );

    // Process payment if needed
    if (!isEditing || appointment.paymentStatus == PaymentStatus.unpaid) {
      showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => ConfirmDialog(
              title: 'Appointment Confirmation',
              content: 'Do you want to proceed with the payment?',
              confirmText: 'Yes',
              cancelText: 'No',
              onConfirm: () async {
                await _processPayment(appointment);
              },
              onCancel: () {
                _showMessage(
                  'Appointment created without payment',
                  isError: false,
                );
                Navigator.of(dialogContext).pop();
              },
            ),
      );
    }

    // Clear form data
    ref.read(appointmentFormProvider.notifier).state = AppointmentFormData();
  }

  // Extract payment processing to a separate method
  Future<void> _processPayment(Appointment appointment) async {
    setState(() => _isLoading = true);

    try {
      // Create payment record
      final paymentResult = await ref
          .read(paymentControllerProvider)
          .createAndGeneratePayment(
            patientName: _selectedPatient!.name,
            patientMobile: _selectedPatient!.phone,
            appointmentId: appointment.id,
            amount: 25.0,
            patientId: _selectedPatient!.id,
            doctorId: appointment.doctorId,
          );

      if (!paymentResult.isSuccess) {
        _showMessage('Failed to create payment record', isError: true);
        return;
      }

      // Generate payment link
      final generateResult = await ref
          .read(paymentControllerProvider)
          .generatePaymentLink(
            paymentId: paymentResult.data!.id,
            patientName: appointment.patientName,
            patientMobile: _selectedPatient!.phone,
            amount: 25.0,
            currency: 'KWD',
          );

      if (!generateResult.isSuccess) {
        _showMessage('Failed to generate payment link', isError: true);
        return;
      }

      // Send payment link
      final sendResult = await ref
          .read(paymentControllerProvider)
          .sendPaymentLink(paymentId: paymentResult.data!.id);
      if (sendResult.isSuccess) {
        _showMessage(
          'Payment link generated and SMS sent successfully',
          isError: false,
        );
      }
    } catch (e) {
      _showMessage('Error processing payment: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Unified message display method
  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch form state from provider
    final formData = ref.watch(appointmentFormProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appointmentId != null
              ? 'Edit Appointment'
              : 'Book New Appointment',
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.appointmentId != null
                            ? 'Edit Appointment Details'
                            : 'Book New Appointment',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Divider(),
                      const SizedBox(height: 16.0),

                      // Patient Selection
                      _buildSectionTitle(context, 'Select Patient'),
                      _buildPatientDropdown(formData.patientId),
                      const SizedBox(height: 24.0),

                      // Doctor Selection
                      _buildSectionTitle(context, 'Select Doctor'),
                      _buildDoctorDropdown(formData.doctorId),
                      const SizedBox(height: 24.0),

                      // Date Selection
                      _buildSectionTitle(context, 'Select Date'),
                      _buildDatePicker(formData.date),
                      const SizedBox(height: 24.0),

                      // Time Slot Selection
                      if (formData.doctorId != null &&
                          formData.date != null) ...[
                        _buildSectionTitle(context, 'Select Time Slot'),
                        _buildTimeSlotSelection(formData.timeSlot),
                        const SizedBox(height: 24.0),
                      ],

                      // Notes
                      _buildSectionTitle(context, 'Notes'),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'Add any additional notes here...',
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          ref
                              .read(appointmentFormProvider.notifier)
                              .state = formData.copyWith(notes: value);
                        },
                      ),
                      const SizedBox(height: 32.0),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleSubmit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              widget.appointmentId != null
                                  ? 'Update Appointment'
                                  : 'Book Appointment',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  // Helper widget for section titles
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildPatientDropdown(String? selectedPatientId) {
    return Consumer(
      builder: (context, ref, child) {
        final patientsAsyncValue = ref.watch(getAllPatientsProvider);

        return patientsAsyncValue.when(
          data: (result) {
            if (!result.isSuccess) {
              return const Text('Failed to load patients');
            }

            final patients = result.data ?? [];
            if (patients.isEmpty) {
              return const Text('No patients available');
            }

            return DropdownButtonFormField<String>(
              value: selectedPatientId,
              decoration: InputDecoration(
                hintText: 'Select a patient',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items:
                  patients.map((patient) {
                    return DropdownMenuItem<String>(
                      value: patient.id,
                      child: Text(patient.name),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(appointmentFormProvider.notifier).state = ref
                      .read(appointmentFormProvider)
                      .copyWith(patientId: value);
                }
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('Error: $error'),
        );
      },
    );
  }

  Widget _buildDoctorDropdown(String? selectedDoctorId) {
    return Consumer(
      builder: (context, ref, child) {
        final doctorsAsyncValue = ref.watch(getAllDoctorsProvider);

        return doctorsAsyncValue.when(
          data: (result) {
            if (!result.isSuccess) {
              return const Text('Failed to load doctors');
            }

            final doctors = result.data ?? [];
            if (doctors.isEmpty) {
              return const Text('No doctors available');
            }

            // Filter available doctors
            final availableDoctors =
                doctors.where((doctor) => doctor.isAvailable).toList();
            if (availableDoctors.isEmpty) {
              return const Text('No available doctors');
            }

            return DropdownButtonFormField<String>(
              value: selectedDoctorId,
              decoration: InputDecoration(
                hintText: 'Select a doctor',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items:
                  availableDoctors.map((doctor) {
                    return DropdownMenuItem<String>(
                      value: doctor.id,
                      child: Text('${doctor.name} (${doctor.specialty})'),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  // Update form data
                  ref.read(appointmentFormProvider.notifier).state = ref
                      .read(appointmentFormProvider)
                      .copyWith(doctorId: value, timeSlot: null);

                  // Load time slots if date is selected
                  final formData = ref.read(appointmentFormProvider);
                  if (formData.date != null) {
                    _loadTimeSlots();
                  }
                }
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('Error: $error'),
        );
      },
    );
  }

  Widget _buildDatePicker(DateTime? selectedDate) {
    final formatter = DateFormat('EEEE, MMMM d, yyyy');

    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );

        if (picked != null && picked != selectedDate) {
          // Update form data
          ref.read(appointmentFormProvider.notifier).state = ref
              .read(appointmentFormProvider)
              .copyWith(date: picked, timeSlot: null);

          // Load time slots if doctor is selected
          final formData = ref.read(appointmentFormProvider);
          if (formData.doctorId != null) {
            _loadTimeSlots();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate != null
                  ? formatter.format(selectedDate)
                  : 'Select a date',
            ),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotSelection(TimeSlot? selectedTimeSlot) {
    if (_availableTimeSlots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No available time slots for selected date and doctor',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children:
          _availableTimeSlots.map((slot) {
            final isSelected = selectedTimeSlot?.id == slot.id;
            final startTime = slot.startTime;
            final endTime = slot.endTime;

            return ChoiceChip(
              label: Text(
                '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}',
              ),
              selected: isSelected,
              onSelected:
                  slot.isAvailable
                      ? (selected) {
                        if (selected) {
                          ref.read(appointmentFormProvider.notifier).state = ref
                              .read(appointmentFormProvider)
                              .copyWith(timeSlot: slot);
                        }
                      }
                      : null,
              backgroundColor: Colors.grey[200],
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color:
                    isSelected
                        ? Colors.white
                        : slot.isAvailable
                        ? Colors.black
                        : Colors.grey,
              ),
            );
          }).toList(),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour =
        time.hour == 0
            ? 12
            : time.hour > 12
            ? time.hour - 12
            : time.hour;

    final minute = time.minute < 10 ? '0${time.minute}' : '${time.minute}';
    final period = time.hour < 12 ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
