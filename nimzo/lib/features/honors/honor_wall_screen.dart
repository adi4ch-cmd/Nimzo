import 'package:flutter/material.dart';
import '../settings/honor_wall_content.dart';

class HonorWallScreen extends StatelessWidget {
  const HonorWallScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Honor Wall')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: HonorWallContent(),
        ),
      );
}
