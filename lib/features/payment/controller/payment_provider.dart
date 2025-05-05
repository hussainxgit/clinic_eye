import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import 'payment_controller.dart';

final paymentProvider = Provider<PaymentController>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return PaymentController(firebaseService);
});
