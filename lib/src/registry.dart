import 'utils.dart';

/// This is the user-facing class which provides the Service Locator features.
class Registry {
  /// Singleton
  factory Registry() => _INSTANCE;
  static late final _INSTANCE = Registry._();
  Registry._();

  /// All registered objects will end up here
  final _registrantsByType = <Type, _Registrant>{};

  /// Assign a callback function to [debugLog]
  /// to get [Registry]'s internal logs in your app.
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()..debugLog = print;
  ///   ...
  /// }
  /// ```
  void Function(String message)? debugLog;

  void _log(String message) => debugLog?.call(_logTemplate(message));
  String _logTemplate(String message) {
    return '\x1B[34m[Registry Logger]\x1B[0m $message';
  }

  /// Put an object in the [Registry], based on it's type or it's interface type.
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()..put<SomeClass>((get, params) => SomeClass());
  /// }
  /// ```
  void put<T>(
    RegistrantBuilder<T> builder, {
    RegistrationMode registrationMode = RegistrationMode.lazySingleton,
    bool allowOneReregistration = false,
    DisposeCallback<T>? onDispose,
  }) {
    _log('Put object of type $T.');

    if (!_isRegistered<T>()) {
      _register<T>(
        builder,
        registerMode: registrationMode,
        allowOneReregistration: allowOneReregistration,
        onDispose: onDispose,
      );
      return;
    }

    if (!_getRegistrant<T>().allowOneReregistration) {
      throw RegistrantTypeAlreadyRegisteredException(T);
    }

    _update<T>(
      builder,
      registerMode: registrationMode,
      allowOneReregistration: allowOneReregistration,
      onDispose: onDispose,
    );
  }

  /// Get a registered object from the [Registry], based on it's type.
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()..put<SomeClass>((get, params) => SomeClass());
  ///   ...
  ///   final someClass = sl.get<SomeClass>();
  /// }
  /// ```
  T get<T>({
    RegistrationParams? params,
  }) {
    _log(
      'Get object of type $T '
      '${params != null ? 'with params: $params' : 'without params'}.',
    );

    if (!_isRegistered<T>()) throw RegistrantTypeNotFoundException(T);
    final registrant = _getRegistrant<T>();

    switch (registrant.registerMode) {
      case RegistrationMode.lazySingleton:
        if (!_isInstantiated<T>()) {
          return _instantiateAndGet<T>(params);
        }
        return _getInstance<T>();
      case RegistrationMode.lazyFactory:
        return _instantiateAndGet<T>(params);
      case RegistrationMode.eagerSingleton:
        return _getInstance<T>();
    }
  }

  /// Check if an object is registered into the [Registry] based on it's type.
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()..put<SomeClass>((get, params) => SomeClass());
  ///   ...
  ///   final isRegistered = sl.isRegistered<SomeClass>();
  /// }
  /// ```
  bool isRegistered<T>() {
    _log('Check if object of type $T is registered.');

    return _isRegistered<T>();
  }

  /// Refresh (rebuild) an instance from the [Registry] based on it's type
  /// and also disposes it (if `onDispose` is defined).
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()..put<SomeClass>((get, params) => SomeClass());
  ///   ...
  ///   final isRegistered = sl.isRegistered<SomeClass>();
  /// }
  /// ```
  void refreshInstance<T>() {
    _log('Refresh instance of type $T.');

    if (_isInstantiated<T>()) {
      final registrant = _getRegistrant<T>();
      final newInstance = registrant.builder(get, registrant.params);

      if (registrant.hasInstance) {
        registrant.maybeDispose();
      }

      _registrantsByType.update(
        T,
        (registrant) => registrant.copyWith(instance: newInstance),
      );
    }
  }

  /// Removes an object from the [Registry] based on it's type
  /// and also disposes it (if `onDispose` is defined).
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()..put<SomeClass>((get, params) => SomeClass());
  ///   ...
  ///   sl.remove<SomeClass>();
  ///
  ///   // Trying to get the object now will
  ///   // result in a RegistrantTypeNotFoundException
  /// }
  /// ```
  void remove<T>() {
    _log('Remove instance of type $T.');

    if (!_isRegistered<T>()) {
      throw RegistrantTypeNotFoundException(T);
    }

    final registrant = _getRegistrant<T>();
    registrant.maybeDispose();

    _registrantsByType.remove(T);
  }

