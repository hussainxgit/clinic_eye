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

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);

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
            leading:
                _isExtended
                    ? IconButton(
                      icon: const Icon(Icons.menu_open),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () {
                        setState(() {
                          _isExtended = !_isExtended;
                        });
                      },
                    )
                    : IconButton(
                      icon: const Icon(Icons.menu),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () {
                        setState(() {
                          _isExtended = !_isExtended;
                        });
                      },
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
            onDestinationSelected: (int index) {
              ref.read(selectedNavIndexProvider.notifier).state = index;
            },
          ),
          // Main content area
          Expanded(
            child: Navigator(
              key: const ValueKey('mainContent'),
              onGenerateRoute: (RouteSettings settings) {
                return MaterialPageRoute(
                  builder: (context) => _buildContentArea(selectedIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(int selectedIndex) {
    final List<Widget> pages = [
      const DoctorsScreen(),
      const PatientListScreen(),
      const Center(child: Text('Appointments', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Payments', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Messages', style: TextStyle(fontSize: 24))),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      child: pages[selectedIndex],
    );
  }
}
