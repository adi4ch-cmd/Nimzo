import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_provider.dart';

/// Presentation state mirrors the existing profile language after a confirmed save.
final uiLanguageProvider = StateProvider<String>((ref) {
  ref.watch(currentUserIdProvider);
  return 'en';
});
const referenceArabicTabs = [
  'الرئيسية',
  'الألعاب',
  'اللحظات',
  'الرسائل',
  'أنا',
];
