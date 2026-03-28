import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard History'),
      ),
      body: ListView.builder(
        itemCount: 0, // TODO: Load clips from service
        itemBuilder: (context, index) {
          return ListTile(
            title: const Text('Clip item'),
            subtitle: const Text('Timestamp'),
          );
        },
      ),
    );
  }
}
