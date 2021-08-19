/// Available registration modes.
enum RegistrationMode { lazySingleton, eagerSingleton, lazyFactory }

typedef DisposeCallback<T> = void Function(T instance);

/// Builder function for the registered objects.
typedef RegistrantBuilder<T> = T Function(
  RegistrantResolver get,
  RegistrationParams? params,
);

/// Callback function for injecting nested dependencies
/// from within the [RegistrantBuilder] declaration.
typedef RegistrantResolver = T Function<T>({RegistrationParams? params});

/// Registration params.
///
/// Automatically casts param types at runtime.
class RegistrationParams {
  final Map<String, Object?> _params;

  /// Provide a [Map<String, Object?>] as the params.
  const RegistrationParams.named(this._params);

  /// Provide a `List<Object?>` as the params.
  ///
  /// Note that this is just for convenience, as it will still
  /// be turned into a `Map<String, Object?>`.
  ///
  /// By using this you also lose the ability to get the params by name.
  ///
  /// (Actually you can, by using the index as the name, such as '0' or '1'
  /// but it's not recomended).
  RegistrationParams.list(List<Object?> params)
      : _params = params.asMap().map((key, value) => MapEntry('$key', value));

  /// Get a param by it's index and it's type.
  ///
  /// The type will be auto-inferred most of the times, though.
  T? byIndex<T>(int index) => _params.values.toList()[index] as T?;

  /// Get a param by it's name and it's type.
  ///
  /// The type will be auto-inferred most of the times, though.
  T? byName<T>(String name) => _params[name] as T?;

  /// Helper method to modify the params inside the `put()` method.
  ///
  /// May be useful when passing params from an object to a dependency.
  RegistrationParams copyWith({
    Map<String, Object?>? params,
  }) {
    return RegistrationParams.named(params ?? _params);
  }

  @override
  String toString() => '[RegistrationParams] $_params';
}

/// Exception thrown when a registrant type is already registered.
class RegistrantTypeAlreadyRegisteredException implements Exception {
  /// Exception message.
  final String message;

  /// Constructor
  RegistrantTypeAlreadyRegisteredException(Type type)
      : message =
            'An object of type $type has already been put in the registry.';

  @override
  String toString() => message;
}

/// Exception for when a registrant type is not found.
class RegistrantTypeNotFoundException implements Exception {
  /// Exception message.
  final String message;

  /// Constructor
  RegistrantTypeNotFoundException(Type type)
      : message = 'There are no objects of type $type in the registry.';

  @override
  String toString() => message;
}
