import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_sync_service.dart';

const String _keyLastKnown = 'last_known_customers_updated_at';
const Duration _checkInterval = Duration(seconds: 45);

/// Periodicky kontroluje GET /api/sync/check. Ak boli na webe zmeny v zákazníkoch,
/// pošle event do [syncNeeded] – UI zobrazí notifikáciu (vykričník) a ponuku „Obnoviť“.
class SyncCheckService {
  SyncCheckService._();
  static final SyncCheckService instance = SyncCheckService._();

  Timer? _timer;
  final StreamController<void> _syncNeededController = StreamController<void>.broadcast();

  /// Stream: emituje keď backend hlási zmenu zákazníkov (úprava na webe).
  Stream<void> get syncNeeded => _syncNeededController.stream;

  bool get isRunning => _timer?.isActive ?? false;

  /// Spustí periodickú kontrolu (volaj z [HomeScreen] pri prihlásení).
  void start() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(_checkInterval, (_) => _check());
    _check(); // jedna kontrola hneď
  }

  /// Zastaví kontrolu (volaj pri odhlásení alebo dispose).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    final data = await fetchSyncCheck();
    final serverAt = data != null ? (data['customers_updated_at'] as num?)?.toInt() ?? 0 : 0;
    if (serverAt == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final lastKnown = prefs.getInt(_keyLastKnown) ?? 0;
    if (serverAt > lastKnown) {
      await prefs.setInt(_keyLastKnown, serverAt);
      if (!_syncNeededController.isClosed) {
        _syncNeededController.add(null);
      }
    }
  }

  void dispose() {
    stop();
    _syncNeededController.close();
  }
}
