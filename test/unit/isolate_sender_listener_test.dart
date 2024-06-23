import 'dart:isolate';

import 'package:dart_test_field/isolate_sender_and_listener.dart';

import 'package:dart_test_field/thread_pool_data_types.dart';
import 'package:test/test.dart';

void main() {
  group("IsolateSenderAndListener.worker()", () {
    test(
        'IsolateSenderAndListener.workerHandleRequest() called with bad data: Response data with error state returned',
        () {
      var res = IsolateSenderAndListener.workerHandleRequest(15);
      expect(res.stateType, StateType.error);
    });

    test(
        'IsolateSenderAndListener.workerHandleRequest() called with good data: Response data with same id returned',
        () {
      RequestData req = RequestData(
          id: 10,
          callback: () {
            return 11;
          });
      var res = IsolateSenderAndListener.workerHandleRequest(req);
      expect(res.id, req.id);
      expect(res.data, 11);
      expect(res.stateType, StateType.success);
    });

    test(
        'IsolateSenderAndListener.workerHandleRequest() called with close request: Response data has stateType == Close',
        () {
      RequestData req =
          RequestData(id: 10, callback: () {}, stateType: StateType.close);
      var res = IsolateSenderAndListener.workerHandleRequest(req);
      expect(res.id, req.id);
      expect(res.stateType, StateType.close);
    });

    test('IsolateSenderAndListener.worker() called : Sends SendPort', () async {
      // Setup
      ReceivePort receiver = ReceivePort();
      // Test
      var i = Isolate.spawn(IsolateSenderAndListener.worker, receiver.sendPort);
      var res = await receiver.first;
      (await i).kill();
      // Assert
      expect(res is SendPort, true);
    });
    test(
        'IsolateSenderAndListener.worker() called with close request : worker returns',
        () async {
      // Setup
      RequestData req =
          RequestData(id: 10, callback: () {}, stateType: StateType.close);

      ReceivePort receiver = ReceivePort();
      var isolate =
          Isolate.spawn(IsolateSenderAndListener.worker, receiver.sendPort);

      ReceivePort exitListener = ReceivePort();
      (await isolate).addOnExitListener(exitListener.sendPort);

      var res = await receiver.first as SendPort;
      // Test
      res.send(req);
      // Assert
      await exitListener
          .first; // This await only stops blocking if the worker returned.
    });
  }, timeout: Timeout(Duration(seconds: 5)));
  test(
      'IsolateSenderAndListener.startIsolate() called : Returns item with correct index',
      () async {
    // Setup Test
    var res = await IsolateSenderAndListener.createIsolate(10);
    // Assert
    expect(res.isolateIndex, 10);
  });
}
