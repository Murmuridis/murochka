import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'knit.dart';
import 'notifications.dart';
import 'screens/home_screen.dart';
import 'screens/reminder_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await Notifier.instance.init();
  Notifier.instance.onTap = _openReminder;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MurochkaApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final t = Notifier.instance.launchTap;
    if (t != null) {
      Notifier.instance.launchTap = null;
      _openReminder(t);
    }
  });
  Notifier.instance.requestPermissions().then((_) => Notifier.instance.rescheduleAll());
}

void _openReminder(ReminderTap t) {
  navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ReminderScreen(medId: t.medId, slot: t.slot, action: t.action)));
}

class MurochkaApp extends StatelessWidget {
  const MurochkaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Мурочка',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Wool.raspberry, surface: Wool.card, primary: Wool.raspberry),
          scaffoldBackgroundColor: Wool.cream,
          textTheme: ThemeData.light().textTheme.apply(bodyColor: Wool.ink, displayColor: Wool.ink),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Wool.card),
            trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Wool.green : Wool.cardEdge),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        home: const HomeScreen(),
      );
}
