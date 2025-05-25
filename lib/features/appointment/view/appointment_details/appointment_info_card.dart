import 'package:clinic_eye/features/appointment/model/appointment.dart'
    as appointment_model;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentInfoCard extends StatelessWidget {
  final appointment_model.Appointment appointment;

  const AppointmentInfoCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointment Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(dateFormat.format(appointment.dateTime)),
                    ],
                  ),
                ),
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(timeFormat.format(appointment.dateTime)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.medical_services, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(appointment.doctorName),
                    ],
                  ),
                ),
                const Icon(Icons.medical_services, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        appointment.status.name,
                        style: TextStyle(
                          color:
                              appointment.status ==
                                  appointment_model.AppointmentStatus.completed
                              ? Colors.green
                              : appointment.status ==
                                    appointment_model
                                        .AppointmentStatus
                                        .scheduled
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Notes', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(appointment.notes!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
