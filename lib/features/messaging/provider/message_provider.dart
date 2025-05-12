import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../controller/messaging_controller.dart';
import '../services/kwt_sms_service.dart'; // Import KwtSmsService provider

final messegingControllerProvider = Provider<MessegingController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final kwtSmsService = ref.watch(kwtSmsServiceProvider); // Watch KwtSmsService
  return MessegingController(firebaseService, kwtSmsService);
});
