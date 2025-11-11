sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Object err) left, R Function(T val) right) =>
      this is Err<T>
      ? left((this as Err<T>).error)
      : right((this as Ok<T>).value);
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final Object error;
}
