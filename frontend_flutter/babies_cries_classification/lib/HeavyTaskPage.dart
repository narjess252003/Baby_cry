import 'dart:async';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<void> startIsolate() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(heavyTask, receivePort.sendPort);
}

void heavyTask(SendPort sendPort) {
  int result = 0;
  for (int i = 0; i < 1000000; i++) {
    result += i; // Simulate a heavy computation
  }
  sendPort.send(result);
}

class HeavyTaskPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Heavy Task with Isolate")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            startIsolate();
          },
          child: Text("Start Heavy Task"),
        ),
      ),
    );
  }
}
