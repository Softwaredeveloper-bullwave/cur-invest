import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/paper_only_mode.dart';
import '../constants/routes.dart';

/// Redirects to home when [PaperOnlyMode.enabled] — use on real-money screens.
class PaperOnlyGate extends StatefulWidget {
  final Widget child;

  const PaperOnlyGate({super.key, required this.child});

  @override
  State<PaperOnlyGate> createState() => _PaperOnlyGateState();
}

class _PaperOnlyGateState extends State<PaperOnlyGate> {
  @override
  void initState() {
    super.initState();
    if (PaperOnlyMode.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppRoutes.home);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PaperOnlyMode.enabled) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
