import 'package:flutter/material.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
      ),
      body: ListView.builder(
        itemCount: 0, // TODO: Load devices from service
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Device name'),
            subtitle: const Text('Platform'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Register new device
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
