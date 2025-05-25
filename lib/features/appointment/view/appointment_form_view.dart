import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/dependencies.dart';
import '../../doctor/provider/doctor_provider.dart';
import '../../patient/provider/patient_provider.dart';
import '../../slot/model/time_slot.dart';
import '../model/appointment.dart';
import '../provider/appointment_provider.dart';

// --------------------------- STATE MANAGEMENT (CONTROLLER) ---------------------------

// A dedicated state class to hold all form-related state
@immutable
class AppointmentFormState {
  final String? patientId;
  final String? patientName;
  final String? doctorId;
  final String? doctorName;

  final DateTime? date;
  final TimeSlot? timeSlot;
  final String notes;
  final bool isLoading;
  final List<TimeSlot> availableTimeSlots;

  const AppointmentFormState({
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
    this.date,
    this.timeSlot,
    this.notes = '',
    this.isLoading = false,
    this.availableTimeSlots = const [],
  });

  bool get isFormValid =>
      patientId != null && doctorId != null && date != null && timeSlot != null;

  AppointmentFormState copyWith({
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    DateTime? date,
    TimeSlot? timeSlot,
    String? notes,
    bool? isLoading,
    List<TimeSlot>? availableTimeSlots,
    bool clearTimeSlot = false,
  }) {
    return AppointmentFormState(
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      timeSlot: clearTimeSlot ? null : timeSlot ?? this.timeSlot,
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      availableTimeSlots: availableTimeSlots ?? this.availableTimeSlots,
    );
  }
}

// Controller to manage the form's state and business logic
class AppointmentFormController extends StateNotifier<AppointmentFormState> {
  final Ref _ref;
  final String? _appointmentId;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController notesController = TextEditingController();

