import 'dart:isolate';

import 'package:dart_test_field/isolate_sender_and_listener.dart';

import 'package:dart_test_field/thread_pool_data_types.dart';
import 'package:test/test.dart';

void main() {
  group("IsolateSenderAndListener", () {
    test(
        'IsolateSenderAndListener.getResponse() called : Returns data from callback.',
        () async {
      // Setup
      var conn = await IsolateSenderAndListener.createIsolate(1);
      RequestData req = RequestData(
          id: conn.idGenerator(),
          callback: () {
            return 10;
          });
      // Test
      var res = await conn.getResponse(req);
      // Assert
      expect(res.data, 10);
      expect(res.id, req.id);
    });

    // If close was called getResponse shouldnt work anymore.
    test(
        'IsolateSenderAndListener.close() called : getResponse() should throw StateError.',
        () async {
      // Setup Test
      var conn = await IsolateSenderAndListener.createIsolate(1);
      await conn.close();
      Object? errorThrown;
      try {
        await conn.getResponse(RequestData(id: 1, callback: () {}));
      } catch (e) {
        errorThrown = e;
      }
      // Assert
      expect(errorThrown is StateError, true);
    });
  }, timeout: Timeout(Duration(seconds: 5)));
}
