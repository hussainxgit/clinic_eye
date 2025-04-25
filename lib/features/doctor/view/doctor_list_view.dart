import 'package:flutter/material.dart';

class DoctorListView extends StatelessWidget {
  const DoctorListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                Text('(7)', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
            Row(
              spacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: () => {},
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
        Divider(),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          itemBuilder: (context, index) {
            return ListTile(
              onTap: () => {},
              title: Text('Doctor ${index + 1}'),
              subtitle: Text('Specialization ${index + 1}'),
              trailing: Icon(Icons.arrow_forward),
            );
          },
        ),
      ],
    );
  }
}
