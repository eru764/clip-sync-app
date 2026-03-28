import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load();
  
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
  
  runApp(const ClipSyncApp());
}

Future<void> _initSystemTray() async {
  // Set tray icon - use app icon from resources
  String iconPath = Platform.isWindows
      ? 'windows/runner/resources/app_icon.ico'
      : 'assets/app_icon.png';
  
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
  State<ClipSyncApp> createState() => _ClipSyncAppState();
}

class _ClipSyncAppState extends State<ClipSyncApp> with TrayListener, WindowListener {
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
    // Show window when tray icon is clicked
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Show context menu on right click
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
    // Hide to tray instead of closing
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
      home: const LoginScreen(),
    );
  }
}
