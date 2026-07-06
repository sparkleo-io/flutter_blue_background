import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ble/ble_controller.dart';
import '../screens/adapter_screen.dart';
import '../screens/connection_query_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/service_screen.dart';

class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MainShellBody();
  }
}

class _MainShellBody extends StatefulWidget {
  const _MainShellBody();

  @override
  State<_MainShellBody> createState() => _MainShellBodyState();
}

class _MainShellBodyState extends State<_MainShellBody> {
  int _selectedIndex = 0;

  static const _titles = ['Service', 'Adapter', 'Scan', 'Connection'];

  final _pages = const [
    ServiceScreen(),
    AdapterScreen(),
    ScanScreen(),
    ConnectionQueryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE example — ${_titles[_selectedIndex]}'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Service',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'Adapter',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link),
            label: 'Connection',
          ),
        ],
      ),
    );
  }
}

/// Registers [BleController] once for the whole app shell.
class BleExampleApp extends StatelessWidget {
  const BleExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter Blue Background example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(BleController(), permanent: true);
      }),
      home: const MainShellScreen(),
    );
  }
}
