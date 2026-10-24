import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_state.dart';
import 'ui/shell.dart';

void main() {
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const InvestorAgentApp()));
}

class InvestorAgentApp extends StatelessWidget {
  const InvestorAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Shelfwise · Investor Update Agent',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
        radius: BorderRadius.circular(12),
      ),
      home: const Shell(),
    );
  }
}
