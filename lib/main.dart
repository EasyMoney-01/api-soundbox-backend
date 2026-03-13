import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/attack_screen.dart';
import 'screens/history_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const UpiSoundboxApp());
}

class UpiSoundboxApp extends StatelessWidget {
  const UpiSoundboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPI Soundbox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ScannerScreen(),
    AttackScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black12,
        elevation: 8,
        indicatorColor: AppTheme.primaryBlue.withOpacity(0.12),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primaryBlue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering, color: AppTheme.primaryBlue),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: const Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send, color: AppTheme.primaryBlue),
            label: 'Inject',
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppTheme.primaryBlue),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
