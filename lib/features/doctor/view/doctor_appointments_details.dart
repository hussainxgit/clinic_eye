import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:clinic_eye/core/locale/l10n/app_localizations.dart';

import '../../../core/config/dependencies.dart';
import '../../../core/models/result.dart';
import '../../../core/services/firebase/firebase_service.dart';
import '../../appointment/model/appointment.dart';
import '../../slot/view/slot_form_view.dart';
import '../model/doctor.dart';

// Provider to store the selected date
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Provider to fetch doctor's appointments for a specific date
final doctorAppointmentsByDateProvider =
    FutureProvider.family<List<Appointment>, DoctorDateFilter>((
      ref,
      filter,
    ) async {
      final firebaseService = ref.watch(firebaseServiceProvider);

      // Format the date to compare only year, month, and day
      final selectedDate = filter.date;
      final startOfDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final endOfDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        23,
        59,
        59,
      );

      // Query appointments for the specified doctor and date
      final snapshot = await firebaseService.queryCollection('appointments', [
        QueryFilter(field: 'doctorId', isEqualTo: filter.doctorId),
        QueryFilter(
          field: 'dateTime',
          isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
        ),
        QueryFilter(
          field: 'dateTime',
          isLessThanOrEqualTo: endOfDay.toIso8601String(),
        ),
      ], orderBy: 'dateTime');

      // Convert to Appointment objects
      return snapshot.docs
          .map(
            (doc) =>
                Appointment.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    });

// Data class to combine doctor ID and date for the provider
class DoctorDateFilter {
  final String doctorId;
  final DateTime date;

  DoctorDateFilter({required this.doctorId, required this.date});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DoctorDateFilter &&
        other.doctorId == doctorId &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode => Object.hash(doctorId, date.year, date.month, date.day);
}

// Provider to get all appointments for a specific doctor
final doctorAppointmentsProvider =
    FutureProvider.family<Result<List<Appointment>>, String>((
      ref,
      doctorId,
    ) async {
      final firebaseService = ref.watch(firebaseServiceProvider);

      try {
        final snapshot = await firebaseService.queryCollection('appointments', [
          QueryFilter(field: 'doctorId', isEqualTo: doctorId),
        ], orderBy: 'dateTime');

        final appointments =
            snapshot.docs
                .map(
                  (doc) => Appointment.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ),
                )
                .toList();

        return Result.success(appointments);
      } catch (e) {
        return Result.error(e.toString());
      }
    });

// Main screen for doctor appointments details
class DoctorAppointmentsDetails extends ConsumerWidget {
  final Doctor doctor;

