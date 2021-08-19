import 'package:registry/registry.dart';

// Please check `test/registry_test.dart` for more advanced example use-cases.

void main() {
  print('1. Init service locator');
  final sl = Registry()..debugLog = print;

  print('2. Register object');
  sl.put<IDummyClass>(
    (get, params) => DummyClassImpl1(params?.byName('param') ?? 'No param'),
    onDispose: (instance) => instance.dispose(),
  );

  final params = RegistrationParams.named({'param': 'Param123'});

  print('3. Resolve object');
  final object = sl.get<IDummyClass>(params: params) as DummyClassImpl1;

  print('4. Check the param of the resolved object: ${object.getParam()}');

  print('5. Remove object');
  sl.remove<IDummyClass>();

  print('6. Check if still registered');
  print(sl.isRegistered<IDummyClass>());
}

// Dummy classes

abstract class IDummyClass {
  void dispose();
}

class DummyClassImpl1 implements IDummyClass {
  final String _param;

  DummyClassImpl1(this._param) {
    print('Created a new instance of DummyClassImpl1.');
  }

  String getParam() => _param;

  @override
  void dispose() {
    print('Object disposed');
  }
}
