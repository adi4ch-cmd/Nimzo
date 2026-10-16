import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MembershipRemovalTest(unittest.TestCase):
    def test_no_legacy_or_free_membership_surface(self):
        for folder in (
            "nimzo/lib/features/membership",
            "nimzo/assets/membership",
            "nimzo/assets/reference/vip",
        ):
            self.assertFalse((ROOT / folder).exists(), folder)
        for path in (
            "nimzo/lib/features/profile/retired_membership_screen.dart",
            "nimzo/test/free_royal_membership_test.dart",
        ):
            self.assertFalse((ROOT / path).exists(), path)

    def test_old_links_safely_return_to_profile(self):
        router = (ROOT / "nimzo/lib/app/router.dart").read_text()
        self.assertIn("GoRoute(path: '/vip', redirect: (_, __) => Routes.profile)", router)
        self.assertIn("GoRoute(path: '/svip', redirect: (_, __) => Routes.profile)", router)
        self.assertNotIn("RoyalMembershipScreen", router)
        me = (ROOT / "nimzo/lib/features/profile/me_screen.dart").read_text()
        for legacy in ("('VIP',", "('SVIP',", "RoyalIdentityBadge",
                       "RoyalAvatarHalo", "'/vip'", "'/svip'"):
            self.assertNotIn(legacy, me)

    def test_no_badges_frames_or_room_chat_membership_art(self):
        for relative in (
            "nimzo/lib/features/profile/me_screen.dart",
            "nimzo/lib/features/profile/profile_screen.dart",
            "nimzo/lib/features/rooms/presentation/room_screen.dart",
            "nimzo/lib/features/rooms/presentation/room_user_sheet.dart",
        ):
            text = (ROOT / relative).read_text()
            for name in ("RoyalAvatarHalo", "RoyalIdentityBadge",
                         "RoyalChatHalo", "freeRoyalSelectionProvider"):
                self.assertNotIn(name, text, relative)
        pubspec = (ROOT / "nimzo/pubspec.yaml").read_text()
        self.assertNotIn("assets/membership/", pubspec)
        self.assertIn("version: 1.0.27+127", pubspec)

    def test_no_new_purchase_or_free_activation_api(self):
        sql = (ROOT / "supabase/migrations/20261016170000_remove_all_vip_svip_user_state.sql").read_text()
        self.assertIn("DROP TABLE IF EXISTS public.free_memberships", sql)
        self.assertIn("DROP FUNCTION IF EXISTS public.activate_free_membership", sql)
        self.assertIn("vip_last_claim=NULL", sql)
        self.assertIn("svip_last_claim=NULL", sql)
        self.assertIn("preserved_ledger_rows", sql)


if __name__ == "__main__":
    unittest.main()