  AppointmentFormController(this._ref, this._appointmentId)
    : super(const AppointmentFormState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_appointmentId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final result = await _ref
          .read(appointmentControllerProvider)
          .getAppointmentById(_appointmentId);

      if (result.isSuccess && result.data != null) {
        final appointment = result.data!;
        notesController.text = appointment.notes ?? '';
        state = state.copyWith(
          patientId: appointment.patientId,
          patientName: appointment.patientName,
          doctorName: appointment.doctorName,
          doctorId: appointment.doctorId,
          date: appointment.dateTime,
          notes: appointment.notes ?? '',
        );
        await _loadTimeSlots(
          onComplete: (slots) {
            final selectedSlot = slots.firstWhere(
              (s) => s.id == appointment.timeSlotId,
              orElse: () => slots.first,
            );
            state = state.copyWith(timeSlot: selectedSlot);
          },
        );
      } else {
        _showMessage('Failed to load appointment data', isError: true);
      }
    } catch (e) {
      _showMessage('Error loading appointment data', isError: true);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadTimeSlots({Function(List<TimeSlot>)? onComplete}) async {
    if (state.doctorId == null || state.date == null) {
      state = state.copyWith(availableTimeSlots: []);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final result = await _ref
          .read(appointmentControllerProvider)
          .getAvailableTimeSlots(state.doctorId!, state.date!);

      if (result.isSuccess) {
        final slots = result.data ?? [];
        state = state.copyWith(availableTimeSlots: slots);
        onComplete?.call(slots);
      } else {
        state = state.copyWith(availableTimeSlots: []);
        _showMessage('Failed to load time slots', isError: true);
      }
    } catch (e) {
      _showMessage('Error loading time slots', isError: true);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void updatePatient(String? patientId) {
    state = state.copyWith(
      patientId: patientId,
      patientName: _ref.read(getAllPatientsProvider).value?.data?.firstWhere((p) => p.id == patientId).name,
    );
  }

  void updateDoctor(String? doctorId) {
    state = state.copyWith(doctorId: doctorId,
    doctorName: _ref.read(getAllDoctorsProvider).value?.data?.firstWhere((d) => d.id == doctorId).name,
    clearTimeSlot: true);
    _loadTimeSlots();
  }

  void updateDate(DateTime? date) {
    state = state.copyWith(date: date, clearTimeSlot: true);
    _loadTimeSlots();
  }

  void updateTimeSlot(TimeSlot? timeSlot) {
    state = state.copyWith(timeSlot: timeSlot);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  Future<void> submitForm() async {
    if (!formKey.currentState!.validate() || !state.isFormValid) {
      _showMessage('Please complete all required fields', isError: true);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      // Build the appointment object from the current state
      final appointment = Appointment(
        id: _appointmentId ?? '',
        patientId: state.patientId!,
        patientName: state.patientName ?? '',
        doctorName: state.doctorName ?? '',
        doctorId: state.doctorId!,
        slotId: state.timeSlot!.slotId,
        timeSlotId: state.timeSlot!.id,
        dateTime: DateTime(
          state.date!.year,
          state.date!.month,
          state.date!.day,
          state.timeSlot!.startTime.hour,
          state.timeSlot!.startTime.minute,
        ),
        status: AppointmentStatus.scheduled,
        paymentStatus: PaymentStatus.unpaid,
        notes: state.notes.isNotEmpty ? state.notes : null,
      );

      final isEditing = _appointmentId != null;
      final result = isEditing
          ? await _ref
                .read(appointmentControllerProvider)
                .updateAppointment(appointment)
          : await _ref
                .read(appointmentControllerProvider)
                .createAppointment(appointment);

      if (result.isSuccess && result.data != null) {
        _ref.invalidate(allAppointmentsProvider);
        _showMessage(
          isEditing
              ? 'Appointment updated successfully'
              : 'Appointment created successfully',
          isError: false,
        );
        // Handle payment logic
      } else {
        _showMessage(
          result.errorMessage ?? 'Failed to save appointment',
          isError: true,
        );
      }
    } catch (e) {
      _showMessage('Error processing appointment', isError: true);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    // This requires a context. It's better to handle this in the view.
    // For now, we'll assume a way to show messages is available globally
    // or passed into the controller. A better approach is using a listener
    // on the provider in the view.
    debugPrint("showMessage: $message (isError: $isError)");
  }
}

// Provider for the controller
final appointmentFormControllerProvider = StateNotifierProvider.autoDispose
    .family<AppointmentFormController, AppointmentFormState, String?>(
      (ref, appointmentId) => AppointmentFormController(ref, appointmentId),
    );

// --------------------------- UI (VIEW) ---------------------------

class AppointmentFormView extends ConsumerWidget {
  final String? appointmentId;

  const AppointmentFormView({super.key, this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(
      appointmentFormControllerProvider(appointmentId).notifier,
    );
    final state = ref.watch(appointmentFormControllerProvider(appointmentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appointmentId != null ? 'Edit Appointment' : 'New Appointment',
        ),
      ),
      body: state.isLoading && state.availableTimeSlots.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointmentId != null
                          ? 'Edit Appointment Details'
                          : 'Book New Appointment',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Divider(height: 32),

                    _SectionTitle('Select Patient'),
                    _PatientDropdown(
                      selectedValue: state.patientId,
                      onChanged: controller.updatePatient,
                    ),
                    const SizedBox(height: 24),

                    _SectionTitle('Select Doctor'),
                    _DoctorDropdown(
                      selectedValue: state.doctorId,
                      onChanged: controller.updateDoctor,
                    ),
                    const SizedBox(height: 24),

                    _SectionTitle('Select Date'),
                    _DatePicker(
                      selectedDate: state.date,
                      onDateSelected: controller.updateDate,
                    ),
                    const SizedBox(height: 24),

                    if (state.doctorId != null && state.date != null) ...[
                      _SectionTitle('Select Time Slot'),
                      if (state.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        _TimeSlotSelection(
                          availableSlots: state.availableTimeSlots,
                          selectedSlot: state.timeSlot,
                          onSlotSelected: controller.updateTimeSlot,
                        ),
                      const SizedBox(height: 24),
                    ],

                    _SectionTitle('Notes (Optional)'),
                    TextFormField(
                      controller: controller.notesController,
                      decoration: const InputDecoration(
                        hintText: 'Add any additional notes here...',
                      ),
                      maxLines: 3,
                      onChanged: controller.updateNotes,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        onPressed: state.isLoading
                            ? null
                            : controller.submitForm,
                        child: Text(
                          appointmentId != null
                              ? 'Update Appointment'
                              : 'Book Appointment',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// --------------------------- REUSABLE UI COMPONENTS ---------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _PatientDropdown extends ConsumerWidget {
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _PatientDropdown({this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(getAllPatientsProvider);
    return patientsAsync.when(
      data: (result) {
        final patients = result.data ?? [];
        return DropdownButtonFormField<String>(
          value: selectedValue,
          hint: const Text('Select a patient'),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: patients
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
              .toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Patient is required' : null,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Text('Could not load patients'),
    );
  }
}

class _DoctorDropdown extends ConsumerWidget {
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _DoctorDropdown({this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(getAllDoctorsProvider);
    return doctorsAsync.when(
      data: (result) {
        final doctors = (result.data ?? [])
            .where((d) => d.isAvailable)
            .toList();
        return DropdownButtonFormField<String>(
          value: selectedValue,
          hint: const Text('Select a doctor'),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: doctors
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text('${d.name} (${d.specialty})'),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Doctor is required' : null,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Text('Could not load doctors'),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DatePicker({this.selectedDate, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEEE, MMMM d, yyyy');
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate != null
                  ? formatter.format(selectedDate!)
                  : 'Select a date',
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotSelection extends StatelessWidget {
  final List<TimeSlot> availableSlots;
  final TimeSlot? selectedSlot;
  final ValueChanged<TimeSlot> onSlotSelected;

  const _TimeSlotSelection({
    required this.availableSlots,
    this.selectedSlot,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (availableSlots.isEmpty) {
      return const Center(child: Text('No available time slots.'));
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: availableSlots.map((slot) {
        final isSelected = selectedSlot?.id == slot.id;
        return ChoiceChip(
          label: Text(
            '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}',
          ),
          selected: isSelected,
          onSelected: slot.isAvailable ? (_) => onSlotSelected(slot) : null,
          backgroundColor: Colors.grey[200],
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : (slot.isAvailable ? Colors.black : Colors.grey),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt); // e.g., 5:08 PM
  }
}
