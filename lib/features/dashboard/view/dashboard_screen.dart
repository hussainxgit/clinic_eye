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
  final List<Widget> _screens = [
    const DoctorsScreen(),
    const PatientsScreen(),
    const AppointmentsScreen(),
    const Center(child: Text('Payments', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Messages', style: TextStyle(fontSize: 24))),
    const SettingsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appName),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Row(
        children: [
          _buildNavigationRail(selectedIndex),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildNavigator(selectedIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(int selectedIndex) {
    return NavigationRail(
      extended: _isExtended,
      minExtendedWidth: 200,
      labelType: NavigationRailLabelType.none,
      leading: IconButton(
        icon: Icon(_isExtended ? Icons.menu_open : Icons.menu),
        color: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => setState(() => _isExtended = !_isExtended),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Doctors'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Patients'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: Text('Appointments'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments),
          label: Text('Payments'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.message_outlined),
          selectedIcon: Icon(Icons.message),
          label: Text('Messages'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        ref.read(selectedNavIndexProvider.notifier).state = index;
      },
    );
  }

  // Build a Navigator for the selected screen
  Widget _buildNavigator(int selectedIndex) {
    return Navigator(
      key: _navigatorKeys[selectedIndex],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => _screens[selectedIndex],
          settings: settings,
        );
      },
    );
  }
}
