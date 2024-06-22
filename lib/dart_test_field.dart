// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_test_field/thread_pool_data_types.dart';

Future<int> getItem(ThreadPool tP, int test) async {
  return tP.executeFunctionInIsolate(() {
    return heavyComputation(test);
  }).then((res) {
    return res as int;
  });
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
  late Stream<bool> portTrigger;

  // These two variables are only used so that the isolates can be closed afterwards.
  final List<ReceivePort> _allReceivers = [];
  final List<Isolate> _allIsolates = [];

  ThreadPool({required this.numberThreads}) {
    portTrigger = _portController.stream.asBroadcastStream();
  }

  /// Start the isolates. This method has to be called to process
  /// the callbacks.
  Future<void> start() async {
    _availablePorts = List.generate(numberThreads, (i) => i);

    for (int index in _availablePorts) {
      var mainReceiver = ReceivePort();

      var isolate = Isolate.spawn((data) {
        worker(data);
      }, mainReceiver.sendPort);

      var stream = mainReceiver.asBroadcastStream();
      var sendPort = await stream.first;
      if (sendPort is! SendPort) {
        throw Exception("Setup error. Expected Sendport");
      }

      final conn = IsolateSenderAndListener(
          sendPortToIsolate: sendPort,
          streamFromIsolate: stream,
          isolateIndex: index);
      _isolateConnections.add(conn);

      // This is only to close them later on.
      _allReceivers.add(mainReceiver);
      _allIsolates.add(await isolate);
    }
  }

  // Close all
  Future<void> close() async {
    _portController.close();

    // Get every isolate and close it.
    for (int _ in Iterable.generate(numberThreads)) {
      IsolateSenderAndListener conn = await _getIsolateConnecion();
      RequestData req = RequestData(
          id: _idGenerator(), callback: () {}, stateType: StateType.close);
      await _getResponse(conn, req);
      _allReceivers[conn.isolateIndex].close();
      _allIsolates[conn.isolateIndex].kill();
    }
  }

  Future<dynamic> executeFunctionInIsolate(
      dynamic Function() functionToCall) async {
    IsolateSenderAndListener conn = await _getIsolateConnecion();
    RequestData req = RequestData(id: _idGenerator(), callback: functionToCall);
    ResponseData res = await _getResponse(conn, req);
    _returnIsolateConnection(conn);
    return res.data;
  }

  static void worker(SendPort sender) {
    ReceivePort receiver = ReceivePort();
    sender.send(receiver.sendPort);

    receiver.listen((data) {
      if (data is RequestData) {
        if (data.stateType == StateType.close) {
          sender.send(
              ResponseData(id: data.id, data: -1, stateType: StateType.close));
          receiver.close();
          return;
        }
        //print("hi from new data worker");
        ResponseData res = ResponseData(data: data.callback(), id: data.id);
        sender.send(res);
      } else {
        print("Worker got wrong data type.");
        throw Exception("Bad data passed to worker thread");
      }
    });
  }

  Future<IsolateSenderAndListener> _getIsolateConnecion() async {
    int index = await _getAvailablePort();
    if (index >= _isolateConnections.length) {
      throw Exception("isolateConnections is out of range.");
    }
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
    await portTrigger.first;
    return await _getAvailablePort();
  }

  Future<ResponseData> _getResponse(
      IsolateSenderAndListener conn, RequestData req) async {
    conn.sendPortToIsolate.send(req);
    ResponseData res = ResponseData.emptyRes();
    // Check that the right id was passed. The id makes sure the right response is being served.
    // This has to be done because the stream is a bit wacky and sometimes triggers the second call aswell.
    // The stream listend to is a broadcasted stream.
    while (res.id != req.id) {
      dynamic value = await conn.streamFromIsolate.first;
      if (value is! ResponseData) {
        throw Exception("Bad response data was returned.");
      }
      res = value;
    }

    return res;
  }

  int _idCounter = 0;
  int _idGenerator() {
    return _idCounter++;
  }
}
