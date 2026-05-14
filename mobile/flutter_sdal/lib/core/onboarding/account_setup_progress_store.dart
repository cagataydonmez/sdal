import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_hint_store.dart';

String _verificationSubmittedKey(int userId) =>
    'account-setup:verification-submitted:$userId';

final verificationRequestSubmittedProvider = FutureProvider.autoDispose
    .family<bool, int>((ref, userId) async {
      final store = await OnboardingHintStore.create();
      return store.isDismissed(_verificationSubmittedKey(userId));
    });

Future<void> markVerificationRequestSubmitted(Ref ref, int userId) async {
  if (userId <= 0) return;
  final store = await OnboardingHintStore.create();
  await store.dismiss(_verificationSubmittedKey(userId));
  ref.invalidate(verificationRequestSubmittedProvider(userId));
}
