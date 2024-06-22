import 'package:dart_test_field/dart_test_field.dart' as dart_test_field;
import 'package:dart_test_field/dart_test_field.dart';

void main(List<String> arguments) async {
  ThreadPool tP = ThreadPool(numberThreads: 4);
  await tP.start();

  Stopwatch stopwatch = Stopwatch()..start();
  List<int> li = await Future.wait<int>([
    dart_test_field.getItem(tP, 15),
    dart_test_field.getItem(tP, 20),
    dart_test_field.getItem(tP, 25),
    dart_test_field.getItem(tP, 2500),
    dart_test_field.getItem(tP, 250),
    dart_test_field.getItem(tP, 251),
    dart_test_field.getItem(tP, 2511),
    dart_test_field.getItem(tP, 25111),
  ]);
  print(li);
  List<int> li2 = await Future.wait<int>([
    dart_test_field.getItem(tP, 100),
    dart_test_field.getItem(tP, 200),
    dart_test_field.getItem(tP, 300),
  ]);
  print(li2);
  print('doSomething() executed in ${stopwatch.elapsed}');
  await tP.close();
}
