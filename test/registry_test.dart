import 'package:registry/registry.dart';
import 'package:test/test.dart';

abstract class IDummyClass {
  void dispose();
}

class DummyClassImpl1 implements IDummyClass {
  int _counter = 0;
  int get counter => _counter;
  bool _disposed = false;

  bool increment() {
    if (_disposed) return false;

    _counter++;
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
  }
}

class DummyClassImplSubClass1 extends DummyClassImpl1 {
  final SomeOtherClass someOtherClass;

  DummyClassImplSubClass1(this.someOtherClass);
}

class SomeOtherClass {
  final String firstParam;
  final int secondParam;

  SomeOtherClass(this.firstParam, this.secondParam);
}

class DummyChainClass1 {
  final int param;

  DummyChainClass1(this.param);
}

class DummyChainClass2 {
  final DummyChainClass1 dummyChainClass1;

  DummyChainClass2(this.dummyChainClass1);
}

class DummyChainClass3 {
  final DummyChainClass2 dummyChainClass2;

  DummyChainClass3(this.dummyChainClass2);
}

class DummyChainClass4 {
  final DummyChainClass3 dummyChainClass3;

  DummyChainClass4(this.dummyChainClass3);
}

void main() {
  group('Test group', () {
    final sl = Registry()..debugLog = print;

    tearDown(() {
      sl.clear();
    });

    test('put one, check if registered', () {
      sl.put<IDummyClass>((get, params) => DummyClassImpl1());

      expect(sl.isRegistered<IDummyClass>(), isTrue);
    });

    test(
        'put one, get one (lazySingleton - create object on first get() '
        'then always return the same instance)', () {
      sl.put<IDummyClass>((get, params) => DummyClassImpl1());

      final lazySingleInstance1 = sl.get<IDummyClass>() as DummyClassImpl1;

      expect(lazySingleInstance1, isA<DummyClassImpl1>());
      expect(lazySingleInstance1.counter, 0);

      lazySingleInstance1.increment();
      expect(lazySingleInstance1.counter, 1);

      final lazySingleInstance2 = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(lazySingleInstance2.counter, 1);
    });

    test(
        'put one, get one (eagerSingleton - create object instantly, when calling put(). '
        'Params are not available on this registration type)', () {
      sl.put<IDummyClass>(
        (get, params) {
          expect(params, equals(null));
          return DummyClassImpl1();
        },
        registrationMode: RegistrationMode.eagerSingleton,
      );

      final singleInstance1 = sl.get<IDummyClass>(
        params: RegistrationParams.list([1, 2, 3]),
      ) as DummyClassImpl1;

      expect(singleInstance1, isA<DummyClassImpl1>());
      expect(singleInstance1.counter, 0);

      singleInstance1.increment();
      expect(singleInstance1.counter, 1);

      final singleInstance2 = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(singleInstance2.counter, 1);
    });

    test(
        'put one, get one (lazyFactory - create new object on every get() call)',
        () {
      sl.put<IDummyClass>(
        (get, params) => DummyClassImpl1(),
        registrationMode: RegistrationMode.lazyFactory,
      );
      final instance1 = sl.get<IDummyClass>() as DummyClassImpl1;

      expect(instance1, isA<DummyClassImpl1>());
      expect(instance1.counter, 0);

      instance1.increment();
      expect(instance1.counter, 1);

      final instance2 = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(instance2.counter, 0);
    });

    test('put both interface and impl, check if it removes the correct one',
        () {
      sl.put<IDummyClass>((get, params) => DummyClassImpl1());
      sl.put<DummyClassImpl1>((get, params) => DummyClassImpl1());

      expect(sl.isRegistered<IDummyClass>(), isTrue);
      expect(sl.isRegistered<DummyClassImpl1>(), isTrue);

      sl.remove<DummyClassImpl1>();
      expect(sl.isRegistered<IDummyClass>(), isTrue);
    });

    test('put two and reregister once', () {
      sl
        ..put<IDummyClass>(
          (get, params) => DummyClassImpl1(),
          allowOneReregistration: true,
        )
        ..put<IDummyClass>(
          (get, params) => DummyClassImpl1(),
        );

      expect(sl.isRegistered<IDummyClass>(), isTrue);
    });

    test(
        'put two and try to reregister once '
        'without adding `allowOneReregistration` to the first one', () {
      sl.put<IDummyClass>(
        (get, params) => DummyClassImpl1(),
      );

      expect(
        () => sl.put<IDummyClass>((get, params) => DummyClassImpl1()),
        throwsA(
          isA<RegistrantTypeAlreadyRegisteredException>().having(
            (exception) => exception.message,
            'message',
            'An object of type IDummyClass has already been put in the registry.',
          ),
        ),
      );
    });

    test('put one and remove', () {
      sl.put<IDummyClass>(
        (get, params) => DummyClassImpl1(),
      );

      expect(sl.isRegistered<IDummyClass>(), isTrue);

      sl.remove<IDummyClass>();

      expect(sl.isRegistered<IDummyClass>(), isFalse);
    });

    test('put one and refresh', () {
      sl.put<IDummyClass>(
        (get, params) => DummyClassImpl1(),
        onDispose: (instance) => instance.dispose(),
      );

      expect(sl.isRegistered<IDummyClass>(), isTrue);

      final object = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(object.counter, equals(0));

      object.increment();
      expect(object.counter, equals(1));

      sl.refreshInstance<IDummyClass>();

      final objectRefreshed = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(objectRefreshed.counter, equals(0));
    });

    test('put one, refresh and remove (check if dispose is called)', () {
      sl.put<IDummyClass>(
        (get, params) => DummyClassImpl1(),
        onDispose: (instance) => instance.dispose(),
      );

      expect(sl.isRegistered<IDummyClass>(), isTrue);

      final object = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(object.counter, equals(0));

      object.increment();
      expect(object.counter, equals(1));

      sl.refreshInstance<IDummyClass>();

      final refreshedObject = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(refreshedObject.counter, equals(0));

      refreshedObject.increment();
      expect(refreshedObject.counter, equals(1));

      sl.remove<IDummyClass>();
      expect(refreshedObject.increment(), isFalse);
    });

    test('put one and dispose on removal/clear', () {
      sl.put<IDummyClass>(
        (get, params) => DummyClassImpl1(),
        onDispose: (instance) => instance.dispose(),
      );
      expect(sl.isRegistered<IDummyClass>(), isTrue);

      final object = sl.get<IDummyClass>() as DummyClassImpl1;
      expect(object.counter, equals(0));

      object.increment();
      expect(object.counter, equals(1));

      sl.remove<IDummyClass>();
      // Or
      //sl.clear();

      expect(object.increment(), isFalse);
    });

    test('put two and clear all', () {
      sl
        ..put<SomeOtherClass>((get, params) => SomeOtherClass('test', 10))
        ..put<IDummyClass>((get, params) => DummyClassImpl1());

      final object1 = sl.get<SomeOtherClass>();
      final object2 = sl.get<IDummyClass>() as DummyClassImpl1;

      expect(object1, isA<SomeOtherClass>());
      expect(object1.firstParam, equals('test'));
      expect(object1.secondParam, equals(10));

      expect(object2, isA<DummyClassImpl1>());

      sl.clear();

      expect(sl.isRegistered<SomeOtherClass>(), isFalse);
      expect(sl.isRegistered<IDummyClass>(), isFalse);
    });

    test('put two, get two with hardcoded params', () {
      sl
        ..put<SomeOtherClass>((get, params) => SomeOtherClass('test', 10))
        ..put<IDummyClass>((get, params) => DummyClassImpl1());

      final object1 = sl.get<SomeOtherClass>();
      final object2 = sl.get<IDummyClass>() as DummyClassImpl1;

      expect(object1, isA<SomeOtherClass>());
      expect(object1.firstParam, equals('test'));
      expect(object1.secondParam, equals(10));

      expect(object2, isA<DummyClassImpl1>());
    });

    test('put two, get two with injected dependency and dynamic params', () {
      sl
        ..put<IDummyClass>(
          (get, params) => DummyClassImplSubClass1(
            get(params: params),
          ),
        )
        ..put<SomeOtherClass>(
          (get, params) => SomeOtherClass(
            params?.byIndex(0) ?? 'fallback',
            params?.byName('param2') ?? 10,
          ),
        );

      final params = RegistrationParams.named(
        {
          'param1': 'test',
          'param2': 10,
        },
      );
      final object2 =
          sl.get<IDummyClass>(params: params) as DummyClassImplSubClass1;
      expect(object2, isA<DummyClassImplSubClass1>());

      final someOtherClass = object2.someOtherClass;
      expect(someOtherClass, isA<SomeOtherClass>());
      expect(someOtherClass.firstParam, equals('test'));
      expect(someOtherClass.secondParam, equals(10));
    });

    test(
        'put four in chain in random order and '
        'check if their dependencies and params are injected '
        'up to the most top-level class (DummyChainClass1)', () {
      sl
        ..put<DummyChainClass3>(
          (get, params) => DummyChainClass3(get(params: params)),
        )
        ..put<DummyChainClass1>(
          (get, params) => DummyChainClass1(params?.byName('paramValue') ?? 0),
        )
        ..put<DummyChainClass4>(
          (get, params) => DummyChainClass4(get(params: params)),
        )
        ..put<DummyChainClass2>(
          (get, params) => DummyChainClass2(get(params: params)),
        );

      expect(sl.isRegistered<DummyChainClass1>(), isTrue);
      expect(sl.isRegistered<DummyChainClass2>(), isTrue);
      expect(sl.isRegistered<DummyChainClass3>(), isTrue);
      expect(sl.isRegistered<DummyChainClass4>(), isTrue);

      final params = RegistrationParams.named({'paramValue': 42});
      final dummyClass4 = sl.get<DummyChainClass4>(params: params);

      expect(
        dummyClass4.dummyChainClass3.dummyChainClass2.dummyChainClass1.param,
        equals(42),
      );
    });
  });
}
