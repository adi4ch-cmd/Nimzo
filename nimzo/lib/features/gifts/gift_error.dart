import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';

/// A known settlement rejection with a message safe to show to the sender.
class GiftRejectedException extends AppException {
  const GiftRejectedException(super.message, {super.code});
}

AppException mapGiftError(Object error) {
  if (error is PostgrestException && error.code == 'P0001') {
    final message = switch (error.message.trim().toLowerCase()) {
      'insufficient coins' =>
        'Not enough coins. Top up your wallet and retry this gift.',
      'gift tier required' =>
        'This gift requires a higher active VIP or SVIP level. Choose another gift.',
      'room member required' ||
      'sender is not in room' ||
      'receiver is not in room' =>
        'Both you and the recipient must be in the room. Rejoin or choose someone in the room.',
      'room unavailable or gifts disabled' =>
        'This room is unavailable or gifts are disabled. Check with the room owner.',
      'gift permission required' =>
        'You need permission to send gifts in this room. Check with the room owner.',
      'gift unavailable' => 'This gift is unavailable. Choose another gift.',
      'receiver unavailable' =>
        'This recipient is unavailable. Choose another recipient.',
      'moment receiver mismatch' =>
        'This Moment is no longer available for this recipient. Reopen Moments and try again.',
      'not authenticated' => 'Please sign in again before sending a gift.',
      'account restricted' =>
        'Gift sending is unavailable for your account. Contact support.',
      'wallet unavailable' => 'The wallet is unavailable. Please retry later.',
      'banned from room' =>
        'Gift sending is unavailable for this room membership.',
      _ => null,
    };
    if (message != null)
      return GiftRejectedException(message, code: error.code);
  }
  return mapError(error);
}
