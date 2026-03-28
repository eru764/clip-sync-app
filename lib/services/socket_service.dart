import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  final String serverUrl;

  SocketService({required this.serverUrl});

  // Initialize socket connection
  void connect(String token) {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket?.connect();

    _socket?.on('connect', (_) {
      print('Socket connected: ${_socket?.id}');
      // Join room with Firebase token
      _socket?.emit('join-room', token);
    });

    _socket?.on('room-joined', (data) {
      print('Joined room for user: ${data['userId']}');
    });

    _socket?.on('error', (error) {
      print('Socket error: ${error['message']}');
    });

    _socket?.on('disconnect', (_) {
      print('Socket disconnected');
    });
  }

  // Listen for new clips
  void onNewClip(Function(dynamic) callback) {
    _socket?.on('new-clip', callback);
  }

  // Disconnect socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
  }

  // Check if connected
  bool get isConnected => _socket?.connected ?? false;
}
