# Settings and support database contract

Migration: `supabase/migrations/20261008165336_settings_support_requests.sql`.

Authenticated RPCs derive ownership exclusively from `auth.uid()`:

| RPC | Arguments | Result |
| --- | --- | --- |
| `user_settings` | none | JSON booleans `message_notifications`, `gift_notifications`, `allow_messages_from_everyone`, all default true |
| `update_user_settings` | `p_message_notifications`, `p_gift_notifications`, `p_allow_messages_from_everyone`: required booleans | same JSON, saved to the account |
| `submit_support_ticket` | `p_category`: feedback/bug/account/other; `p_subject`: trimmed 1–120 characters; `p_body`: trimmed 1–4000 | `{id,status:"submitted",created_at}` |
| `respond_support_ticket` | admin only; `p_ticket`: UUID; `p_response`: trimmed 1–4000; `p_close`: required boolean | `{id,status,response,responded_at}` |
| `request_account_deletion` | `p_reason`: text, default empty, max 1000 characters | `{id,status:"requested",created_at}`; repeat calls return the pending request |

`allow_messages_from_everyone=false` means the recipient does not accept incoming private text, emoji, or room invitations. It does not invent a friends/followers exception. The database rejects those message inserts, including through the existing `send_message` RPC. Gift receipt messages continue to record settlements. Existing blocking behavior remains in `send_message`.

Notification settings suppress creation of new `notifications` rows in the exact `messages` and `gifts` categories. Existing notifications remain visible. Message delivery still succeeds with message notifications disabled. A new AFTER INSERT trigger on `gift_events` inserts one `gifts` notification for the receiver using the gift name and quantity. This covers room, Moment, and profile gift settlements without modifying their economic functions. Existing RPC retries create no new gift event, so they create no duplicate notification. Self gift events follow the receiver preference too; the trigger does not alter which RPCs permit self gifts. There is no historical backfill or push delivery system.

`user_preferences`, `support_tickets`, and `account_deletion_requests` permit authenticated owner-only SELECT. Client INSERT/UPDATE/DELETE is revoked; RPCs validate inputs. Support intake serializes requests per account and limits submission to five tickets per hour. An administrator already recognized by the protected `public.is_admin()` role check can SELECT all tickets and respond using `respond_support_ticket`. Response text and `responded_at` are readable by the ticket owner; clients cannot write them directly. Tickets have no promised operator, invented email address, or response deadline. Deletion requests are intake records only: they do not delete profiles, auth users, wallets, or other data, and do not claim a processed deletion.

Online/visitor privacy is unsupported because no enforceable policy is defined. No preference is exposed for either setting.

Local verification uses the read-only metadata snapshot of the deployed schema with synthetic users in disposable PostgreSQL 17, with no production rows or writes:

```sh
python3 tools/verify_settings_support.py --snapshot /tmp/nimzo-postdeploy-schema.json
```

The suite checks missing authentication, defaults, account persistence, cross-account row isolation, direct write denial, required booleans, ticket categories/text bounds/rate limit, idempotent request-only deletion, enforced private messaging, notification suppression, re-enabling delivery, real profile gift settlement/replay with one notification, optout without changing settlement, self-event optout, unauthorized support response rejection, admin reading/replying, and owner reply visibility.
