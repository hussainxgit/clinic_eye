import 'package:clinic_eye/features/payment/controller/payment_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/appointment/controller/appointment_controller.dart';
import '../../features/messaging/controller/messeging_controller.dart';
import '../../features/patient/controller/patient_controller.dart';
import '../services/firebase/firebase_service.dart';
import '../../features/doctor/controller/doctor_controller.dart';

// Core providers
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  throw UnimplementedError('Firebase service must be initialized in main()');
});

final themeModeProvider = StateProvider<bool>((ref) {
  return false; // false = light mode, true = dark mode
});

// Selected index for navigation
final selectedNavIndexProvider = StateProvider<int>((ref) {
  return 0;
});

// Service providers
final messegingControllerProvider = Provider<MessegingController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return MessegingController(firebaseService);
});

final paymentControllerProvider = Provider<PaymentController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return PaymentController(firebaseService);
});

final doctorControllerProvider = Provider<DoctorController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return DoctorController(firebaseService);
});

final patientControllerProvider = Provider<PatientController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return PatientController(firebaseService);
});

final appointmentControllerProvider = Provider<AppointmentController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return AppointmentController(firebaseService);
});

// Function to initialize providers at app startup
Future<void> setupDependencies(FirebaseService firebaseService) async {
  // This function will be called from main() to override the providers with actual instances
  container = ProviderContainer(
    overrides: [firebaseServiceProvider.overrideWithValue(firebaseService)],
  );
}

// Global provider container to be used in main.dart
late ProviderContainer container;
