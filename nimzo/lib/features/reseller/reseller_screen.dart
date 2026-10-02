import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/nimzo_button.dart';
import '../../core/widgets/nimzo_text_field.dart';
import 'reseller_repository.dart';

class ResellerScreen extends ConsumerStatefulWidget {
  const ResellerScreen({super.key});
  @override
  ConsumerState<ResellerScreen> createState() => _S();
}

class _S extends ConsumerState<ResellerScreen> {
  final _id = TextEditingController(), _amt = TextEditingController();
  Map<String, dynamic>? user;
  bool busy = false;
  @override
  void dispose() { _id.dispose(); _amt.dispose(); super.dispose(); }
  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(resellerRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reseller recharge')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        NimzoTextField(controller: _id, label: 'User ID', keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        NimzoButton(label: 'Verify user', outlined: true, onPressed: () async {
          user = await repo.verifyUser(int.tryParse(_id.text) ?? -1);
          setState(() {});
          if (user == null) _msg('User not found');
        }),
        if (user != null) ...[
          const SizedBox(height: 12),
          Text('Recharging ${user!['display_name']}'),
          const SizedBox(height: 12),
          NimzoTextField(controller: _amt, label: 'Coin amount', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          NimzoButton(label: 'Send coins', loading: busy, onPressed: () async {
            final n = int.tryParse(_amt.text);
            if (n == null || n <= 0) return _msg('Enter a valid amount');
            setState(() => busy = true);
            try {
              await repo.recharge(user!['id'], n, 'rs-${DateTime.now().microsecondsSinceEpoch}');
              _msg('Coins sent');
            } catch (e) { _msg('$e'); } finally { if (mounted) setState(() => busy = false); }
          }),
        ],
      ]),
    );
  }
}
