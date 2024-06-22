import 'package:dart_test_field/dart_test_field.dart' as dart_test_field;
import 'package:dart_test_field/dart_test_field.dart';

void main(List<String> arguments) async {
  print('Hello world: ${dart_test_field.calculate()}!');

  ThreadPool tP = ThreadPool(numberThreads: 4);
  await tP.start();

  List<int> li = await Future.wait<int>([
    dart_test_field.getItem(tP, 15),
    dart_test_field.getItem(tP, 2),
    dart_test_field.getItem(tP, 3),
    dart_test_field.getItem(tP, 1),
  ]);
  print(li);
  List<int> li2 = await Future.wait<int>([
    dart_test_field.getItem(tP, 1),
    dart_test_field.getItem(tP, 2),
    dart_test_field.getItem(tP, 3),
  ]);
  print(li2);
}
