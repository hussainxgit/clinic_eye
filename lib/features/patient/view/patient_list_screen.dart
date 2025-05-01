import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/views/widgets/common/generic_filter_dialog.dart';
import '../model/patient.dart';
import '../provider/patient_provider.dart';
import 'patient_form_screen.dart';

// StateProvider to hold the current filter values
final patientFiltersProvider = StateProvider<Map<String, dynamic>>((ref) => {});

// Provider that filters patients based on filter criteria
final filteredPatientsProvider = Provider<List<Patient>>((ref) {
  final patientsResult = ref.watch(getAllPatientsProvider);
  final filters = ref.watch(patientFiltersProvider);

  if (patientsResult.value == null || !patientsResult.value!.isSuccess) {
    return [];
  }

  final patients = patientsResult.value!.data ?? [];

  if (filters.isEmpty) {
    return patients;
  }

  return patients.where((patient) {
    // Apply each filter criterion
    for (final entry in filters.entries) {
      switch (entry.key) {
        case 'gender':
          final gender =
              entry.value.toLowerCase() == 'male'
                  ? PatientGender.male
                  : PatientGender.female;
          if (patient.gender != gender) return false;
          break;
        case 'status':
          final status =
              entry.value.toLowerCase() == 'active'
                  ? PatientStatus.active
                  : PatientStatus.inactive;
          if (patient.status != status) return false;
          break;
      }
    }
    return true;
  }).toList();
});

class PatientListWithFilter extends ConsumerWidget {
  const PatientListWithFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredPatients = ref.watch(filteredPatientsProvider);
    final filters = ref.watch(patientFiltersProvider);
    final hasActiveFilters = filters.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Patients List (${filteredPatients.length})',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientFormScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Patient'),
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
                      ref.read(patientFiltersProvider.notifier).state =
                          updatedFilters;
                    },
                  ),
                TextButton.icon(
                  onPressed: () {
                    ref.read(patientFiltersProvider.notifier).state = {};
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
          child:
              filteredPatients.isEmpty
                  ? const Center(
                    child: Text('No patients match the selected filters'),
                  )
                  : ListView.builder(
                    itemCount: filteredPatients.length,
                    itemBuilder: (context, index) {
                      final patient = filteredPatients[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => PatientFormScreen(
                                      patient: patient,
                                      isEditing: true,
                                    ),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundImage:
                                patient.avatarUrl != null
                                    ? NetworkImage(patient.avatarUrl!)
                                    : null,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            child:
                                patient.avatarUrl == null
                                    ? Text(patient.name[0].toUpperCase())
                                    : null,
                          ),
                          title: Text(patient.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone: ${patient.phone}'),
                              if (patient.email != null)
                                Text(
                                  patient.email!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(
                              patient.status == PatientStatus.active
                                  ? 'Active'
                                  : 'Inactive',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor:
                                patient.status == PatientStatus.active
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

  String _getFilterLabel(String key, dynamic value) {
    switch (key) {
      case 'gender':
        return 'Gender: $value';
      case 'status':
        return 'Status: $value';
      default:
        return '$key: $value';
    }
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) async {
    // Get current filters
    final currentFilters = ref.read(patientFiltersProvider);

    // Create gender filter options
    final genderOptions = [
      OptionItem<String>(label: 'Male', value: 'male'),
      OptionItem<String>(label: 'Female', value: 'female'),
    ];

    // Create status filter options
    final statusOptions = [
      OptionItem<String>(label: 'Active', value: 'active'),
      OptionItem<String>(label: 'Inactive', value: 'inactive'),
    ];

    // Create filter options
    final filterOptions = [
      FilterOption<String>(
        label: 'Gender',
        field: 'gender',
        options: genderOptions,
        selectedValue: currentFilters['gender'],
      ),
      FilterOption<String>(
        label: 'Status',
        field: 'status',
        options: statusOptions,
        selectedValue: currentFilters['status'],
      ),
    ];

    // Show filter dialog
    await showFilterDialog<Patient>(
      context: context,
      filterOptions: filterOptions,
      title: 'Filter Patients',
      onApply: (filterValues) {
        ref.read(patientFiltersProvider.notifier).state = filterValues;
      },
      onReset: () {
        ref.read(patientFiltersProvider.notifier).state = {};
      },
    );
  }
}
