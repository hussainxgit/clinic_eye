import 'package:clinic_eye/features/doctor/view/doctor_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/doctor_provider.dart';

class DoctorListView extends ConsumerWidget {
  const DoctorListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(getAllDoctorsProvider);
    return switch (doctorsAsync) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoctorsListViewHeader(listCounter: value.data!.length),
          Divider(),
          ListView.builder(
            shrinkWrap: true,
            itemCount: value.data!.length,
            itemBuilder: (context, index) {
              final doctor = value.data![index];
              return Card(
                child: ListTile(
                  onTap: () => {
                    // Navigate to doctor details screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditDoctorFormView(doctor: doctor),
                      ),
                    ),
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  title: Text(doctor.name),
                  subtitle: Text('Specialty: ${doctor.specialty}'),
                  trailing: Icon(Icons.arrow_forward),
                ),
              );
            },
          ),
        ],
      ),
      AsyncError(:final error) => Text('error: $error'),
      _ => const Text('loading'),
    };
  }
}

class DoctorsListViewHeader extends StatelessWidget {
  final int listCounter;
  const DoctorsListViewHeader({super.key, required this.listCounter});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              spacing: 8.0,
              children: [
                Text(
                  'Doctors List',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  '($listCounter)',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
            Row(
              spacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed:
                      () => {
                        // Navigate to add doctor screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddDoctorFormView(),
                          ),
                        ),
                      },
                  child: const Text('Add Doctor'),
                ),
                ElevatedButton(
                  onPressed: () => {},
                  child: const Text('Filter'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
