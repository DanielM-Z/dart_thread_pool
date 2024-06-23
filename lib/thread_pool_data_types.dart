import 'dart:isolate';

enum StateType { success, error, close, sending }

class RequestData {
  int id;
  dynamic Function() callback;
  StateType stateType;
  RequestData({
    required this.id,
    required this.callback,
    this.stateType = StateType.sending,
  });
}

class ResponseData {
  int id;
  dynamic data;
  StateType stateType;
  String errorMessage;
  ResponseData(
      {required this.id,
      required this.data,
      this.stateType = StateType.success,
      this.errorMessage = ""});

  factory ResponseData.emptyRes() {
    return ResponseData(id: -1, data: null);
  }
}
