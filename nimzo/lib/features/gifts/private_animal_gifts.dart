/// Private premium media is downloaded only through the authenticated gateway.
/// No raw Phoenix/Tiger animation or thumbnail is bundled in the application.
const phoenixGiftId = '629b0f33-55b5-5084-8488-865869e9ab39';
const holyTigerGiftId = '2f869219-7cdd-531b-9715-c5d8c9cd864d';
const animalGiftPriceCoins = 1000000;
const privateHallOfFameGiftId = '53f6278f-1770-5be9-ae07-329c34f36c47';
const privateDragonThroneGiftId = '5e07ac17-491a-4a26-a48b-e6701445705f';
const privateAnimalGiftNames = <String, String>{
  privateHallOfFameGiftId: 'Hall of Fame',
  privateDragonThroneGiftId: 'Dragon Throne',
  phoenixGiftId: 'Ice Fire Phoenix',
  holyTigerGiftId: 'Holy Tiger',
};
const privateAnimalVapGiftIds = <String>{
  privateHallOfFameGiftId,
  privateDragonThroneGiftId,
  phoenixGiftId,
  holyTigerGiftId,
};
String? privateAnimalGiftIdForName(String name) {
  final normalized = name.trim().toLowerCase();
  for (final entry in privateAnimalGiftNames.entries) {
    if (entry.value.toLowerCase() == normalized) return entry.key;
  }
  return null;
}
