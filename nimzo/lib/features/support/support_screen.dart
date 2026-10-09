import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import 'support_repository.dart';

const supportFaqs = {
  'How do I recharge?': 'Open Recharge and choose an available store package. The server verifies purchases before crediting coins. For a missing purchase, report the store, product, date and non-sensitive transaction reference.',
  'How do VIP and SVIP work?': 'Open VIP or SVIP to view the current tiers and benefits. Check the displayed details before spending coins.',
  'How do I report another user?': 'Use the report action on the relevant profile or room when available. You can also block users from their profile.',
  'Does a deletion request delete my account?': 'No. It records a request for review. Your account remains active and no completion time is confirmed.',
};

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help and feedback')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: SupportHelpContent(),
    ),
  );
}

class SupportHelpContent extends ConsumerStatefulWidget {
  const SupportHelpContent({super.key});
  @override
  ConsumerState<SupportHelpContent> createState() => _SupportState();
}

class _SupportState extends ConsumerState<SupportHelpContent> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = 'feedback';
  bool _busy = false;
  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final id = ref.read(currentUserIdProvider);
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .submit(_category, _subject.text, _body.text);
      if (!mounted || ref.read(currentUserIdProvider) != id) return;
      _subject.clear();
      _body.clear();
      ref.invalidate(supportTicketsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket submitted. You can view it below.'),
        ),
      );
    } catch (_) {
      if (mounted && ref.read(currentUserIdProvider) == id)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not submit. Check your connection and retry. Limit: five tickets per hour.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next) {
        _subject.clear();
        _body.clear();
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final faq in supportFaqs.entries)
          ExpansionTile(
            title: Text(faq.key),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(faq.value),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'Send feedback or report a bug',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Do not send passwords, verification codes, payment credentials or unnecessary personal information. No response time is guaranteed.',
        ),
        if (id == null)
          const Text('Sign in to submit and view your tickets.')
        else ...[
          Form(
            key: _form,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final pair in const {
                      'feedback': 'Feedback',
                      'bug': 'Bug report',
                      'account': 'Account',
                      'other': 'Other',
                    }.entries)
                      DropdownMenuItem(
                        value: pair.key,
                        child: Text(pair.value),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _category = v!),
                ),
                TextFormField(
                  controller: _subject,
                  enabled: !_busy,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a subject.' : null,
                ),
                TextFormField(
                  controller: _body,
                  enabled: !_busy,
                  maxLength: 4000,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'For bugs, describe what happened and how to reproduce it.',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter details.' : null,
                ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Submitting…' : 'Submit ticket'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your tickets',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh tickets',
                onPressed: () => ref.invalidate(supportTicketsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          ref
              .watch(supportTicketsProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => TextButton(
                  onPressed: () => ref.invalidate(supportTicketsProvider),
                  child: const Text('Tickets could not be loaded. Retry'),
                ),
                data: (rows) => rows.isEmpty
                    ? const Text('No tickets yet.')
                    : Column(
                        children: [
                          for (final row in rows)
                            ExpansionTile(
                              title: Text(
                                row['subject']?.toString() ?? 'Support ticket',
                              ),
                              subtitle: Text(
                                '${row['status'] ?? 'submitted'} · ${row['created_at'] ?? ''}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    row['body']?.toString() ?? '',
                                  ),
                                ),
                                if (row['response'] != null)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Support reply',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SelectableText(
                                          row['response'].toString(),
                                        ),
                                        if (row['responded_at'] != null)
                                          Text(row['responded_at'].toString()),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
              ),
        ],
      ],
    );
  }
}

class AccountDeletionRequestContent extends ConsumerStatefulWidget {
  const AccountDeletionRequestContent({super.key});
  @override
  ConsumerState<AccountDeletionRequestContent> createState() =>
      _DeletionState();
}

class _DeletionState extends ConsumerState<AccountDeletionRequestContent> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final id = ref.read(currentUserIdProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'This records a request for review. It does not delete your account or data, cancel memberships, or sign you out. No completion time is confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || ref.read(currentUserIdProvider) != id)
      return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(supportRepositoryProvider).requestDeletion(_reason.text);
      if (mounted && ref.read(currentUserIdProvider) == id)
        setState(
          () => _message = 'Deletion request recorded for review. Your account remains active.',
        );
    } catch (_) {
      if (mounted && ref.read(currentUserIdProvider) == id)
        setState(
          () => _message = 'Could not record the request. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentUserIdProvider);
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next) {
        _reason.clear();
        setState(() => _message = null);
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'Account deletion request',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Request review of account deletion. This does not delete your account or data. No completion timeframe is confirmed.',
        ),
        TextField(
          controller: _reason,
          enabled: id != null && !_busy,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        OutlinedButton(
          onPressed: id == null || _busy ? null : _request,
          child: Text(_busy ? 'Submitting…' : 'Request account deletion'),
        ),
        if (id == null) const Text('Sign in to request account deletion.'),
        if (_message != null) Text(_message!),
      ],
    );
  }
}
