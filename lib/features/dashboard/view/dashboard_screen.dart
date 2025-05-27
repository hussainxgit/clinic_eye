import 'package:clinic_eye/core/locale/l10n/app_localizations.dart';
import 'package:clinic_eye/core/views/screens/settings_screen.dart';
import 'package:clinic_eye/features/patient/view/patient_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../appointment/view/appointments_screen.dart';
import '../../doctor/view/doctors_screen.dart';

// Provider for selected navigation index
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const DashboardScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isExtended = true;

  // List of GlobalKeys for each Navigator to manage separate stacks
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Screens to display in the dashboard
  List<Widget> _getScreens(AppLocalizations l10n) {
    return [
      const AppointmentsScreen(),
      const DoctorsScreen(),
      const PatientsScreen(),
      Center(child: Text(l10n.payments, style: const TextStyle(fontSize: 24))),
      Center(child: Text(l10n.messages, style: const TextStyle(fontSize: 24))),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Row(
        children: [
          _buildNavigationRail(selectedIndex, l10n),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildNavigator(selectedIndex, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(int selectedIndex, AppLocalizations l10n) {
    return NavigationRail(
      extended: _isExtended,
      minExtendedWidth: 200,
      labelType: NavigationRailLabelType.none,
      leading: IconButton(
        icon: Icon(_isExtended ? Icons.menu_open : Icons.menu),
        color: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => setState(() => _isExtended = !_isExtended),
      ),
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.calendar_today_outlined),
          selectedIcon: const Icon(Icons.calendar_today),
          label: Text(l10n.appointments),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.people_outline),
          selectedIcon: const Icon(Icons.people),
          label: Text(l10n.doctors),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: Text(l10n.patients),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.payments_outlined),
          selectedIcon: const Icon(Icons.payments),
          label: Text(l10n.payments),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.message_outlined),
          selectedIcon: const Icon(Icons.message),
          label: Text(l10n.messages),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(l10n.settings),
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        ref.read(selectedNavIndexProvider.notifier).state = index;
      },
    );
  }

  // Build a Navigator for the selected screen
  Widget _buildNavigator(int selectedIndex, AppLocalizations l10n) {
    final screens = _getScreens(l10n);
    return Navigator(
      key: _navigatorKeys[selectedIndex],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => screens[selectedIndex],
          settings: settings,
        );
      },
    );
  }
}
