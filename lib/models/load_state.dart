/// One vocabulary for «what is this screen (or block) doing with its data».
///
/// The two states that must never be confused:
///  * [LoadPhase.loading] — there is nothing to show yet;
///  * [LoadPhase.refreshing] — content is on screen and is being updated.
///    The content is never replaced by a loader in this state.
enum LoadPhase {
  /// Nothing requested yet.
  initial,

  /// First load: no data to show.
  loading,

  /// Data is shown and is current as far as the app knows.
  ready,

  /// Data is shown; an update is running.
  refreshing,

  /// Data is shown, a secondary part could not be loaded.
  partial,

  /// Data is shown from the device; the network is unavailable.
  offline,

  /// No data and the request failed.
  error,
}

/// Data of a screen together with its [LoadPhase].
class LoadState<T> {
  const LoadState._(this.phase, this.data, this.error);

  const LoadState.initial() : this._(LoadPhase.initial, null, null);
  const LoadState.loading() : this._(LoadPhase.loading, null, null);
  const LoadState.ready(T data) : this._(LoadPhase.ready, data, null);
  const LoadState.refreshing(T data) : this._(LoadPhase.refreshing, data, null);
  const LoadState.partial(T data, [Object? error])
    : this._(LoadPhase.partial, data, error);
  const LoadState.offline(T data) : this._(LoadPhase.offline, data, null);
  const LoadState.error(Object error) : this._(LoadPhase.error, null, error);

  final LoadPhase phase;
  final T? data;
  final Object? error;

  /// Content can be rendered (whatever else is happening).
  bool get hasData => data != null;

  /// The only state that may show a full-screen loader.
  bool get isFirstLoad => phase == LoadPhase.loading;

  /// Content stays; at most an unobtrusive progress line is shown.
  bool get isRefreshing => phase == LoadPhase.refreshing;

  bool get isError => phase == LoadPhase.error;

  @override
  String toString() => 'LoadState<$T>($phase)';
}

/// Resolves a first load, a refresh and a failure to the right [LoadState]:
/// a failed request never takes content off the screen.
LoadState<T> loadStateAfterFailure<T>(
  T? shown,
  Object error, {
  required bool offline,
}) {
  if (shown == null) return LoadState<T>.error(error);
  return offline
      ? LoadState<T>.offline(shown)
      : LoadState<T>.partial(shown, error);
}
