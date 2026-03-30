import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SocketService {
  IO.Socket? _socket;
  final String serverUrl;
  String? _currentToken;
  Timer? _heartbeatTimer;

  SocketService({required this.serverUrl});

  // Initialize socket connection
  void connect(String token) {
    // Prevent duplicate connections
    if (_socket != null && _socket!.connected) {
      print('Socket already connected, skipping duplicate connection');
      return;
    }
    
    _currentToken = token;
    
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(1000)
          .disableAutoConnect()
          .build(),
    );

    _socket?.connect();

    _socket?.on('connect', (_) async {
      print('Socket connected: ${_socket?.id}');
      // Join room with fresh Firebase token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final freshToken = prefs.getString('auth_token') ?? token;
      print('Joining room with fresh token from SharedPreferences');
      _socket?.emit('join-room', freshToken);
    });

    _socket?.on('room-joined', (data) {
      print('Joined room for user: ${data['userId']}');
      _startHeartbeat();
    });

    _socket?.on('token-expired', (data) async {
      print('Token expired, refreshing...');
      // refresh token and reconnect
      _reconnect();
    });

    _socket?.on('error', (error) async {
      print('Socket error: ${error['message']}');
      
      // Handle unauthorized error by refreshing token
      if (error['message'] == 'Unauthorized') {
        print('Token expired, attempting to refresh...');
        final newToken = await _refreshToken();
        if (newToken != null) {
          print('Token refreshed successfully, reconnecting...');
          disconnect();
          connect(newToken);
        } else {
          print('Failed to refresh token');
        }
      }
    });

    _socket?.on('disconnect', (_) {
      print('Socket disconnected');
    });
  }
  
  // Refresh Firebase token
  Future<String?> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) {
        print('No refresh token found in SharedPreferences');
        return null;
      }
      
      final response = await http.post(
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=AIzaSyBbKI6LDUimJvKiBOFd2HFqs-sc7YQI_1w'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newIdToken = data['id_token'];
        final newRefreshToken = data['refresh_token'];
        
        // Save new tokens to SharedPreferences
        await prefs.setString('auth_token', newIdToken);
        await prefs.setString('refresh_token', newRefreshToken);
        
        return newIdToken;
      } else {
        print('Token refresh failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }

  // Listen for new clips
  void onNewClip(Function(dynamic) callback) {
    _socket?.on('new-clip', callback);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('ping', {});
      } else {
        print('Socket disconnected, reconnecting...');
        _reconnect();
      }
    });
  }

  void _reconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) return;
    
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    
    connect(token);
  }

  // Disconnect socket
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
  }

  // Check if connected
  bool get isConnected => _socket?.connected ?? false;
}