  const DoctorAppointmentsDetails({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appointmentsReport), // Assuming this is a suitable title
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed:
                () =>
                    ref.read(selectedDateProvider.notifier).state =
                        DateTime.now(),
            tooltip: l10n.today,
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined),
            tooltip: l10n.manageSlots, // Needs a new key `manageSlots`
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => SlotFormView(
                        doctorId: doctor.id,
                        doctorName: doctor.name,
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appointments list for the selected date (left side)
            Expanded(
              flex: 3,
              child: AppointmentsListByDate(doctor: doctor, date: selectedDate),
            ),
            const SizedBox(width: 16),
            // Calendar widget (right side)
            Expanded(
              flex: 2,
              child: DoctorAppointmentsCalendar(doctor: doctor),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget for displaying appointments for a specific date
class AppointmentsListByDate extends ConsumerWidget {
  final Doctor doctor;
  final DateTime date;

  const AppointmentsListByDate({
    super.key,
    required this.doctor,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = DoctorDateFilter(doctorId: doctor.id, date: date);
    final appointmentsAsync = ref.watch(
      doctorAppointmentsByDateProvider(filter),
    );
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy', l10n.localeName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateFormat.format(date),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          doctor.isAvailable
              ? 'Dr. ${doctor.name} ${l10n.isAvailableOnThisDate}' // Needs a new key `isAvailableOnThisDate`
              : 'Dr. ${doctor.name} ${l10n.isNotAvailableOnThisDate}', // Needs a new key `isNotAvailableOnThisDate`
          style: TextStyle(
            color: doctor.isAvailable ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: appointmentsAsync.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return Center(
                  child: Text(l10n.noAppointments), // Needs a new key `noAppointments` or similar like `noUpcomingAppointments`
                );
              }

              return ListView.builder(
                itemCount: appointments.length,
                itemBuilder: (context, index) {
                  final appointment = appointments[index];
                  final timeFormat = DateFormat('h:mm a', l10n.localeName);

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: Text(appointment.patientName[0].toUpperCase()),
                      ),
                      title: Text(appointment.patientName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.time}: ${timeFormat.format(appointment.dateTime)}',
                          ),
                          Text(
                            '${l10n.status}: ${appointment.status.toString().split('.').last}',
                          ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(
                          appointment.paymentStatus == PaymentStatus.paid
                              ? l10n.paid // Needs a new key `paid`
                              : l10n.unpaid, // Needs a new key `unpaid`
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor:
                            appointment.paymentStatus == PaymentStatus.paid
                                ? Colors.green
                                : Colors.orange,
                        padding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        // Navigate to appointment details
                        // Navigator.of(context).push(
                        //   MaterialPageRoute(
                        //     builder: (_) => AppointmentDetailsScreen(appointment: appointment),
                        //   ),
                        // );
                      },
                    ),
                  );
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
            error: (error, stack) => Center(child: Text('${l10n.error}: $error')),
          ),
        ),
      ],
    );
  }
}

// Calendar widget for selecting dates
class DoctorAppointmentsCalendar extends ConsumerWidget {
  final Doctor doctor;

  const DoctorAppointmentsCalendar({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final doctorAppointmentsAsyncValue = ref.watch(
      doctorAppointmentsProvider(doctor.id),
    );
    final l10n = AppLocalizations.of(context)!;

    // Create a map of dates that have appointments
    final Map<DateTime, List<Appointment>> appointmentsByDate = {};

    if (doctorAppointmentsAsyncValue.hasValue &&
        doctorAppointmentsAsyncValue.value!.isSuccess) {
      final appointments = doctorAppointmentsAsyncValue.value!.data ?? [];

      for (final appointment in appointments) {
        final date = DateTime(
          appointment.dateTime.year,
          appointment.dateTime.month,
          appointment.dateTime.day,
        );

        if (!appointmentsByDate.containsKey(date)) {
          appointmentsByDate[date] = [];
        }

        appointmentsByDate[date]!.add(appointment);
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectDate, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TableCalendar(
              locale: l10n.localeName,
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: selectedDate,
              selectedDayPredicate: (day) {
                return isSameDay(selectedDate, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(selectedDateProvider.notifier).state = selectedDay;
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  // Display markers for dates with appointments
                  final date = DateTime(day.year, day.month, day.day);
                  if (appointmentsByDate.containsKey(date) &&
                      appointmentsByDate[date]!.isNotEmpty) {
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            doctorAppointmentsAsyncValue.when(
              data: (result) {
                if (!result.isSuccess) {
                  print(result.errorMessage);
                  return Text('${l10n.error}: ${result.errorMessage}');
                }

                final appointments = result.data ?? [];
                final date = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                );

                final appointmentsForDay = appointmentsByDate[date] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appointmentDetails, // Assuming 'Appointment Stats' can map to this
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          context,
                          l10n: l10n,
                          title: l10n.all, // Assuming 'Total' maps to 'All'
                          value: appointments.length.toString(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _buildStatCard(
                          context,
                          l10n: l10n,
                          title: l10n.today,
                          value: appointmentsForDay.length.toString(),
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
              error: (error, stack) => Text('${l10n.error}: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required AppLocalizations l10n, // Added l10n here
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
