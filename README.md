<p align="center">
<img src="https://raw.githubusercontent.com/adrianflutur/registry/main/doc/images/logo.png" height="400" alt="registry" />
</p>

[![pub package](https://shields.io/pub/v/registry.svg?style=flat-square&color=blue)](https://pub.dev/packages/registry)

### Fast service locator for Dart and Flutter with support for deep injection params.

### No dependencies, no code generation.

---

## _**Getting started**_

- [FAQ](#faq)
- [Example](#example)
- [Registration and resolving](#registration-and-resolving)
- [Injection params](#injection-params)
- [Other features](#other-features)
- [License](#license)

## _**FAQ**_

> Q : What is the difference between using a service locator to register your objects, and turning all your objects into singletons?
>
> > A : When you turn all your objects into singletons you lose testability.

<br>

> Q : What exactly should I register in the service locator?
>
> > A : In a clean architecture, only low-level classes (such as a Service or Repository which interacts with a persistence layer) should be registered. This will let you easily achieve both dependency injection into higher-level classes (such as a Controller/ViewModel) and seamless testability.

<br>

> Q : Can I use this instead of some other state management solution?
>
> > A : Service locators are **not** state management solutions. Do not call methods on the `Registry()` object straight from your widgets. Use (constructor) dependency injection to resolve your state management Controllers/ViewModels/BLoCs etc. with the registered objects from the service locator.

<br>

> Q : Why make another service locator, when there's stuff like get_it and kiwi already available out there?
>
> > A : I've had some new features in mind such as theese deep injection params, allowing one re-registration per object type and using a single method for all types of registration modes, and also to practice Dart.

<br>

## _**Example**_

From [registry_example.dart](https://github.com/adrianflutur/registry/tree/main/example/registry_example.dart):

```dart
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
```

### _*Also check out [test/registry_test.dart](https://github.com/adrianflutur/registry/tree/main/test/registry_test.dart) for more advanced use-cases.*_

<br>

## _**Registration and resolving**_

### The `Registry` is a singleton which handles all registered objects.

<br>

### Available methods:

```dart
// Register an object
Registry().put<T>(
  (get, params) => YourObject(),
  registrationMode: RegistrationMode.lazySingleton,
  allowOneReregistration: false,
  onDispose: (instance) => instance.dispose(),
);

// Get an object with optional "params"
Registry().get<T>({RegistrationParams? params});

// Check if an object is registered
Registry().isRegistered<T>();

// Refresh an existing object instance
Registry().refreshInstance<T>();

// Remove an existing object
Registry().remove<T>();

// Clear the registry, removing all objects
Registry().clear();
```

<br>

### There are **3** available modes to register an object:

- _**Lazy singleton**_ -> Single instance. It is instantiated on first `.get()` call.
- _**Eager singleton**_ -> Single instance. It is instantiated right when we `.put()` it.
- _**Lazy factory**_ -> Lazy multiple instances. We get a new instance on every `.get()` call.

<br>

### When you `put()` objects, you can also make sure their dependencies are automatically resolved multiple layers down:

```dart
final sl = Registry()
  ..put<ThirdObject>((get, params) => ThirdObject());
  ..put<SecondObject>((get, params) => SecondObject(get()));
  ..put<FirstObject>((get, params) => FirstObject(get()));

void main() {
  // Automatically resolves SecondObject and ThirdObject
  final firstObject = sl.get<FirstObject>();
}

class FirstObject {
  final SecondObject secondObject;
  FirstObject(this.secondObject);
}

class SecondObject {
  final ThirdObject thirdObject;
  SecondObject(this.thirdObject);
}

class ThirdObject {}
```

<br>

## _**Injection params**_

### Injection params are _*optional*_.

<br>

### Params can be created in two ways:

- #### By using the `.named()` constructor, in which case you can give a name to each param and access them with `byName()`:

```dart
final paramsNamed = RegistrationParams.named(
  {
    'first_param': 10,
    'second_param': 'Test123',
  },
);

final firstParam = paramsNamed.byName('first_param') as int;
```

- #### or by using the `.list()` constructor, in which case you need to access them with `byIndex()`:

```dart
final paramsList = RegistrationParams.list(
  [10, 'Test123'],
);

final firstParam = paramsNamed.byIndex(0) as int;
```

---

<br>

### Now you can register an object and make use of the params field:

```dart
Registry().put<SomeObject>(
  (get, params) => SomeObject(params.byName('first_param')),
);
```

### and when you want to get that object from the Registry, add `params` to `.get() and they will be passed to your object:

```dart
final object = Registry().get<SomeObject>(params: params);
```

---

<br>

### Params **can also be passsed from an object to another at injection time**:

```dart
final sl = Registry()
  // First object uses `get` to inject the second object inside itself
  // and to pass the params it gets from us
..put<FirstObject>((get, params) => FirstObject(get(params: params)))
  // Second object receives the params from the first object and injects it into itself
  //
  // We don't need to cast params here (such as 'param as int'). The type is inferred.
  //
  // Also, the `params` field we get in the callback is always NULLABLE.
  // There's a chance we didn't get any params, that's why we use `params?.byName() ?? -1`.
  //
  // If you're sure you'll get some params in your callback, you can just use `params!.byName`
  // without adding `?? -1.
..put<SecondObject>((get, params) => SecondObject(params?.byName('param') ?? -1));


void main() {
  final params = RegistrationParams.named(
    {'param': 256},
  );

  final firstObject = sl.get<FirstObject>(params: params);

  // Now the Registry has injected the params into SecondObject, and then the SecondObject
  // into FirstObject.
}

class FirstObject {
  final SecondObject secondObject;
  FirstObject(this.secondObject);
}

class SecondObject {
  final int param;
  class SecondObject(this.param);
}
```

<br>

## _**Other features**_

- ### **onDispose** optional callback on the `.put()` method.

  > If non-null, onDispose will be called before the object is removed/refreshed/replaced.
  >
  > We receive the current instance in the callback so we can dispose resources, `StreamSubscription`s for example.

  ```dart
  final sl = Registry()
  ..put<SomeObject>(
    (get, params) => SomeObject(),
    onDispose: (instance) => instance.dispose(),
  );
  ```

- ### **allowOneReregistration** field on the `.put()` method

  > If you try to re-register the same object TYPE twice you will get an exception.
  >
  > Setting `allowOneReregistration: true` will allow you to register the same object type one more time. The new object will replace the old one entirely.
  >
  > ### **This is disabled by default and in most cases it should not be needed.**
  >
  > **NOTE**: This behaviour is a one-time thing. This means that if you set this to `true` for the first registration, then you re-register the same object you must set it to `true` again if you want to re-register again (third time).

  ```dart
  // Error, allowOneReregistration is false (by default)
  final sl = Registry()
  ..put<SomeObject>(
    (get, params) => SomeObject(),
  )..put<SomeObject>(
    (get, params) => SomeObject(),
  );

  // No error, allowOneReregistration is true so the second registered object has replaced the first one
  final sl = Registry()
  ..put<SomeObject>(
    (get, params) => SomeObject(),
    allowOneReregistration: true,
  )..put<SomeObject>(
    (get, params) => SomeObject(),
  );
  ```

<br>

## _**License**_

[MIT](https://github.com/adrianflutur/registry/blob/main/LICENSE)
