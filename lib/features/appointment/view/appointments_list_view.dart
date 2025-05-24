import 'package:clinic_eye/core/config/dependencies.dart';
import 'package:clinic_eye/core/views/widgets/common/confirm_dialog.dart';
import 'package:clinic_eye/features/appointment/view/appointment_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/views/widgets/common/generic_filter_dialog.dart';
import '../model/appointment.dart';
import '../provider/appointment_provider.dart';
import 'appointment_details/appointment_details_view.dart';

// StateProvider to hold the current filter values
final appointmentFiltersProvider = StateProvider<Map<String, dynamic>>(
  (ref) => {},
);

// Provider that extracts unique statuses from appointments data
final appointmentStatusesProvider = Provider<List<String>>((ref) {
  final appointmentsResult = ref.watch(allAppointmentsProvider);

  if (appointmentsResult.value == null ||
      !appointmentsResult.value!.isSuccess) {
    return [];
  }

  final appointments = appointmentsResult.value!.data ?? [];
  final statuses =
      appointments
          .map((appointment) => appointment.status.toString().split('.').last)
          .toSet()
          .toList();
  statuses.sort(); // Sort alphabetically for better UI experience

  return statuses;
});

// Provider that filters appointments based on filter criteria
final filteredAppointmentsProvider = Provider<List<Appointment>>((ref) {
  final appointmentsResult = ref.watch(allAppointmentsProvider);
  final filters = ref.watch(appointmentFiltersProvider);

  if (appointmentsResult.value == null ||
      !appointmentsResult.value!.isSuccess) {
    return [];
  }

  final appointments = appointmentsResult.value!.data ?? [];

  if (filters.isEmpty) {
    return appointments;
  }

  return appointments.where((appointment) {
    // Apply each filter criterion
    for (final entry in filters.entries) {
      switch (entry.key) {
        case 'status':
          final appointmentStatus =
              appointment.status.toString().split('.').last;
          if (appointmentStatus != entry.value) return false;
          break;
        case 'doctorId':
          if (appointment.doctorId != entry.value) return false;
          break;
        case 'date':
          if (!appointment.isSameDay(entry.value)) return false;
          break;
      }
    }
    return true;
  }).toList();
});

class AppointmentListWithFilter extends ConsumerWidget {
  const AppointmentListWithFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAppointments = ref.watch(filteredAppointmentsProvider);
    final filters = ref.watch(appointmentFiltersProvider);
    final hasActiveFilters = filters.isNotEmpty;
    final appointmentsAsync = ref.watch(allAppointmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Appointments List (${filteredAppointments.length})',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppointmentFormView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Appointment'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showFilterDialog(context, ref),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                  style:
                      hasActiveFilters
                          ? ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                          )
                          : null,
                ),
              ],
            ),
          ],
        ),
        if (hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (final filter in filters.entries)
                  Chip(
                    label: Text(
                      _getFilterLabel(filter.key, filter.value),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      final updatedFilters = Map<String, dynamic>.from(filters);
                      updatedFilters.remove(filter.key);
                      ref.read(appointmentFiltersProvider.notifier).state =
                          updatedFilters;
                    },
                  ),
                TextButton.icon(
                  onPressed: () {
                    ref.read(appointmentFiltersProvider.notifier).state = {};
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        Expanded(
          child: appointmentsAsync.when(
            data: (appointmentsResult) {
              if (!appointmentsResult.isSuccess) {
                return Center(
                  child: Text('Error: ${appointmentsResult.errorMessage}'),
                );
              }

              if (filteredAppointments.isEmpty) {
                return const Center(
                  child: Text('No appointments match the selected filters'),
                );
              }

              return ListView.builder(
                itemCount: filteredAppointments.length,
                itemBuilder: (context, index) {
                  final appointment = filteredAppointments[index];
                  return AppointmentListItem(
                    appointment: appointment,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => AppointmentDetailsView(
                                appointmentId: appointment.id,
                              ),
                        ),
                      );
                    },
                    onDelete: () => _confirmDelete(context, ref, appointment),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  String _getFilterLabel(String key, dynamic value) {
    switch (key) {
      case 'status':
        return 'Status: $value';
      case 'doctorId':
        return 'Doctor: $value';
      case 'date':
        final date = value as DateTime;
        return 'Date: ${date.day}/${date.month}/${date.year}';
      default:
        return '$key: $value';
    }
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) async {
    // Get current filters
    final currentFilters = ref.read(appointmentFiltersProvider);

    // Get dynamic statuses from the provider
    final statuses = ref.read(appointmentStatusesProvider);

    // Create status filter options dynamically from data
    final statusOptions =
        statuses
            .map((status) => OptionItem<String>(label: status, value: status))
            .toList();

    // Create filter options
    final filterOptions = [
      FilterOption<String>(
        label: 'Status',
        field: 'status',
        options: statusOptions,
        selectedValue: currentFilters['status'],
      ),
      // Add date filter option if needed
      // FilterOption<DateTime>(...),
    ];

    // Show filter dialog
    await showFilterDialog<Appointment>(
      context: context,
      filterOptions: filterOptions,
      title: 'Filter Appointments',
      onApply: (filterValues) {
        ref.read(appointmentFiltersProvider.notifier).state = filterValues;
      },
      onReset: () {
        ref.read(appointmentFiltersProvider.notifier).state = {};
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => ConfirmDialog(
            title: 'Delete Appointment',
            content:
                'Are you sure you want to delete appointment with ${appointment.patientName} on ${appointment.dateTime.day}/${appointment.dateTime.month}/${appointment.dateTime.year}?',
            confirmText: 'Delete',
            cancelText: 'Cancel',
            onConfirm: () {
              // Call the delete method from the appointment controller
              ref
                  .read(appointmentControllerProvider)
                  .cancelAppointment(appointment.id)
                  .then((result) {
                    if (result.isSuccess) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Appointment deleted')),
                        );
                        Navigator.of(context).pop(); // Close the dialog
                        ref.invalidate(allAppointmentsProvider); // Refresh the list
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${result.errorMessage}'),
                          ),
                        );
                      }
                    }
                  });
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
    );
  }
}

class AppointmentListItem extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AppointmentListItem({
    super.key,
    required this.appointment,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(appointment.status);
    final paymentStatusColor =
        appointment.paymentStatus == PaymentStatus.paid
            ? Colors.green
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Dismissible(
        key: Key(appointment.id),
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return false; // We'll handle deletion in our own dialog
        },
        onDismissed:
            (_) {}, // Won't be called due to confirmDismiss returning false
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Text(appointment.patientName[0].toUpperCase()),
          ),
          title: Text(appointment.patientName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doctor: ${appointment.doctorName}'),
              Text(
                'Date: ${appointment.dateTime.day}/${appointment.dateTime.month}/${appointment.dateTime.year} at ${appointment.dateTime.hour}:${appointment.dateTime.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                label: Text(
                  appointment.status.toString().split('.').last,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: statusColor,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  appointment.paymentStatus == PaymentStatus.paid
                      ? 'Paid'
                      : 'Unpaid',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: paymentStatusColor,
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Colors.blue;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }
}
