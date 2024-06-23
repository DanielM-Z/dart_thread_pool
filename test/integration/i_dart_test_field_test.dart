import 'dart:io';

import 'package:dart_test_field/dart_test_field.dart';
import 'package:test/test.dart';

Future<int> getSimulationTest(
    ThreadPool tP, int test, int simulationTimeMs) async {
  dynamic res = await tP.executeFunctionInIsolate(() {
    return heavySimulation(test, simulationTimeMs);
  });
  if (res is! int) {
    throw Exception("Callback returned unexpected type");
  }
  return res;
}

int heavySimulation(int test, int simulationTimeMs) {
  //print("hi from heavy thread");
  sleep(Duration(milliseconds: simulationTimeMs));
  //print("finished work");
  return test;
}

void main() {
  group("ThreadPool", () {
    test(
        'ThreadPool.executeFunctionInIsolate() called multiple times: Callbacks are called in parallel',
        () async {
      // Setup
      int numberThreads = 4;
      int timeEachCallback = 300;
      int numberCallbacksCalled = 12;
      ThreadPool tP = ThreadPool(numberThreads: numberThreads);
      await tP.start();

      // Test
      Stopwatch stopwatch = Stopwatch()..start();
      // wait for all callbacks.
      List<int> _ = await Future.wait<int>(List.generate(numberCallbacksCalled,
          (i) => getSimulationTest(tP, 10, timeEachCallback)));
      await tP.close();
      // Assert
      var expectedMaximumTime = Duration(
          milliseconds:
              timeEachCallback * 3 + 100); // Add 100 for other processes.
      expect(stopwatch.elapsed < expectedMaximumTime, true);
    });

    test(
        'ThreadPool.executeFunctionInIsolate() called: Returns value from callback',
        () async {
      // Setup
      int numberThreads = 4;
      ThreadPool tP = ThreadPool(numberThreads: numberThreads);
      await tP.start();

      // Test
      var res = await tP.executeFunctionInIsolate(() {
        return heavySimulation(52, 10);
      });
      await tP.close();
      // Assert
      expect(res, 52);
    });
  }, timeout: Timeout(Duration(seconds: 20)));
}
