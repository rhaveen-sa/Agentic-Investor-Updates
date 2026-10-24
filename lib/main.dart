import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) await windowManager.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const InvestorAgentApp()));
}

class InvestorAgentApp extends StatelessWidget {
  const InvestorAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return ShadApp(
      title: 'Ledger',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
        radius: BorderRadius.circular(12),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
        radius: BorderRadius.circular(12),
      ),
      home: const Shell(),
    );
  }
}
