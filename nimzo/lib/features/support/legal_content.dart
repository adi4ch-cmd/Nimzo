import 'package:flutter/material.dart';

const legalDraftNotice =
    'Draft — requires owner and legal review. These documents describe the current implementation and proposed rules. They are not approved final policies.';
const legalPolicies = <String, String>{
  'Privacy Policy':
      '''Nimzo uses account authentication and stores profile information, social connections, room activity, messages, moments, notifications, wallet and purchase records, and support requests to provide its features. Information you publish in profiles, rooms, or moments may be visible to other users. Private messages are associated with their participants.

The implementation uses Supabase for authentication and application data. Voice features integrate with Vivox. Purchases use the platform store and server verification. Do not include passwords, verification codes, payment credentials, or unnecessary sensitive information in support tickets.

Blocking controls and account settings are available in the app. Account deletion is currently a request for review; submitting it does not delete your account or data.

Before publication, the owner must confirm the operator identity and contact channel, service providers and disclosures, legal bases, international transfers, retention periods, age eligibility, and the process for exercising privacy rights. No retention duration or legal jurisdiction has been confirmed.''',
  'Terms of Service':
      '''Nimzo provides social profiles, rooms, messaging, moments, virtual gifts, and membership features. Availability depends on the service and the account's access. Protect your login credentials and use accurate information where required.

Use the service lawfully and respect other users. Do not impersonate others, gain unauthorized access, manipulate balances or purchases, or interfere with the service. Virtual balances and gifts are recorded by the backend; do not assume they can be redeemed for money or transferred outside the supported app flows.

Store purchases are subject to the applicable store's purchase process. A support ticket does not establish refund eligibility. Membership benefits depend on the current tier and implementation.

Before publication, the owner must approve the contracting entity, contact channel, eligibility requirements, payment and virtual-item terms, termination rules, dispute terms, liability terms, governing law, and policy change process. This draft does not invent those terms.''',
  'Community Guidelines':
      '''Treat people respectfully in rooms, messages, profiles, and moments. Do not harass, threaten, exploit, discriminate against, or impersonate others. Do not share another person's private information without permission. Do not publish illegal content or facilitate fraud or abuse.

Room owners and authorized moderators have room controls. Users can block other users and submit reports through available reporting tools. Help and feedback accepts bug reports and account questions; provide enough context without including secrets or unnecessary personal information.

These are proposed community standards. Before publication, the owner must approve age and content rules, moderation responsibilities, enforcement criteria, appeal routes, and the handling of urgent safety reports. No response time or enforcement outcome is promised by this draft.''',
  'Refund Policy':
      '''Recharge purchases use the platform store and server-side purchase verification. The app records verified purchases and virtual balances. A verification failure or delayed balance should be raised through Help and feedback with the store, product, date, and a non-sensitive transaction reference. Do not send payment credentials or full receipts containing personal information.

The app does not currently offer a self-service refund action. Submitting a ticket does not issue a refund, reverse a gift, or change a wallet balance. Consult the purchase platform's refund process where applicable.

Before publication, the owner must confirm refund eligibility, deadlines, exceptions, handling of consumed virtual items and memberships, store responsibilities, and the applicable consumer rights. No blanket no-refund rule or refund promise has been approved.''',
  'Account Deletion Policy':
      '''You can submit an account deletion request from Account settings. The request is associated with your signed-in account and may include an optional reason. A pending request is recorded for review.

Submitting a request does not delete your account, sign you out, cancel purchases or memberships, or remove your messages and other data. There is no automatic deletion workflow in the current implementation.

Before publication, the owner must confirm who processes requests, identity verification, cancellation and withdrawal procedures, the handling of public and shared content, legal retention requirements, completion timeframes, and how users receive confirmation. No deletion deadline or data-retention period has been confirmed.''',
};

class LegalPoliciesContent extends StatelessWidget {
  const LegalPoliciesContent({super.key});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
              padding: EdgeInsets.all(12), child: Text(legalDraftNotice)),
          for (final policy in legalPolicies.entries)
            ExpansionTile(
              title: Text(policy.key),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(policy.value),
                ),
              ],
            ),
        ],
      );
}
