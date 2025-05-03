import 'package:clinic_eye/features/appointment/view/appointments_list_view.dart';
import 'package:flutter/material.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppointmentListWithFilter();
  }
}
