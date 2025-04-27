import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_theme.dart';
import 'core/config/dependencies.dart';
import 'core/services/firebase/firebase_service.dart';
import 'features/dashboard/view/dashboard_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Failed to load .env.development file: $e');
  }
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize dependencies
    final firebaseService = FirebaseService();
    await setupDependencies(firebaseService);
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }

  // Use ProviderScope with overrides from the container
  runApp(
    ProviderScope(
      overrides: [firebaseServiceProvider.overrideWithValue(FirebaseService())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clinic Eye',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DashboardScreen(
        toggleTheme: () {
          ref.read(themeModeProvider.notifier).state = !isDarkMode;
        },
        isDarkMode: isDarkMode,
      ),
    );
  }
}
