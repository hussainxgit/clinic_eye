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

class AppointmentFormView extends ConsumerStatefulWidget {
  final String? appointmentId;

  const AppointmentFormView({super.key, this.appointmentId});

  @override
  ConsumerState<AppointmentFormView> createState() =>
      _AppointmentFormViewState();
}

class _AppointmentFormViewState extends ConsumerState<AppointmentFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Form field controllers
  String? _selectedPatientId;
  String? _selectedDoctorId;
  DateTime? _selectedDate;
  TimeSlot? _selectedTimeSlot;
  final TextEditingController _notesController = TextEditingController();

  // States
  bool _isLoading = false;
  bool _isEditing = false;
  List<TimeSlot> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.appointmentId != null;

    // If editing, load appointment data
    if (_isEditing) {
      _loadAppointmentData();
    }
  }

  Future<void> _loadAppointmentData() async {
    setState(() => _isLoading = true);

    try {
      final appointmentResult = await ref
          .read(appointmentControllerProvider)
          .getAppointmentById(widget.appointmentId!);

      if (appointmentResult.isSuccess && appointmentResult.data != null) {
        final appointment = appointmentResult.data!;

        setState(() {
          _selectedPatientId = appointment.patientId;
          _selectedDoctorId = appointment.doctorId;
          _selectedDate = appointment.dateTime;
          _notesController.text = appointment.notes ?? '';
        });

        // Load available time slots for the selected date and doctor
        await _loadTimeSlots();

        // Find the selected time slot
        _selectedTimeSlot = _availableTimeSlots.firstWhere(
          (slot) => slot.id == appointment.timeSlotId,
          orElse:
              () =>
                  _availableTimeSlots.isNotEmpty
                      ? _availableTimeSlots.first
                      : throw Exception('No available time slots'),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load appointment data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTimeSlots() async {
    if (_selectedDoctorId == null || _selectedDate == null) {
      setState(() => _availableTimeSlots = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final timeSlotsResult = await ref
          .read(appointmentControllerProvider)
          .getAvailableTimeSlots(_selectedDoctorId!, _selectedDate!);

      if (timeSlotsResult.isSuccess) {
        setState(() => _availableTimeSlots = timeSlotsResult.data ?? []);
      } else {
        print(timeSlotsResult.errorMessage);

        _showErrorSnackBar(
          'Failed to load time slots: ${timeSlotsResult.errorMessage}',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load time slots: ${e.toString()}');
      print(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPatientId == null) {
      _showErrorSnackBar('Please select a patient');
      return;
    }

    if (_selectedDoctorId == null) {
      _showErrorSnackBar('Please select a doctor');
      return;
    }

    if (_selectedDate == null) {
      _showErrorSnackBar('Please select a date');
      return;
    }

    if (_selectedTimeSlot == null) {
      _showErrorSnackBar('Please select a time slot');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patientsAsyncValue = ref.read(getAllPatientsProvider);
      final doctorsAsyncValue = ref.read(getAllDoctorsProvider);

      if (patientsAsyncValue.value == null || doctorsAsyncValue.value == null) {
        _showErrorSnackBar('Failed to load patient or doctor data');
        return;
      }

      final patients = patientsAsyncValue.value!.data ?? [];
      final doctors = doctorsAsyncValue.value!.data ?? [];

      final patient = patients.firstWhere(
        (p) => p.id == _selectedPatientId,
        orElse: () => throw Exception('Patient not found'),
      );

      final doctor = doctors.firstWhere(
        (d) => d.id == _selectedDoctorId,
        orElse: () => throw Exception('Doctor not found'),
      );

      // Create appointment object
      final appointment = Appointment(
        id: widget.appointmentId ?? '',
        patientId: patient.id,
        patientName: patient.name,
        doctorId: doctor.id,
        doctorName: doctor.name,
        slotId: _selectedTimeSlot!.slotId,
        timeSlotId: _selectedTimeSlot!.id,
        dateTime: DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTimeSlot!.startTime.hour,
          _selectedTimeSlot!.startTime.minute,
        ),
        status: AppointmentStatus.scheduled,
        paymentStatus: PaymentStatus.unpaid,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      Result<Appointment> result;

      if (_isEditing) {
        // Update existing appointment
        result = await ref
            .read(appointmentControllerProvider)
            .updateAppointment(appointment);
      } else {
        // Create new appointment
        result = await ref
            .read(appointmentControllerProvider)
            .createAppointment(appointment);
      }

      if (!mounted) return;

      if (result.isSuccess) {
        // Invalidate providers to refresh data
        ref.invalidate(allAppointmentsProvider);

        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Appointment updated successfully'
                  : 'Appointment created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Create payment record if needed
        if (!_isEditing || appointment.paymentStatus == PaymentStatus.unpaid) {
          _createPaymentRecord(result.data!);
        }

        Navigator.of(context).pop();
      } else {
        _showErrorSnackBar(result.errorMessage ?? 'Failed to save appointment');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPaymentRecord(Appointment appointment) async {
    try {
      final paymentResult = await ref
          .read(appointmentControllerProvider)
          .createPaymentForAppointment(appointment);

      if (!paymentResult.isSuccess) {
        // Just log the error, don't block the flow
        print('Failed to create payment: ${paymentResult.errorMessage}');
      }
    } catch (e) {
      print('Error creating payment: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsyncValue = ref.watch(getAllPatientsProvider);
    final doctorsAsyncValue = ref.watch(getAllDoctorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Appointment' : 'Book New Appointment'),
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
                        _isEditing
                            ? 'Edit Appointment Details'
                            : 'Book New Appointment',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Divider(),
                      const SizedBox(height: 16.0),

                      // Patient Selection
                      Text(
                        'Select Patient',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8.0),
                      _buildPatientDropdown(patientsAsyncValue),
                      const SizedBox(height: 24.0),

                      // Doctor Selection
                      Text(
                        'Select Doctor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8.0),
                      _buildDoctorDropdown(doctorsAsyncValue),
                      const SizedBox(height: 24.0),

                      // Date Selection
                      Text(
                        'Select Date',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8.0),
                      _buildDatePicker(),
                      const SizedBox(height: 24.0),

                      // Time Slot Selection
                      if (_selectedDoctorId != null &&
                          _selectedDate != null) ...[
                        Text(
                          'Select Time Slot',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8.0),
                        _buildTimeSlotSelection(),
                        const SizedBox(height: 24.0),
                      ],

                      // Notes
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'Add any additional notes here...',
                        ),
                        maxLines: 3,
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
                              _isEditing
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

  Widget _buildPatientDropdown(
    AsyncValue<Result<List<Patient>>> patientsAsyncValue,
  ) {
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
          value: _selectedPatientId,
          decoration: InputDecoration(
            hintText: 'Select a patient',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items:
              patients.map((patient) {
                return DropdownMenuItem<String>(
                  value: patient.id,
                  child: Text(patient.name),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedPatientId = value;
            });
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Text('Error: $error'),
    );
  }

  Widget _buildDoctorDropdown(
    AsyncValue<Result<List<Doctor>>> doctorsAsyncValue,
  ) {
    return doctorsAsyncValue.when(
      data: (result) {
        if (!result.isSuccess) {
          return const Text('Failed to load doctors');
        }

        final doctors = result.data ?? [];
        if (doctors.isEmpty) {
          return const Text('No doctors available');
        }

        // Filter out available doctors only
        final availableDoctors =
            doctors.where((doctor) => doctor.isAvailable).toList();

        if (availableDoctors.isEmpty) {
          return const Text('No available doctors');
        }

        return DropdownButtonFormField<String>(
          value: _selectedDoctorId,
          decoration: InputDecoration(
            hintText: 'Select a doctor',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items:
              availableDoctors.map((doctor) {
                return DropdownMenuItem<String>(
                  value: doctor.id,
                  child: Text('${doctor.name} (${doctor.specialty})'),
                );
              }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDoctorId = value;
              _selectedTimeSlot = null;
            });

            if (_selectedDate != null) {
              _loadTimeSlots();
            }
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Text('Error: $error'),
    );
  }

  Widget _buildDatePicker() {
    final formatter = DateFormat('EEEE, MMMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );

            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
                _selectedTimeSlot = null;
              });

              if (_selectedDoctorId != null) {
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
                  _selectedDate != null
                      ? formatter.format(_selectedDate!)
                      : 'Select a date',
                ),
                const Icon(Icons.calendar_today),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
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
            final isSelected = _selectedTimeSlot?.id == slot.id;
            final startTime = TimeOfDay(
              hour: slot.startTime.hour,
              minute: slot.startTime.minute,
            );
            final endTime = slot.endTime;

            return ChoiceChip(
              label: Text(
                '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}',
              ),
              selected: isSelected,
              onSelected:
                  slot.isAvailable
                      ? (selected) {
                        setState(() {
                          _selectedTimeSlot = selected ? slot : null;
                        });
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
