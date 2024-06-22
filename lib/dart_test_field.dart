// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';

int calculate() {
  return 6 * 7;
}

Future<int> getItem(ThreadPool tP, int test) async {
  return tP.executeFunctionInIsolate(() {
    return heavyComputation(test);
  }).then((res) {
    return res as int;
  });
}

int heavyComputation(int test) {
  //print("hi from heavy thread");
  sleep(Duration(seconds: 5));
  //print("finished work");
  return test;
}

void worker(SendPort sender) {
  //print("hi from init worker");
  ReceivePort receiver = ReceivePort();
  sender.send(receiver.sendPort);

  receiver.listen((data) {
    if (data is RequestData) {
      //print("hi from new data worker");
      ResponseData res = ResponseData(data: data.callback(), id: data.id);
      sender.send(res);
    } else {
      print("Worker got wrong data type.");
      throw Exception("Bad data passed to worker thread");
    }
  });
}

class RequestData {
  int id;
  dynamic Function() callback;
  RequestData({
    required this.id,
    required this.callback,
  });
}

class ResponseData {
  int id;
  dynamic data;
  ResponseData({
    required this.id,
    required this.data,
  });

  factory ResponseData.emptyRes() {
    return ResponseData(id: -1, data: null);
  }
}

class ThreadPool {
  int numberThreads;
  List<SendPort> allSenders = [];
  List<Stream> allListeners = [];
  List<int> availablePorts = [];
  final StreamController<bool> _portController = StreamController();
  late Stream<bool> portTrigger;

  ThreadPool({required this.numberThreads}) {
    portTrigger = _portController.stream.asBroadcastStream();
  }
  Future<void> start() async {
    availablePorts = List.generate(numberThreads, (i) => i);
    List<ReceivePort> allReceivers = [];
    for (int _ in availablePorts) {
      var mainReceiver = ReceivePort();

      allReceivers.add(mainReceiver);
      Isolate.spawn((data) {
        worker(data);
      }, mainReceiver.sendPort);

      var stream = mainReceiver.asBroadcastStream();
      var sendPort = await stream.first;
      if (sendPort is SendPort) {
        allSenders.add(sendPort);
        //print("sendport added");
      } else {
        throw Exception("Setup error. Expected Sendport");
      }
      allListeners.add(stream);
    }
  }

  SendPort getSender(int index) {
    if (index >= allSenders.length) {
      throw Exception("Sender is out of range.");
    }
    return allSenders[index];
  }

  Stream getListener(int index) {
    if (index >= allSenders.length) {
      throw Exception("Listener is out of range.");
    }
    return allListeners[index];
  }

  /// Get available port and remove it from the available port list. If none are available wait
  /// till one is available.
  Future<int> getAvailablePort() async {
    if (availablePorts.isNotEmpty) {
      return availablePorts.removeLast();
    }

    // Wait for a new port to be available and rerun the function.
    await portTrigger.first;
    return await getAvailablePort();
  }

  void addBackAvailablePort(int port) {
    availablePorts.add(port);
    // Notify everyone that is waiting that a new thread is available
    _portController.add(true);
  }

  void close() {
    _portController.close();
  }

  int counter = 0;

  Future<dynamic> executeFunctionInIsolate(
      dynamic Function() functionToCall) async {
    int portToUse = await getAvailablePort();
    RequestData req = RequestData(id: counter++, callback: functionToCall);

    // Send the request to the isolated thread.
    getSender(portToUse).send(req);
    ResponseData res = ResponseData.emptyRes();
    // Check that the right id was passed. The id makes sure the right response is being served.
    // This has to be done because the stream is a bit wacky and sometimes triggers the second call aswell.
    // The stream listend to is a broadcasted stream.
    while (res.id != req.id) {
      var value = await getListener(portToUse).first;
      if (value is! ResponseData) {
        throw Exception("Bad response data passed.");
      }
      res = value;
    }

    addBackAvailablePort(portToUse);
    return res.data;
  }
}
