import 'package:flutter/material.dart';

import 'doctor_list_view.dart';

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DoctorListWithFilter();
  }
}
