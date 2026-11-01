/// Time source of the discovery engine. Injected so quotas, cooldowns and the
/// rolling window can be tested without waiting.
abstract class DiscoveryClock {
  const DiscoveryClock();

  DateTime now();
}

class SystemDiscoveryClock extends DiscoveryClock {
  const SystemDiscoveryClock();

  @override
  DateTime now() => DateTime.now();
}

/// Deterministic clock for tests and the QA harness.
class FakeDiscoveryClock extends DiscoveryClock {
  FakeDiscoveryClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  set value(DateTime value) => _now = value;

  void advance(Duration by) => _now = _now.add(by);
}
