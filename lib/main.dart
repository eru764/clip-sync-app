import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load();
  
  // Only initialize window manager and tray on Windows
  if (Platform.isWindows) {
    // Initialize window manager
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    
    // Initialize system tray
    await _initSystemTray();
  }
  
  runApp(const ClipSyncApp());
}

Future<void> _initSystemTray() async {
  if (!Platform.isWindows) return;
  
  // Set tray icon - use app icon from resources
  String iconPath = 'windows/runner/resources/app_icon.ico';
  
  await trayManager.setIcon(iconPath);
  
  // Set tooltip
  await trayManager.setToolTip('ClipSync - Monitoring clipboard');
  
  // Create context menu
  Menu menu = Menu(
    items: [
      MenuItem(
        key: 'show_window',
        label: 'Show ClipSync',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: 'Quit',
      ),
    ],
  );
  
  await trayManager.setContextMenu(menu);
}

class ClipSyncApp extends StatefulWidget {
  const ClipSyncApp({super.key});

  @override
  State<ClipSyncApp> createState() {
    if (Platform.isWindows) {
      return _ClipSyncAppWindowsState();
    } else {
      return _ClipSyncAppMobileState();
    }
  }
}

// Windows-specific state with tray and window manager
class _ClipSyncAppWindowsState extends State<ClipSyncApp> with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'quit') {
      windowManager.destroy();
      exit(0);
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipSync',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// Mobile-specific state without window/tray manager
class _ClipSyncAppMobileState extends State<ClipSyncApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipSync',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// Check for saved token and route accordingly
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
