import 'dart:io';

import 'package:thread_pool/thread_pool.dart';

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

void main(List<String> arguments) async {
  ThreadPool tP = ThreadPool(numberThreads: 4);
  await tP.start();

  List<int> li = await Future.wait<int>([
    getItem(tP, 15),
    getItem(tP, 20),
    getItem(tP, 25),
    getItem(tP, 2500),
    getItem(tP, 250),
    getItem(tP, 251),
    getItem(tP, 2511),
    getItem(tP, 25111),
  ]);
  print(li);

  await tP.close();
}
