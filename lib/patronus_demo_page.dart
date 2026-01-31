import 'package:flutter/material.dart';
import 'patronus_loader.dart';
import 'animated_gradient_text.dart';

class PatronusDemoPage extends StatelessWidget {
  const PatronusDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AnimatedGradientText('Patronus – Démo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const PatronusLoader(duration: Duration(seconds: 2)),
    );
  }
}