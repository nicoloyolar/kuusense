import 'package:flutter/material.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Centers page content at a comfortable reading width.
class DashPage extends StatelessWidget {
  const DashPage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(
      horizontal: KuuSpacing.lg,
      vertical: KuuSpacing.xl,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1232),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}
