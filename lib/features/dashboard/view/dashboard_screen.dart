import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/dependencies.dart';
import '../../doctor/view/doctors_screen.dart';
import '../../patient/view/patient_list_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function toggleTheme;
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

  // Navigator keys for each section
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

    // Sync page controller with selected index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != selectedIndex) {
        _pageController.jumpToPage(selectedIndex);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Eye'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.toggleTheme(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
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
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              ref.read(selectedNavIndexProvider.notifier).state = index;
            },
          ),
          // Main content with PageView and nested Navigator for each page
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: PageView(
                key: ValueKey<int>(selectedIndex),
                controller: _pageController,                
                scrollDirection: Axis.vertical,
                onPageChanged: (index) {
                  ref.read(selectedNavIndexProvider.notifier).state = index;
                },
                children: List.generate(5, (index) => _buildNavigator(index)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => _getScreen(index),
          );
        }
        return null;
      },
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const DoctorsScreen();
      case 1:
        return const PatientListScreen();
      case 2:
        return const Center(
          child: Text('Appointments', style: TextStyle(fontSize: 24)),
        );
      case 3:
        return const Center(
          child: Text('Payments', style: TextStyle(fontSize: 24)),
        );
      case 4:
        return const Center(
          child: Text('Messages', style: TextStyle(fontSize: 24)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
