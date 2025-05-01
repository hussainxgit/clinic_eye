import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/patient/controller/patient_controller.dart';
import '../services/firebase/firebase_service.dart';
import '../../features/doctor/controller/doctor_controller.dart';
import '../../features/messaging/services/sms_service.dart';
import '../../features/payment/services/payment_service.dart';

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
final smsServiceProvider = Provider<SmsService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return SmsService(firebaseService);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return PaymentService(firebaseService);
});

final doctorControllerProvider = Provider<DoctorController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return DoctorController(firebaseService);
});

final patientControllerProvider = Provider<PatientController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return PatientController(firebaseService);
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
