import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An offline arithmetic tool. It never reads or changes a wallet.
class RoomGiftCalculator extends StatefulWidget {
  const RoomGiftCalculator({super.key});
  @override
  State<RoomGiftCalculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<RoomGiftCalculator> {
  final price = TextEditingController(),
      quantity = TextEditingController(text: '1');
  @override
  void dispose() {
    price.dispose();
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = BigInt.tryParse(price.text),
        count = BigInt.tryParse(quantity.text);
    final total = unit != null && count != null && count > BigInt.zero
        ? (unit * count).toString()
        : null;
    final formatted = total?.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Gift calculator',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Color(0xff047857))),
      const Text(
          'Estimate the total before sending. This tool does not spend coins.'),
      const SizedBox(height: 16),
      TextField(
          key: const ValueKey('calculator-price'),
          controller: price,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12)
          ],
          decoration: const InputDecoration(labelText: 'Coins per gift'),
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      TextField(
          key: const ValueKey('calculator-quantity'),
          controller: quantity,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6)
          ],
          decoration: const InputDecoration(labelText: 'Quantity'),
          onChanged: (_) => setState(() {})),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
              formatted == null
                  ? 'Enter a price and a positive quantity.'
                  : '$formatted coins',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 24))),
      OutlinedButton(
          onPressed: () => setState(() {
                price.clear();
                quantity.text = '1';
              }),
          child: const Text('Clear')),
    ]));
  }
}
