import 'package:flutter/material.dart';

class NimzoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  const NimzoTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    validator: validator,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
  );
}
