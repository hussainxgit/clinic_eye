import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../../messaging/services/kwt_sms_service.dart';
import '../services/my_fatoorah_service.dart'; // Import MyFatoorahService provider
import 'payment_controller.dart';

final paymentProvider = Provider<PaymentController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final myFatoorahService = ref.watch(myFatoorahServiceProvider); // Watch MyFatoorahService
  final messingingService = ref.watch(kwtSmsServiceProvider); // Get the reader
  return PaymentController(firebaseService, myFatoorahService, messingingService); // Pass reader
});
