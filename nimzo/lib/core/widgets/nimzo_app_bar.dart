import 'package:flutter/material.dart';

class NimzoAppBar extends AppBar {
  NimzoAppBar({super.key, required String title, super.actions})
      : super(title: Text(title), centerTitle: false, elevation: 0, scrolledUnderElevation: 0);
}
