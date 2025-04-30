import 'package:flutter/material.dart';

// Helper class to create a generic filter dialog
class FilterOption<T> {
  final String label;
  final String field;
  final List<OptionItem<T>> options;
  T? selectedValue;

  FilterOption({
    required this.label,
    required this.field,
    required this.options,
    this.selectedValue,
  });
}

// Helper class to create option items for the filter
class OptionItem<T> {
  final String label;
  final T value;

  OptionItem({required this.label, required this.value});
}

class GenericFilterDialog<T> extends StatefulWidget {
  final List<FilterOption<dynamic>> filterOptions;
  final String title;
  final Function(Map<String, dynamic>) onApply;
  final Function() onReset;

  const GenericFilterDialog({
    super.key,
    required this.filterOptions,
    required this.title,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<GenericFilterDialog<T>> createState() => _GenericFilterDialogState<T>();
}

class _GenericFilterDialogState<T> extends State<GenericFilterDialog<T>> {
  late List<FilterOption<dynamic>> _filterOptions;

  @override
  void initState() {
    super.initState();
    // Create a copy of the filter options to prevent modifying the originals
    _filterOptions = List.from(widget.filterOptions);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildFilterOptions(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onReset();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final filterValues = <String, dynamic>{};
                    for (var option in _filterOptions) {
                      if (option.selectedValue != null) {
                        filterValues[option.field] = option.selectedValue;
                      }
                    }
                    widget.onApply(filterValues);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilterOptions() {
    return _filterOptions.map((option) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(option.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<dynamic>(
            value: option.selectedValue,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items:
                option.options.map((item) {
                  return DropdownMenuItem<dynamic>(
                    value: item.value,
                    child: Text(item.label),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() {
                option.selectedValue = value;
              });
            },
            hint: Text('Select ${option.label}'),
          ),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }
}

// Helper function to show the filter dialog
Future<void> showFilterDialog<T>({
  required BuildContext context,
  required List<FilterOption<dynamic>> filterOptions,
  required Function(Map<String, dynamic>) onApply,
  required Function() onReset,
  String title = 'Filter',
}) async {
  await showDialog(
    context: context,
    builder:
        (context) => GenericFilterDialog<T>(
          filterOptions: filterOptions,
          title: title,
          onApply: onApply,
          onReset: onReset,
        ),
  );
}
