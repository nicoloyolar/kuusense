import 'package:flutter/material.dart';

/// Sets the browser tab title to `KúuSense - <page>`.
class PageTitle extends StatelessWidget {
  const PageTitle(this.page, {super.key, required this.child});
  final String page;
  final Widget child;

  @override
  Widget build(BuildContext context) => Title(
    title: 'KúuSense - $page',
    color: Theme.of(context).colorScheme.primary,
    child: child,
  );
}
