import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/accessibility_service.dart';
import '../models/clip_model.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _authService = AuthService();
  late SocketService _socketService;
  final _textController = TextEditingController();
  final List<ClipModel> _clips = [];
  bool _isLoading = false;
  String? _token;
  Timer? _clipboardTimer;
  Timer? _pollingTimer;
  Timer? _pollTimer;
  String _lastClipboardContent = '';
  bool _isInitialized = false;
  StreamSubscription? _intentDataStreamSubscription;
  StreamSubscription? _accessibilityClipboardSubscription;
  bool _isAccessibilityServiceEnabled = true;
  bool _showAccessibilityBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeShareIntent();
    _initializeAccessibilityService();
  }

  void _initializeShareIntent() {
    if (!Platform.isAndroid) return;
    
    print('Share intent initialized');
    
    _intentDataStreamSubscription = ReceiveSharingIntent
        .instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      print('Received shared media: ${value.length} items');
      if (value.isNotEmpty) {
        print('First item message: ${value.first.message}');
        print('First item path: ${value.first.path}');
        final text = value.first.message ?? value.first.path ?? '';
        if (text.isNotEmpty) {
          _handleSharedText(text);
        }
      }
    });

    ReceiveSharingIntent.instance.getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        print('Initial media - First item message: ${value.first.message}');
        print('Initial media - First item path: ${value.first.path}');
        final text = value.first.message ?? value.first.path ?? '';
        if (text.isNotEmpty) {
          _handleSharedText(text);
          ReceiveSharingIntent.instance.reset();
        }
      }
    });
  }

  Future<void> _handleSharedText(String text) async {
    print('Handling shared text: $text');
    if (_token == null || _token!.isEmpty) return;

    try {
      final serverUrl = dotenv.env['SERVER_URL'] ?? 'http://localhost:3000';
      await http.post(
        Uri.parse('$serverUrl/clips'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'content': text,
          'type': 'text',
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clip synced from share!')),
        );
      }
    } catch (e) {
      print('Error syncing shared text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing: $e')),
        );
      }
    }
  }

  Future<void> _initializeAccessibilityService() async {
    if (!Platform.isAndroid) return;

    // Check if accessibility service is enabled
    final isEnabled = await AccessibilityService.isAccessibilityServiceEnabled();
    
    setState(() {
      _isAccessibilityServiceEnabled = isEnabled;
    });
    
    if (!isEnabled && mounted) {
      // Show bottom sheet explaining why accessibility service is needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAccessibilityServiceBottomSheet();
      });
    } else {
      // Listen to clipboard changes from accessibility service
      _accessibilityClipboardSubscription = AccessibilityService.clipboardStream.listen((content) {
        print('Accessibility clipboard changed: $content');
        if (content.isNotEmpty && content != _lastClipboardContent) {
          _lastClipboardContent = content;
          _autoSyncClipboard(content);
        }
      });
      
      // Start foreground service for background monitoring
      AccessibilityService.startForegroundService();
      
      // Request battery optimization exemption
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBatteryOptimizationDialog();
      });
    }
  }

  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'To sync clipboard in background, please tap \'Allow\' on the next screen to exempt ClipSync from battery optimization.\n\n'
            'This ensures ClipSync can monitor your clipboard even when the app is closed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                AccessibilityService.requestBatteryOptimizationExemption();
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showAccessibilityServiceBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.teal,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Enable Clipboard Monitoring',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'ClipSync needs Accessibility permission to automatically sync your clipboard across devices - including WhatsApp',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Step-by-step instructions
                _buildInstructionStep(
                  1,
                  Icons.settings,
                  "Tap 'Open Settings' below",
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  2,
                  Icons.accessibility,
                  "In Settings, tap 'Installed apps' or 'Downloaded apps'",
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  3,
                  Icons.phone_android,
                  "Find and tap 'ClipSync' in the list",
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  4,
                  Icons.toggle_on,
                  "Toggle ON 'ClipSync Clipboard Monitor'",
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(
                  5,
                  Icons.check_circle,
                  "Tap 'Allow' on the confirmation dialog",
                ),
                const SizedBox(height: 24),
                
                // Privacy note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'This permission only reads clipboard content to sync it across your devices. No data is shared with third parties.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _showAccessibilityBanner = true;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[700]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('I\'ll do it later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          AccessibilityService.openAccessibilitySettings();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Open Settings',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(int stepNumber, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          icon,
          color: Colors.teal,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Reconnect socket if disconnected
      if (_token != null && _token!.isNotEmpty) {
        _socketService.connect(_token!);
        
        // Fetch latest clips from server
        await _fetchClips();
      }
    } else if (state == AppLifecycleState.paused) {
      // Keep socket alive, do nothing
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Load token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      
      if (_token == null || _token!.isEmpty) {
        throw Exception('No token found in SharedPreferences');
      }
      
      // Initialize Socket.io service
      final serverUrl = dotenv.env['SERVER_URL'] ?? 'http://localhost:3000';
      _socketService = SocketService(serverUrl: serverUrl);
      
      // Save server URL for native background sync
      if (Platform.isAndroid) {
        await AccessibilityService.saveServerUrl(serverUrl);
      }
      
      // Connect and join room
      _socketService.connect(_token!);
      
      // Listen for new clips
      _socketService.onNewClip((data) {
        if (mounted) {
          setState(() {
            final clip = ClipModel.fromJson(data);
            _addClipIfNotDuplicate(clip);
          });
        }
      });
      
      // Fetch existing clips from server
      await _fetchClips();
      
      // Mark as initialized
      _isInitialized = true;
      
      // Start clipboard monitoring after initialization
      _startClipboardMonitoring();
      
      // Start aggressive polling on all platforms
      _startPolling();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  void _startClipboardMonitoring() {
    if (_clipboardTimer != null) return; // Already running
    
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkClipboard();
    });
  }

  void _stopClipboardMonitoring() {
    _clipboardTimer?.cancel();
    _clipboardTimer = null;
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _fetchLatestClips();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchLatestClips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) return;
      
      final serverUrl = dotenv.env['SERVER_URL'] ?? '';
      final response = await http.get(
        Uri.parse('$serverUrl/clips'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && mounted) {
          setState(() {
            for (var clipData in data) {
              if (clipData is Map<String, dynamic>) {
                final id = clipData['id']?.toString() ?? '';
                final exists = _clips.any((c) => c.id == id);
                if (!exists && id.isNotEmpty) {
                  try {
                    _clips.insert(0, ClipModel.fromJson(clipData));
                  } catch (e) {
                    print('Error parsing clip: $e');
                  }
                }
              }
            }
            while (_clips.length > 20) {
              _clips.removeLast();
            }
          });
        }
      }
    } catch (e) {
      // silent fail
    }
  }

  void _addClipIfNotDuplicate(ClipModel newClip) {
    // Check if a clip with same content exists in last 10 seconds
    final content = newClip.content;
    final isDuplicate = _clips.any((c) {
      try {
        final clipTime = c.timestamp is DateTime 
            ? c.timestamp as DateTime
            : DateTime.parse(c.timestamp.toString());
        return c.content == content && 
               DateTime.now().difference(clipTime).inSeconds < 10;
      } catch (e) {
        return false;
      }
    });
    
    if (!isDuplicate) {
      _clips.insert(0, newClip);
    }
  }

  Future<void> _checkClipboard() async {
    if (!_isInitialized) return;
    
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final currentContent = clipboardData?.text ?? '';

      if (currentContent.isNotEmpty && currentContent != _lastClipboardContent) {
        _lastClipboardContent = currentContent;
        await _autoSyncClipboard(currentContent);
      }
    } catch (e) {
      // Silently handle clipboard access errors
    }
  }

  Future<void> _autoSyncClipboard(String content) async {
    if (_token == null || _token!.isEmpty) return;
    
    try {
      final serverUrl = dotenv.env['SERVER_URL'] ?? 'http://localhost:3000';
      await http.post(
        Uri.parse('$serverUrl/clips'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'content': content,
          'type': 'text',
        }),
      );
    } catch (e, stackTrace) {
      print('Auto-sync error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _fetchClips() async {
    if (_token == null || _token!.isEmpty) return;
    
    try {
      final serverUrl = dotenv.env['SERVER_URL'] ?? 'http://localhost:3000';
      final response = await http.get(
        Uri.parse('$serverUrl/clips'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> clipsJson = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _clips.clear();
            _clips.addAll(clipsJson.map((json) => ClipModel.fromJson(json)).toList());
          });
        }
      }
    } catch (e) {
      print('Error fetching clips: $e');
    }
  }

  Future<void> _syncClip() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text to sync')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final serverUrl = dotenv.env['SERVER_URL'] ?? 'http://localhost:3000';
      final response = await http.post(
        Uri.parse('$serverUrl/clips'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'content': _textController.text.trim(),
          'type': 'text',
        }),
      );

      if (response.statusCode == 200) {
        _textController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clip synced successfully!')),
          );
        }
      } else {
        throw Exception('Failed to sync clip');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing clip: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  Future<void> _logout() async {
    try {
      _socketService.disconnect();
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentDataStreamSubscription?.cancel();
    _accessibilityClipboardSubscription?.cancel();
    _stopClipboardMonitoring();
    _stopPolling();
    _textController.dispose();
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('ClipSync'),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'Monitoring clipboard...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Accessibility banner (if disabled)
          if (_showAccessibilityBanner && Platform.isAndroid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[300],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Clipboard monitoring disabled - tap to enable',
                      style: TextStyle(
                        color: Colors.orange[300],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    color: Colors.orange[300],
                    onPressed: _showAccessibilityServiceBottomSheet,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          
          // Text input and sync button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type or paste text to sync...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _syncClip,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Sync'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Clips list
          Expanded(
            child: _clips.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.content_copy, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No clips yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sync your first clip above',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _clips.length,
                    itemBuilder: (context, index) {
                      final clip = _clips[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.text_fields),
                          title: Text(
                            clip.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatTimestamp(clip.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyToClipboard(clip.content),
                            tooltip: 'Copy to clipboard',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showClipboardHistory,
        tooltip: 'Clipboard History',
        child: const Icon(Icons.history),
      ),
    );
  }

  void _showClipboardHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  const Text(
                    'Clipboard History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_clips.length > 20 ? 20 : _clips.length} items',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Clips list
            Expanded(
              child: _clips.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.content_copy, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No clipboard history yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _clips.length > 20 ? 20 : _clips.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final clip = _clips[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.withOpacity(0.2),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            clip.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatTimestamp(clip.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              _copyToClipboard(clip.content);
                              Navigator.pop(context);
                            },
                            tooltip: 'Copy',
                          ),
                          onTap: () {
                            _copyToClipboard(clip.content);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
