import 'package:clinic_eye/features/doctor/controller/doctor_controller.dart';
import 'package:flutter/material.dart';

class AddDoctorForm extends StatelessWidget {
  const AddDoctorForm({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return Form(
      key: formKey,
      child: Column(
        spacing: 16.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Doctor',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const Divider(),
          const Text('Fill in the details below to add a new doctor.'),
          const SizedBox(height: 16.0),
          TextFormField(decoration: InputDecoration(labelText: 'Doctor Name')),
          TextFormField(
            decoration: InputDecoration(labelText: 'Specialization'),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Contact Number'),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Email Address'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                // Handle form submission
                // DoctorController.addDoctor(
                //   name: 'Doctor Name',
                //   specialization: 'Specialization',
                //   contactNumber: 'Contact Number',
                //   email: 'Email Address',
                // );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Doctor added successfully!')),
                );
              }
            },
            child: const Text('Add Doctor'),
          ),
        ],
      ),
    );
  }
}
