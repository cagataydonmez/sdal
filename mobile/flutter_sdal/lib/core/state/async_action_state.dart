enum AsyncActionStatus { idle, loading, success, error }

class AsyncActionState {
  const AsyncActionState({required this.status, this.message, this.scope});

  final AsyncActionStatus status;
  final String? message;
  final String? scope;

  bool get isIdle => status == AsyncActionStatus.idle;
  bool get isLoading => status == AsyncActionStatus.loading;
  bool get isSuccess => status == AsyncActionStatus.success;
  bool get isError => status == AsyncActionStatus.error;

  const AsyncActionState.idle() : this(status: AsyncActionStatus.idle);

  const AsyncActionState.loading({String? scope})
    : this(status: AsyncActionStatus.loading, scope: scope);

  const AsyncActionState.success({String? message, String? scope})
    : this(status: AsyncActionStatus.success, message: message, scope: scope);

  const AsyncActionState.error({String? message, String? scope})
    : this(status: AsyncActionStatus.error, message: message, scope: scope);
}