  /// Clears the [Registry] by removing all registered objects
  /// and also disposes them (if `onDispose` is defined).
  ///
  /// Example:
  ///
  /// ```dart
  /// void main() {
  ///   final sl = Registry()
  ///       ..put<SomeClass>((get, params) => SomeClass())
  ///       ..put<SomeOtherClass>((get, params) => SomeOtherClass());
  ///   ...
  ///   sl.clear();
  ///
  ///   // Trying to get the object now will
  ///   // result in a RegistrantTypeNotFoundException
  /// }
  /// ```
  void clear() {
    _log('Clear the Registry.');

    _registrantsByType.values.forEach((r) => r.maybeDispose());
    _registrantsByType.clear();
  }

  void _register<T>(
    RegistrantBuilder<T> builder, {
    required RegistrationMode registerMode,
    bool allowOneReregistration = false,
    DisposeCallback<T>? onDispose,
  }) {
    switch (registerMode) {
      case RegistrationMode.lazySingleton:
      case RegistrationMode.lazyFactory:
        _registrantsByType.putIfAbsent(
          T,
          () => _Registrant<T>(
            builder: builder,
            instance: null,
            registerMode: registerMode,
            allowOneReregistration: allowOneReregistration,
            onDispose: onDispose,
          ),
        );
        break;
      case RegistrationMode.eagerSingleton:
        _registrantsByType.putIfAbsent(
          T,
          () => _Registrant<T>(
            builder: builder,
            instance: builder(get, null),
            registerMode: registerMode,
            allowOneReregistration: allowOneReregistration,
            onDispose: onDispose,
          ),
        );
        break;
    }
  }

  void _update<T>(
    RegistrantBuilder<T> builder, {
    required RegistrationMode registerMode,
    bool allowOneReregistration = false,
    DisposeCallback<T>? onDispose,
  }) {
    switch (registerMode) {
      case RegistrationMode.lazySingleton:
      case RegistrationMode.lazyFactory:
        _registrantsByType.update(
          T,
          (value) => (value as _Registrant<T>).copyWith(
            builder: builder,
            instance: null,
            registerMode: registerMode,
            allowOneReregistration: allowOneReregistration,
            onDispose: onDispose,
          ),
        );
        break;
      case RegistrationMode.eagerSingleton:
        _registrantsByType.update(
          T,
          (value) => (value as _Registrant<T>).copyWith(
            builder: builder,
            instance: builder(get, null),
            registerMode: registerMode,
            allowOneReregistration: allowOneReregistration,
            onDispose: onDispose,
          ),
        );
        break;
    }
  }

  T _getInstance<T>() {
    return _registrantsByType[T]!.instance as T;
  }

  _Registrant<T> _getRegistrant<T>() {
    return _registrantsByType[T]! as _Registrant<T>;
  }

  T _instantiateAndGet<T>(RegistrationParams? params) {
    final builder = _registrantsByType[T]!.builder as RegistrantBuilder<T>;
    final newInstance = builder(get, params);

    final registrant = _registrantsByType.update(
      T,
      (value) => value.copyWith(
        instance: newInstance,
        params: params,
      ),
    ) as _Registrant<T>;

    return registrant.instance!;
  }

  bool _isInstantiated<T>() {
    return _isRegistered<T>() && _getRegistrant<T>().hasInstance;
  }

  bool _isRegistered<T>() {
    return _registrantsByType.containsKey(T);
  }
}

// This is used for storing information about a specific object type.
class _Registrant<T> {
  final RegistrantBuilder<T> builder;
  final T? instance;
  final RegistrationMode registerMode;
  final bool allowOneReregistration;
  final RegistrationParams? params;
  final DisposeCallback<T>? onDispose;

  static const _sentinel = Object();

  _Registrant({
    required this.builder,
    this.instance,
    required this.registerMode,
    required this.allowOneReregistration,
    this.params,
    this.onDispose,
  });

  bool get hasInstance => instance != null;

  void maybeDispose() {
    if (onDispose != null && instance != null) {
      onDispose!(instance!);
    }
  }

  _Registrant<T> copyWith({
    Object? builder = _sentinel,
    Object? instance = _sentinel,
    RegistrationMode? registerMode,
    bool? allowOneReregistration,
    RegistrationParams? params,
    DisposeCallback<T>? onDispose,
  }) {
    return _Registrant<T>(
      instance: instance == _sentinel ? this.instance : instance as T?,
      builder:
          builder == _sentinel ? this.builder : builder as RegistrantBuilder<T>,
      registerMode: registerMode ?? this.registerMode,
      allowOneReregistration:
          allowOneReregistration ?? this.allowOneReregistration,
      params: params ?? this.params,
      onDispose: onDispose ?? this.onDispose,
    );
  }
}
