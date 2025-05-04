// lib/features/slot/view/slot_form_view.dart
import 'package:clinic_eye/features/slot/model/slot.dart';
import 'package:clinic_eye/features/slot/provider/slot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SlotFormView extends ConsumerWidget {
  final String doctorId;
  final String doctorName;

  const SlotFormView({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(slotFormProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Manage Slots - Dr. $doctorName')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left panel - Slot generation form
            Flexible(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Slots',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      _buildDateRangeSection(context, ref, formState),
                      const Divider(height: 32),
                      _buildTimeSlotSection(context, ref, formState),
                      const Divider(height: 32),
                      _buildExcludedDaysSection(context, ref, formState),
                      const Divider(height: 32),
                      _buildSlotSettingsSection(context, ref, formState),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              formState.isGenerating
                                  ? null
                                  : () => _generateSlots(context, ref),
                          icon:
                              formState.isGenerating
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.calendar_month),
                          label: Text(
                            formState.isGenerating
                                ? 'Generating...'
                                : 'Generate Slots',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right panel - Existing slots
            Flexible(flex: 1, child: _ExistingSlotsView(doctorId: doctorId)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection(
    BuildContext context,
    WidgetRef ref,
    SlotFormState formState,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Start Date'),
                subtitle: Text(dateFormat.format(formState.startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: formState.startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    ref
                        .read(slotFormProvider.notifier)
                        .setDateRange(
                          date,
                          formState.endDate.isBefore(date)
                              ? date.add(const Duration(days: 14))
                              : formState.endDate,
                        );
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ListTile(
                title: const Text('End Date'),
                subtitle: Text(dateFormat.format(formState.endDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: formState.endDate,
                    firstDate: formState.startDate,
                    lastDate: formState.startDate.add(
                      const Duration(days: 365),
                    ),
                  );
                  if (date != null) {
                    ref
                        .read(slotFormProvider.notifier)
                        .setDateRange(formState.startDate, date);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSlotSection(
    BuildContext context,
    WidgetRef ref,
    SlotFormState formState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Time Slots',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: () => _addTimeSlot(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (formState.dailyTimeSlots.isEmpty)
          const Card(
            color: Colors.amber,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Please add at least one time slot'),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                formState.dailyTimeSlots.map((timeSlot) {
                  return Chip(
                    label: Text(_formatTimeOfDay(timeSlot)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      ref
                          .read(slotFormProvider.notifier)
                          .removeTimeSlot(timeSlot);
                    },
                  );
                }).toList(),
          ),
      ],
    );
  }

  Widget _buildExcludedDaysSection(
    BuildContext context,
    WidgetRef ref,
    SlotFormState formState,
  ) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Excluded Days', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final weekday = index + 1; // 1 = Monday, 7 = Sunday
            final isExcluded = formState.excludedWeekdays.contains(weekday);

            return FilterChip(
              label: Text(weekdays[index]),
              selected: isExcluded,
              onSelected: (selected) {
                ref.read(slotFormProvider.notifier).toggleWeekday(weekday);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlotSettingsSection(
    BuildContext context,
    WidgetRef ref,
    SlotFormState formState,
  ) {
    final durationOptions = [15, 20, 30, 45, 60, 90, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Slot Settings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                ),
                value: formState.slotDuration.inMinutes,
                items:
                    durationOptions.map((duration) {
                      return DropdownMenuItem<int>(
                        value: duration,
                        child: Text('$duration minutes'),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(slotFormProvider.notifier)
                        .setSlotDuration(Duration(minutes: value));
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Max Patients'),
                value: formState.maxPatients,
                items: List.generate(5, (index) {
                  final value = index + 1;
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value ${value == 1 ? 'patient' : 'patients'}',
                    ),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(slotFormProvider.notifier).setMaxPatients(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addTimeSlot(BuildContext context, WidgetRef ref) async {
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (timeOfDay != null) {
      ref.read(slotFormProvider.notifier).addTimeSlot(timeOfDay);
    }
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hour.toString().padLeft(2, '0');
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _generateSlots(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(slotFormProvider.notifier)
        .generateSlots(doctorId);

    if (!context.mounted) return;

    if (result.isSuccess) {
      // Refresh the slots list
      ref.refresh(doctorSlotsProvider(doctorId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully generated ${result.data} time slots'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ExistingSlotsView extends ConsumerWidget {
  final String doctorId;

  const _ExistingSlotsView({required this.doctorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(doctorSlotsProvider(doctorId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Existing Slots',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: slotsAsync.when(
                data: (result) {
                  if (result.isError) {
                    print(result.errorMessage);
                    return Center(child: Text('Error: ${result.errorMessage}'));
                  }

                  final slots = result.data!;
                  if (slots.isEmpty) {
                    return const Center(
                      child: Text('No slots found. Generate some!'),
                    );
                  }

                  return _buildSlotsCalendar(context, ref, slots);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stackTrace) {
                      print(error);
                      return Center(child: Text('Error: $error'));
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotsCalendar(
    BuildContext context,
    WidgetRef ref,
    List<Slot> slots,
  ) {
    // Group slots by month and day
    final groupedSlots = <DateTime, List<Slot>>{};
    for (final slot in slots) {
      final date = DateTime(slot.date.year, slot.date.month, slot.date.day);
      groupedSlots[date] = [...(groupedSlots[date] ?? []), slot];
    }

    // Sort dates
    final sortedDates =
        groupedSlots.keys.toList()..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateSlots = groupedSlots[date]!;

        return _buildDateSlotCard(context, ref, date, dateSlots);
      },
    );
  }

  Widget _buildDateSlotCard(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    List<Slot> slots,
  ) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return ExpansionTile(
      title: Text(dateFormat.format(date)),
      subtitle: Text('${slots.length} slots available'),
      children:
          slots.map((slot) {
            return _SlotDetailTile(
              slot: slot,
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Slot'),
                        content: const Text(
                          'Are you sure you want to delete this slot and all its time slots?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );

                if (confirmed == true) {
                  if (!context.mounted) return;

                  final controller = ref.read(slotControllerProvider);
                  final result = await controller.deleteSlot(slot.id);

                  if (!context.mounted) return;

                  if (result.isSuccess) {
                    // Refresh the slots list
                    ref.refresh(doctorSlotsProvider(doctorId));

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Slot deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${result.errorMessage}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              onToggleAvailability: () async {
                final controller = ref.read(slotControllerProvider);
                final result = await controller.toggleSlotAvailability(slot.id);

                if (!context.mounted) return;

                if (result.isSuccess) {
                  // Refresh the slots list
                  ref.refresh(doctorSlotsProvider(doctorId));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${result.errorMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          }).toList(),
    );
  }
}

class _SlotDetailTile extends ConsumerWidget {
  final Slot slot;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  const _SlotDetailTile({
    required this.slot,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeSlotsAsync = ref.watch(slotTimeSlotsProvider(slot.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: Text('Slot for ${DateFormat('MMM d').format(slot.date)}'),
            subtitle: Text(
              slot.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: slot.isActive ? Colors.green : Colors.red,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: slot.isActive,
                  onChanged: (_) => onToggleAvailability(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: timeSlotsAsync.when(
              data: (result) {
                if (result.isError) {
                  return Text('Error: ${result.errorMessage}');
                }

                final timeSlots = result.data!;
                if (timeSlots.isEmpty) {
                  return const Text('No time slots found');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      timeSlots.map((timeSlot) {
                        final hour = timeSlot.startTime.hour.toString().padLeft(
                          2,
                          '0',
                        );
                        final minute = timeSlot.startTime.minute
                            .toString()
                            .padLeft(2, '0');
                        final durationMins = timeSlot.duration.inMinutes;

                        return Chip(
                          label: Text('$hour:$minute ($durationMins min)'),
                          avatar: Icon(
                            Icons.timer,
                            size: 16,
                            color:
                                timeSlot.isActive ? Colors.green : Colors.red,
                          ),
                          backgroundColor:
                              timeSlot.isFullyBooked
                                  ? Colors.red.shade100
                                  : Colors.green.shade50,
                        );
                      }).toList(),
                );
              },
              loading:
                  () => const SizedBox(
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (error, stackTrace) => Text('Error: $error'),
            ),
          ),
        ],
      ),
    );
  }
}
