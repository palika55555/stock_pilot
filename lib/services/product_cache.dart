import 'dart:async';
import '../models/product.dart';
import 'Database/database_service.dart';
import 'data_change_notifier.dart';

/// In-memory cache produktov.
///
/// Načíta produkty z SQLite raz pri štarte (alebo po prihlásení) a drží ich
/// v pamäti. Všetky obrazovky, ktoré potrebujú plný zoznam produktov
/// (scanner, recipe, price quote, stock out modal, home stats), čítajú odtiaľto
/// namiesto toho, aby zakaždým robili SQLite query.
///
/// Cache sa automaticky invaliduje keď [DataChangeNotifier.notify()] signalizuje
/// zmenu dát (insert/update/delete produktu). Ďalší prístup spustí lazy reload.
class ProductCache {
  static final ProductCache instance = ProductCache._();
  ProductCache._() {
    DataChangeNotifier.addListener(_onDataChanged);
  }

  List<Product> _products = [];
  bool _valid = false;
  Completer<List<Product>>? _loadCompleter;

  /// Aktuálne cachovane produkty. Prázdne ak ešte neboli načítané.
  List<Product> get products => _products;

  /// True keď je cache naplnená a aktuálna.
  bool get isReady => _valid;

  /// Načíta produkty z DB (ak cache je stale alebo prázdna) a vráti ich.
  /// Ak načítanie práve prebieha, počká a vráti rovnaký výsledok – žiadne
  /// duplicitné queries.
  Future<List<Product>> load({bool force = false}) async {
    if (_valid && !force) return _products;

    // Ak iná coroutine práve načítava, počkaj na ňu
    if (_loadCompleter != null) return _loadCompleter!.future;

    final c = Completer<List<Product>>();
    _loadCompleter = c;
    try {
      _products = await DatabaseService().getProducts();
      _valid = true;
      c.complete(_products);
    } catch (e, st) {
      c.completeError(e, st);
    } finally {
      _loadCompleter = null;
    }
    return c.future;
  }

  /// Invaliduje cache. Ďalší [load()] znovu načíta z DB.
  void invalidate() => _valid = false;

  /// Invaliduje a okamžite znovu načíta na pozadí (neblokuje volajúceho).
  void refreshInBackground() {
    _valid = false;
    load();
  }

  /// Vyčistí cache pri odhlásení.
  void clear() {
    _products = [];
    _valid = false;
  }

  void _onDataChanged() => invalidate();
}
