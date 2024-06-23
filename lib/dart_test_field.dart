// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_test_field/isolate_sender_and_listener.dart';
import 'package:dart_test_field/thread_pool_data_types.dart';

Future<int> getItem(ThreadPool tP, int test) async {
  dynamic res = await tP.executeFunctionInIsolate(() {
    return heavyComputation(test);
  });
  if (res is! int) {
    throw Exception("Callback returned unexpected type");
  }
  return res;
}

int heavyComputation(int test) {
  //print("hi from heavy thread");
  sleep(Duration(seconds: 3));
  //print("finished work");
  return test;
}

/// This allows you to create a threadpool to call callbacks on isolated threads.
/// Pass a callback to executeFunctionInIsolate() and the returned value of the callback
/// is the returned value from executeFunctionInIsolate(). To start the thread pool you have to call start().
class ThreadPool {
  int numberThreads;
  final List<IsolateSenderAndListener> _isolateConnections = [];
  List<int> _availablePorts = [];
  // These two variables are being used to notify all listeners
  // when new ports are available.
  final StreamController<bool> _portController = StreamController();
  late Stream<bool> _portTrigger;

  ThreadPool({required this.numberThreads}) {
    _portTrigger = _portController.stream.asBroadcastStream();
  }

  /// Start the isolates. This method has to be called to process
  /// the callbacks.
  Future<void> start() async {
    _availablePorts = List.generate(numberThreads, (i) => i);

    for (int index in _availablePorts) {
      final conn = await IsolateSenderAndListener.createIsolate(index);
      _isolateConnections.add(conn);
    }
  }

  /// Close all Isolates.
  Future<void> close() async {
    _portController.close();

    // Get every isolate and close it.
    for (int _ in Iterable.generate(numberThreads)) {
      IsolateSenderAndListener conn = await _getIsolateConnection();
      await conn.close();
    }
  }

  /// Pass a function to be excuted in isolate.
  Future<dynamic> executeFunctionInIsolate(
      dynamic Function() functionToCall) async {
    IsolateSenderAndListener conn = await _getIsolateConnection();
    RequestData req =
        RequestData(id: conn.idGenerator(), callback: functionToCall);
    ResponseData res = await conn.getResponse(req);
    _returnIsolateConnection(conn);
    return res.data;
  }

  Future<IsolateSenderAndListener> _getIsolateConnection() async {
    int index = await _getAvailablePort();
    return _isolateConnections[index];
  }

  // This returns the Connection and notifys all listeners that a port is free again.
  void _returnIsolateConnection(IsolateSenderAndListener conn) {
    _availablePorts.add(conn.isolateIndex);
    // Notify everyone that is waiting that a new thread is available
    _portController.add(true);
  }

  /// Get available port and remove it from the available port list. If none are available wait
  /// till one is available.
  Future<int> _getAvailablePort() async {
    if (_availablePorts.isNotEmpty) {
      return _availablePorts.removeLast();
    }

    // Wait for a new port to be available and rerun the function.
    await _portTrigger.first;
    return await _getAvailablePort();
  }
}
