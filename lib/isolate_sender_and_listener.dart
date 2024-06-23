// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:isolate';

import 'package:meta/meta.dart';
import 'package:thread_pool/thread_pool_data_types.dart';

class IsolateSenderAndListener {
  int isolateIndex;

  final SendPort _sendPortToIsolate;
  final Stream _streamFromIsolate;
  final ReceivePort _receiver;
  final Isolate _isolate;

  IsolateSenderAndListener._({
    required this.isolateIndex,
    required SendPort sendPortToIsolate,
    required Stream<dynamic> streamFromIsolate,
    required ReceivePort receiver,
    required Isolate isolate,
  })  : _isolate = isolate,
        _receiver = receiver,
        _streamFromIsolate = streamFromIsolate,
        _sendPortToIsolate = sendPortToIsolate;

  static Future<IsolateSenderAndListener> createIsolate(
      int isolateIndex) async {
    var receiver = ReceivePort();

    var isolate = Isolate.spawn((data) {
      worker(data);
    }, receiver.sendPort);

    var stream = receiver.asBroadcastStream();
    // The first thing the worker thread sends is the SendPort.
    var sendPort = await stream.first;
    if (sendPort is! SendPort) {
      throw Exception("Setup error. Expected Sendport");
    }
    return IsolateSenderAndListener._(
        sendPortToIsolate: sendPort,
        streamFromIsolate: stream,
        receiver: receiver,
        isolate: await isolate,
        isolateIndex: isolateIndex);
  }

  Future<ResponseData> getResponse(RequestData req) async {
    _sendPortToIsolate.send(req);
    ResponseData res = ResponseData.emptyRes();
    // Check that the right id was passed. The id makes sure the right response is being served.
    // This has to be done because the stream is a bit wacky and sometimes triggers the second call aswell.
    // The stream listend to is a broadcasted stream.
    while (res.id != req.id) {
      dynamic value = await _streamFromIsolate.first;
      if (value is! ResponseData) {
        throw Exception("Bad response data was returned.");
      }
      res = value;
    }

    return res;
  }

  /// Close the isolate.
  Future<void> close() async {
    RequestData req = RequestData(
        id: idGenerator(), callback: () {}, stateType: StateType.close);
    await getResponse(req);
    _receiver.close();
    _isolate.kill();
  }

  /// The main isolate worker.
  static void worker(SendPort sender) {
    ReceivePort receiver = ReceivePort();
    sender.send(receiver.sendPort);

    receiver.listen((data) {
      ResponseData res = workerHandleRequest(data);
      sender.send(res);
      if (res.stateType == StateType.close) {
        receiver.close();
        return;
      }
    });
  }

  static ResponseData workerHandleRequest(dynamic data) {
    if (data is RequestData) {
      if (data.stateType == StateType.close) {
        return ResponseData(id: data.id, data: -1, stateType: StateType.close);
      }
      return ResponseData(data: data.callback(), id: data.id);
    } else {
      print("Worker got wrong data type.");
      return ResponseData(id: -1, data: -1, stateType: StateType.error);
    }
  }

  int _idCounter = 0;

  int idGenerator() {
    return _idCounter++;
  }
}
