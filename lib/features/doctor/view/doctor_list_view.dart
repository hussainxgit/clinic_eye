import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clinic_eye/core/locale/l10n/app_localizations.dart';

import '../../../core/views/widgets/common/generic_filter_dialog.dart';
import '../model/doctor.dart';
import '../provider/doctor_provider.dart';
import 'doctor_appointments_details.dart';
import 'doctor_form_view.dart';

// StateProvider to hold the current filter values
final doctorFiltersProvider = StateProvider<Map<String, dynamic>>((ref) => {});

// Provider that extracts unique specialties from doctors data
final doctorSpecialtiesProvider = Provider<List<String>>((ref) {
  final doctorsResult = ref.watch(getAllDoctorsProvider);

  if (doctorsResult.value == null || !doctorsResult.value!.isSuccess) {
    return [];
  }

  final doctors = doctorsResult.value!.data ?? [];
  final specialties =
      doctors.map((doctor) => doctor.specialty).toSet().toList();
  specialties.sort(); // Sort alphabetically for better UI experience

  return specialties;
});

// Provider that filters doctors based on filter criteria
final filteredDoctorsProvider = Provider<List<Doctor>>((ref) {
  final doctorsResult = ref.watch(getAllDoctorsProvider);
  final filters = ref.watch(doctorFiltersProvider);

  if (doctorsResult.value == null || !doctorsResult.value!.isSuccess) {
    return [];
  }

  final doctors = doctorsResult.value!.data ?? [];

  if (filters.isEmpty) {
    return doctors;
  }

  return doctors.where((doctor) {
    // Apply each filter criterion
    for (final entry in filters.entries) {
      switch (entry.key) {
        case 'specialty':
          if (doctor.specialty != entry.value) return false;
          break;
        case 'isAvailable':
          if (doctor.isAvailable != entry.value) return false;
          break;
      }
    }
    return true;
  }).toList();
});

class DoctorListWithFilter extends ConsumerWidget {
  const DoctorListWithFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredDoctors = ref.watch(filteredDoctorsProvider);
    final filters = ref.watch(doctorFiltersProvider);
    final hasActiveFilters = filters.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${l10n.doctors} (${filteredDoctors.length})',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddDoctorFormView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.add),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showFilterDialog(context, ref),
                  icon: const Icon(Icons.filter_list),
                  label: Text(l10n.filter),
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
                      _getFilterLabel(filter.key, filter.value, l10n),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      final updatedFilters = Map<String, dynamic>.from(filters);
                      updatedFilters.remove(filter.key);
                      ref.read(doctorFiltersProvider.notifier).state =
                          updatedFilters;
                    },
                  ),
                TextButton.icon(
                  onPressed: () {
                    ref.read(doctorFiltersProvider.notifier).state = {};
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(
                    l10n.clearAllNotifications, // Assuming 'Clear All' is similar to 'Clear all notifications'
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        Expanded(
          child:
              filteredDoctors.isEmpty
                  ? Center(
                    child: Text(l10n.noDoctorsFound),
                  )
                  : ListView.builder(
                    itemCount: filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = filteredDoctors[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onTap: () {
                            // Navigator.of(context).push(
                            //   MaterialPageRoute(
                            //     builder:
                            //         (_) => EditDoctorFormView(doctor: doctor),
                            //   ),
                            // );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => DoctorAppointmentsDetails(
                                      doctor: doctor,
                                    ),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            child: Text(doctor.name[0].toUpperCase()),
                          ),
                          title: Text(doctor.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l10n.doctorSpecialty}: ${doctor.specialty}'),
                              if (doctor.email != null)
                                Text(
                                  doctor.email!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(
                              doctor.isAvailable ? l10n.availableSlots : l10n.noSlotsAvailable, // Assuming 'Available' and 'Unavailable' map to these
                              style: TextStyle(
                                color:
                                    doctor.isAvailable
                                        ? Colors.white
                                        : Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor:
                                doctor.isAvailable
                                    ? Colors.green
                                    : Colors.red.shade300,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  String _getFilterLabel(String key, dynamic value, AppLocalizations l10n) {
    switch (key) {
      case 'specialty':
        return '${l10n.doctorSpecialty}: $value';
      case 'isAvailable':
        return '${l10n.status}: ${value ? l10n.availableSlots : l10n.noSlotsAvailable}'; // Assuming 'Available' and 'Unavailable' map to these
      default:
        return '$key: $value';
    }
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) async {
    // Get current filters
    final currentFilters = ref.read(doctorFiltersProvider);
    final l10n = AppLocalizations.of(context)!;

    // Get dynamic specialties from the provider
    final specialties = ref.read(doctorSpecialtiesProvider);

    // Create specialty filter options dynamically from data
    final specialtyOptions =
        specialties
            .map(
              (specialty) =>
                  OptionItem<String>(label: specialty, value: specialty),
            )
            .toList();

    // Create availability filter options
    final availabilityOptions = [
      OptionItem<bool>(label: l10n.availableSlots, value: true), // Assuming 'Available' maps to this
      OptionItem<bool>(label: l10n.noSlotsAvailable, value: false), // Assuming 'Unavailable' maps to this
    ];

    // Create filter options
    final filterOptions = [
      FilterOption<String>(
        label: l10n.doctorSpecialty,
        field: 'specialty',
        options: specialtyOptions,
        selectedValue: currentFilters['specialty'],
      ),
      FilterOption<bool>(
        label: l10n.status, // Assuming 'Availability' maps to 'Status'
        field: 'isAvailable',
        options: availabilityOptions,
        selectedValue: currentFilters['isAvailable'],
      ),
    ];

    // Show filter dialog
    await showFilterDialog<Doctor>(
      context: context,
      filterOptions: filterOptions,
      title: '${l10n.filter} ${l10n.doctors}',
      onApply: (filterValues) {
        ref.read(doctorFiltersProvider.notifier).state = filterValues;
      },
      onReset: () {
        ref.read(doctorFiltersProvider.notifier).state = {};
      },
    );
  }
}
