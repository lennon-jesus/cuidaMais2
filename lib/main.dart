// ignore_for_file: use_build_context_synchronously
import 'settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

enum AppThemeMode { system, light, dark }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final seenWelcome = prefs.getBool("seenWelcome") ?? false;
  final themeIndex = prefs.getInt('themeMode') ?? 0;

  runApp(
    MedApp(
      showWelcome: !seenWelcome,
      initialTheme: AppThemeMode.values[themeIndex],
    ),
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(settings);
  }

  Future<void> scheduleWeeklyNotification(
    int id,
    String title,
    String body,
    TimeOfDay time,
    int weekday,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _notifications.zonedSchedule(
      id & 0x7FFFFFFF,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Lembretes',
          channelDescription: 'Notificações de medicamentos',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

class MedApp extends StatefulWidget {
  final bool showWelcome;
  final AppThemeMode initialTheme;

  const MedApp({
    super.key,
    required this.showWelcome,
    required this.initialTheme,
  });

  @override
  State<MedApp> createState() => _MedAppState();
}

class _MedAppState extends State<MedApp> {
  late AppThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialTheme;
  }

  void _changeTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    setState(() {
      _themeMode = mode;
    });
  }

  ThemeMode get currentThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
Widget build(BuildContext context) {
  // Converte AppThemeMode → ThemeMode
  ThemeMode currentThemeMode;
  switch (_themeMode) {
    case AppThemeMode.light:
      currentThemeMode = ThemeMode.light;
      break;
    case AppThemeMode.dark:
      currentThemeMode = ThemeMode.dark;
      break;
    case AppThemeMode.system:
    default:
      currentThemeMode = ThemeMode.system;
  }

  return MaterialApp(
    title: 'Gerenciador de Medicamentos',
    theme: ThemeData(
      primarySwatch: Colors.teal,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.teal.shade50,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.teal,
      scaffoldBackgroundColor: const Color(0xFF1E164B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E164B),
        foregroundColor: Colors.white,
      ),
    ),
    themeMode: currentThemeMode, // ✅ usa o modo atual
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('pt', 'BR')],
    routes: {
      '/settings': (context) => SettingsScreen(
            currentTheme: _themeMode,
            onThemeChanged: _changeTheme, // ✅ adiciona callback
          ),
    },
    home: widget.showWelcome
        ? const WelcomeScreen() // ✅ fixo, sempre claro
        : HomeScreen(
            onThemeChanged: _changeTheme,
            currentTheme: _themeMode,
          ),
  );
}

}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _goToHome(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("seenWelcome", true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
Widget build(BuildContext context) {
  return Theme(
    data: ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.teal.shade100,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.teal.shade100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(image: AssetImage('assets/images/logosemitrans.png')),
              const SizedBox(height: 20),
              const Text(
                "Bem-vindo ao gerenciador de medicamentos Cuida+",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Aqui você pode cadastrar seus remédios e organizar sua rotina de forma prática.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.teal,
                ),
                onPressed: () => _goToHome(context),
                child: const Text(
                  "Entrar",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

}

// Função auxiliar para formatar dias
String formatarDias(List<bool> days) {
  const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  if (days.every((d) => !d)) return "Nenhum dia";
  if (days.every((d) => d)) return "Todos os dias";
  return [
    for (int i = 0; i < days.length; i++)
      if (days[i]) nomes[i],
  ].join(', ');
}
