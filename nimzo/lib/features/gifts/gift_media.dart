import 'gift_svga_overlay.dart';
import 'hall_of_fame_gift.dart';
import 'private_animal_gifts.dart';
import 'zodiac_gifts.dart';

/// Decoder requirements belong to verified gift identities, never display names.
bool isVapGift(String giftId) =>
    giftId == hallOfFameGiftId ||
    zodiacVapGiftIds.contains(giftId) ||
    privateAnimalVapGiftIds.contains(giftId);

bool hasGiftAnimation(String giftId) =>
    freeGiftAnimationForId(giftId) != null ||
    isVapGift(giftId) ||
    stagedAnimatedGiftIds.contains(giftId);

// Reserved preview identities remain governed by server active/media gates.
const stagedAnimatedGiftIds = <String>{
  'fa1bc74b-02e0-5d55-9dc1-e71d451c335f',
  'a7e8f51d-4bcc-572c-a341-d49b2c3161dc',
  'dbe66ab1-6b9c-5326-9b79-155d4d14e3d7',
};
