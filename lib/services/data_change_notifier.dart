/// Lightweight static event bus: DatabaseService calls notify() after every
/// local write. Supports multiple listeners (AutoPushService, ProductCache, …).
class DataChangeNotifier {
  static final List<void Function()> _listeners = [];

  // ── Legacy single-callback API (AutoPushService používa register/unregister) ──
  static void Function()? _legacyCallback;

  static void register(void Function() cb) => _legacyCallback = cb;
  static void unregister() => _legacyCallback = null;

  // ── Multi-listener API ─────────────────────────────────────────────────────
  static void addListener(void Function() cb) {
    if (!_listeners.contains(cb)) _listeners.add(cb);
  }

  static void removeListener(void Function() cb) => _listeners.remove(cb);

  static void notify() {
    _legacyCallback?.call();
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}
