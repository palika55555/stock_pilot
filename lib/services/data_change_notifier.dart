/// Lightweight static event bus: DatabaseService calls notify() after every
/// local write; AutoPushService registers a callback to schedule an upload.
class DataChangeNotifier {
  static void Function()? _callback;

  static void register(void Function() cb) => _callback = cb;
  static void unregister() => _callback = null;
  static void notify() => _callback?.call();
}
