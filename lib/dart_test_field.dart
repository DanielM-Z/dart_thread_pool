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
  print("hi from heavy thread");
  var total = 0.0;
  for (var i = 0; i < 10000; i++) {
    total += i;
  }
  print("finished work");
  return -1 + test;
}

void worker(SendPort sender) {
  print("hi from init worker");
  ReceivePort receiver = ReceivePort();
  sender.send(receiver.sendPort);

  receiver.listen((data) {
    var callback = data as dynamic Function();
    print("hi from new data worker");
    sender.send(callback());
  });
}

class ThreadPool {
  int numberThreads;
  List<SendPort> allSenders = [];
  // List<ReceivePort> allReceivers = [];
  List<Stream> allListeners = [];
  List<int> availablePorts = [];

  ThreadPool({required this.numberThreads});
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
        print("sendport added");
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

  /// Get available port and remove it from the available port list.
  int getAvailablePort() {
    if (allSenders.isEmpty) {
      throw Exception("Sender was not setup. No sender available.");
    }
    if (availablePorts.isNotEmpty) {
      return availablePorts.removeLast();
    } else {
      throw Exception("All ports are used. Maybe you should use more threads");
    }
  }

  void addBackAvailablePort(int port) {
    availablePorts.add(port);
  }

  Future<dynamic> executeFunctionInIsolate(
      dynamic Function() functionToCall) async {
    int portToUse = getAvailablePort();
    getSender(portToUse).send(functionToCall);
    var res = await getListener(portToUse).first;
    addBackAvailablePort(portToUse);
    return res;
  }
}
