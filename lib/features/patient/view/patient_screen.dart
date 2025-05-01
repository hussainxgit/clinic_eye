import 'package:flutter/material.dart';

import 'patient_list_screen.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientListWithFilter();
  }
}
