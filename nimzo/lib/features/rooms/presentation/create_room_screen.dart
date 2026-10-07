import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/nimzo_button.dart';
import '../../../core/widgets/nimzo_text_field.dart';
import 'room_controller.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  ConsumerState<CreateRoomScreen> createState() => _S();
}

class _S extends ConsumerState<CreateRoomScreen> {
  final _n = TextEditingController();
  Country? country;
  bool busy = false;
  @override
  void dispose() { _n.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create room')),
        body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          NimzoTextField(controller: _n, label: 'Room name'),
          const SizedBox(height: 12),
          ListTile(
            tileColor: const Color(0xFFF8FAFC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(country?.name ?? 'Select country'), trailing: const Icon(Icons.expand_more),
            onTap: () => showCountryPicker(context: context, onSelect: (c) => setState(() => country = c)),
          ),
          const SizedBox(height: 20),
          NimzoButton(label: 'Create', loading: busy, onPressed: () async {
            final name = _n.text.trim();
            if (name.isEmpty || name.length > 40) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room name must contain 1 to 40 characters.')),
              );
              return;
            }
            setState(() => busy = true);
            try {
              final id = await ref.read(roomRepositoryProvider).create(name, country: country?.name);
              ref.invalidate(newRoomsProvider);
              ref.invalidate(myRoomsProvider);
              ref.invalidate(popularRoomsProvider(null));
              if (context.mounted) context.pushReplacement('/room/$id');
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            } finally { if (mounted) setState(() => busy = false); }
          }),
        ])),
      );
}
