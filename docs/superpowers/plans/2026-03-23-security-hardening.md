# Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Odstrániť kritické bezpečnostné riziká v StockPilot Flutter appke – debug logy, plaintext heslá, hardcoded config.

**Architecture:** 3 nezávislé oblasti: (1) logovanie – odstrániť print(), (2) heslá – SHA-256 + salt cez existujúci `crypto` package, (3) konfigurácia – presunúť API konštanty do dedikovaného súboru.

**Tech Stack:** Flutter/Dart, sqflite, crypto (SHA-256), flutter_secure_storage (už nainštalované)

---

## Súbory ktoré budú zmenené

| Akcia | Súbor | Dôvod |
|-------|-------|-------|
| Vytvoriť | `lib/config/app_config.dart` | API konštanty von z business kódu |
| Vytvoriť | `lib/services/Auth/hash_service.dart` | SHA-256 + salt hashing logika |
| Upraviť | `lib/services/api_sync_service.dart` | odstraniť 32 print(), presunúť konštanty, odstraniť _decodeJwt |
| Upraviť | `lib/services/Database/database_service.dart` | odstraniť 12 print(), pridať password_salt stĺpec + migrácia, hashnutie existujúcich hesiel |
| Upraviť | `lib/services/Auth/password_service.dart` | hash porovnanie miesto plaintext |
| Upraviť | `lib/screens/Login/login_page.dart` | hash porovnanie pri lokálnom logine |
| Upraviť | `lib/screens/Home/Home_screen.dart` | odstraniť 1 print(), neposielať plaintext heslo do syncUserToBackend |
| Upraviť | `lib/services/user_session.dart` | odstraniť 1 print() |
| Upraviť | `lib/services/External/finstat_service.dart` | odstraniť 1 print() |
| Upraviť | `lib/screens/Customers/customers_page.dart` | odstraniť 2 print() |
| Upraviť | `lib/screens/pallet/customers_pallets_screen.dart` | odstraniť 3 print() |

---

## Task 1: Odstraniť DEBUG print() logy — api_sync_service.dart

**Súbory:**
- Upraviť: `lib/services/api_sync_service.dart`

> **Kontext:** Súbor obsahuje 32 `print()` volaní. Tie odhaľujú JWT tokeny, URL, response body a stack traces v produkcii. Odstránime ich a necháme iba funkčné error throw-y.

- [ ] **Krok 1: Odstraniť celý blok JWT decode debug kódu (riadky 359–372)**

  Nájdi v `lib/services/api_sync_service.dart` a **vymaž** tieto riadky:
  ```dart
  print('DEBUG login userId: ${map?['user']?['id']}');
  print('DEBUG login accessToken decoded: ${_decodeJwt(access)}');
  final token = access;
  if (token != null && token.isNotEmpty) {
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        var payloadPart = parts[1];
        while (payloadPart.length % 4 != 0) payloadPart += '=';
        final payload = utf8.decode(base64Url.decode(payloadPart));
        print('DEBUG JWT payload: $payload');
      }
    } catch (_) {}
  }
  print('DEBUG backend login parsed userId=$userId accessPresent=${access != null && access.isNotEmpty} refreshPresent=${refresh != null && refresh.isNotEmpty}');
  ```

- [ ] **Krok 2: Odstrániť všetky ostatné print() z funkcie fetchBackendToken**

  Vymaž tieto riadky z `fetchBackendToken`:
  ```dart
  print('DEBUG backend login request: url=$uri username=$username rememberMe=$rememberMe');
  print('DEBUG backend login status: ${res.statusCode}');
  print('DEBUG login response: ${res.body}');
  print('DEBUG backend login failed with status ${res.statusCode}');
  print('DEBUG backend login: missing access/refresh token in response');
  print('DEBUG backend login error: $e');
  print(st);
  ```

- [ ] **Krok 3: Odstraniť print() z ostatných sync funkcií**

  Vymaž z celého súboru všetky `print(` riadky vrátane:
  - `print('DEBUG fetchProductsFromBackendWithToken: downloaded=...')` (riadok 465)
  - `print('syncBatchesToBackend failed: ...')` (riadok 542)
  - `print('syncBatchesToBackend error: ...')` (542–546)
  - `print('syncReceiptsToBackend failed: ...')` (636)
  - `print('syncReceiptsToBackend error: ...')` (639)
  - `print('syncStockOutsToBackend failed: ...')` (708)
  - `print('syncStockOutsToBackend error: ...')` (711)
  - `print('syncRecipesToBackend failed: ...')` (768)
  - `print('syncRecipesToBackend error: ...')` (771)
  - `print('syncProductionOrdersToBackend failed: ...')` (820)
  - `print('syncProductionOrdersToBackend error: ...')` (823)
  - `print('syncQuotesToBackend failed: ...')` (880)
  - `print('syncQuotesToBackend error: ...')` (883)
  - `print('syncTransportsToBackend failed: ...')` (927)
  - `print('syncTransportsToBackend error: ...')` (930)
  - `print('syncCompanyToBackend failed: ...')` (972)
  - `print('syncCompanyToBackend error: ...')` (975)
  - `print('syncInvoicesToBackend failed: ...')` (1034–1038)
  - `print('syncInvoicesToBackend error: ...')` (1042)

- [ ] **Krok 4: Odstraniť funkciu `_decodeJwt`**

  Vymaž celú funkciu (riadky 35–46):
  ```dart
  /// Decode JWT payload (middle part) for debug. Returns map or null.
  dynamic _decodeJwt(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      var payload = parts[1];
      while (payload.length % 4 != 0) payload += '=';
      return jsonDecode(utf8.decode(base64Url.decode(payload)));
    } catch (_) {
      return null;
    }
  }
  ```

- [ ] **Krok 5: Skontrolovať že flutter build nevypíše žiadne errory**

  Spusti:
  ```bash
  cd C:\Users\pavol\Desktop\Flutter\stock_pilot
  flutter analyze lib/services/api_sync_service.dart
  ```
  Očakávané: `No issues found!` alebo len warnings, nie errors.

- [ ] **Krok 6: Commit**

  ```bash
  git add lib/services/api_sync_service.dart
  git commit -m "security: remove all debug print() and JWT decode logging from api_sync_service"
  ```

---

## Task 2: Odstraniť print() z ostatných súborov

**Súbory:**
- Upraviť: `lib/services/Database/database_service.dart`
- Upraviť: `lib/screens/Home/Home_screen.dart`
- Upraviť: `lib/services/user_session.dart`
- Upraviť: `lib/services/External/finstat_service.dart`
- Upraviť: `lib/screens/Customers/customers_page.dart`
- Upraviť: `lib/screens/pallet/customers_pallets_screen.dart`

- [ ] **Krok 1: Odstraniť print() z database_service.dart**

  Nájdi a vymaž všetkých 12 výskytov `print(` v `lib/services/Database/database_service.dart`.
  Použi `flutter analyze` na kontrolu že nič nezlomíme.

- [ ] **Krok 2: Odstraniť print() zo zvyšných súborov**

  Pre každý súbor — nájdi `print(` a vymaž celý riadok:
  - `lib/screens/Home/Home_screen.dart` — 1 výskyt (`print('DEBUG HomeScreen.initState...')`)
  - `lib/services/user_session.dart` — 1 výskyt
  - `lib/services/External/finstat_service.dart` — 1 výskyt
  - `lib/screens/Customers/customers_page.dart` — 2 výskyty
  - `lib/screens/pallet/customers_pallets_screen.dart` — 3 výskyty

- [ ] **Krok 3: Verify — žiadne print() v lib/**

  Spusti:
  ```bash
  grep -r "print(" lib/ --include="*.dart" -l
  ```
  Očakávané: prázdny výstup (žiadne súbory).

- [ ] **Krok 4: Flutter analyze celá lib/**

  ```bash
  flutter analyze
  ```
  Očakávané: no errors (warnings OK).

- [ ] **Krok 5: Commit**

  ```bash
  git add lib/services/Database/database_service.dart lib/screens/Home/Home_screen.dart lib/services/user_session.dart lib/services/External/finstat_service.dart lib/screens/Customers/customers_page.dart lib/screens/pallet/customers_pallets_screen.dart
  git commit -m "security: remove all debug print() statements from remaining files"
  ```

---

## Task 3: Presunúť API konštanty do app_config.dart

**Súbory:**
- Vytvoriť: `lib/config/app_config.dart`
- Upraviť: `lib/services/api_sync_service.dart`

> **Kontext:** `kBackendApiBase` a `kApiPrefix` sú hardcoded na začiatku `api_sync_service.dart`. Presunieme ich do dedikovaného config súboru, čo umožní jednoduché menenie bez nutnosti hľadať v business kóde.

- [ ] **Krok 1: Vytvoriť `lib/config/app_config.dart`**

  ```dart
  /// Centrálna konfigurácia aplikácie.
  /// Meniť tu — nie v business kóde.
  class AppConfig {
    AppConfig._();

    /// Base URL backendu (bez trailing slash).
    static const String backendApiBase = 'https://backend.stockpilot.sk';

    /// API prefix – backend montuje router na /api/:API_PATH_PREFIX/.
    /// Bez tohto prefixu backend vráti 404.
    static const String apiPrefix = '/api/sp-9f2a4e1b';

    /// Plná base URL pre API volania.
    static String get apiBase => '$backendApiBase$apiPrefix';
  }
  ```

- [ ] **Krok 2: Aktualizovať `api_sync_service.dart` — použiť AppConfig**

  V súbore `lib/services/api_sync_service.dart`:

  Pridaj import (za ostatné importy):
  ```dart
  import '../config/app_config.dart';
  ```

  Vymaž tieto 3 riadky:
  ```dart
  const String kBackendApiBase = 'https://backend.stockpilot.sk';
  const String kApiPrefix = '/api/sp-9f2a4e1b';
  String get _apiBase => '$kBackendApiBase$kApiPrefix';
  ```

  **DÔLEŽITÉ — string interpolácia v Dart:**
  `$_apiBase` v stringu funguje lebo `_apiBase` je jednoduchý identifikátor.
  `AppConfig.apiBase` obsahuje `.` — preto musíš použiť `${AppConfig.apiBase}`.

  Použi Find & Replace v editore:
  - Hľadaj: `'$_apiBase`  → Nahraď: `'${AppConfig.apiBase}`
  - Hľadaj: `"$_apiBase`  → Nahraď: `"${AppConfig.apiBase}`

  Napríklad:
  ```dart
  // PRED:
  final uri = Uri.parse('$_apiBase/auth/login');

  // PO:
  final uri = Uri.parse('${AppConfig.apiBase}/auth/login');
  ```

  Skontroluj replace — `_apiBase` sa vyskytuje ~35× v súbore.

- [ ] **Krok 3: Flutter analyze**

  ```bash
  flutter analyze lib/services/api_sync_service.dart lib/config/app_config.dart
  ```
  Očakávané: no errors.

- [ ] **Krok 4: Commit**

  ```bash
  git add lib/config/app_config.dart lib/services/api_sync_service.dart
  git commit -m "refactor: move API config constants to AppConfig class"
  ```

---

## Task 4: Implementovať password hashing (SHA-256 + salt)

**Súbory:**
- Vytvoriť: `lib/services/Auth/hash_service.dart`
- Upraviť: `lib/services/Auth/password_service.dart`
- Upraviť: `lib/screens/Login/login_page.dart`
- Upraviť: `lib/services/api_sync_service.dart` (funkcia `userFromBackendProfile`)
- Upraviť: `lib/services/Database/database_service.dart` (schema + migrácia)

> **Kontext:** Package `crypto: ^3.0.5` je **už nainštalovaný** v pubspec.yaml. Heslá sú momentálne uložené v plaintext v stĺpci `password TEXT`. Pridáme stĺpec `password_salt TEXT` a pri každom uložení budeme hashovať. Lokálna DB je offline cache — heslo sa ukladá len pre offline login fallback.
>
> **Schéma hashovania:** `SHA-256(salt + ":" + password)` kde salt je 16-byte random hex string.

- [ ] **Krok 1: Vytvoriť `lib/services/Auth/hash_service.dart`**

  ```dart
  import 'dart:convert';
  import 'dart:math';
  import 'package:crypto/crypto.dart';

  /// Hashing hesiel pomocou SHA-256 + náhodný salt.
  /// Používa sa len pre lokálnu offline DB cache.
  class HashService {
    HashService._();

    static final Random _rng = Random.secure();

    /// Vygeneruje 16-byte náhodný salt ako hex string.
    static String generateSalt() {
      final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }

    /// Zahashuje heslo so saltom: SHA-256(salt + ":" + password).
    /// Vráti hex digest.
    static String hashPassword(String password, String salt) {
      final input = utf8.encode('$salt:$password');
      return sha256.convert(input).toString();
    }

    /// Overí heslo voči uloženému hashu a saltu.
    /// Vráti true ak heslo sedí.
    static bool verifyPassword(String password, String storedHash, String salt) {
      final computed = hashPassword(password, salt);
      // Constant-time comparison aby sme predišli timing útokom.
      if (computed.length != storedHash.length) return false;
      var result = 0;
      for (var i = 0; i < computed.length; i++) {
        result |= computed.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
      }
      return result == 0;
    }
  }
  ```

- [ ] **Krok 2: Pridať `password_salt` stĺpec do VŠETKÝCH users definícií v `database_service.dart`**

  Súbor `database_service.dart` definuje users tabuľku na **3 miestach** — všetky 3 treba aktualizovať:

  **Miesto 1 — riadok ~292** (hlavná inicializačná cesta v `_initDb`):
  ```dart
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    password_salt TEXT,    -- pridaj tento riadok
    full_name TEXT,
    ...
  )
  ```

  **Miesto 2 — riadok ~1175** (v `_onUpgrade`, early migration block):
  Nájdi `CREATE TABLE IF NOT EXISTS users (` okolo riadku 1175 a rovnako pridaj `password_salt TEXT,` za `password TEXT,`.

  **Miesto 3 — riadok ~2194** (v metóde `_onCreate`):
  Nájdi `CREATE TABLE users (` okolo riadku 2194 a rovnako pridaj `password_salt TEXT,` za `password TEXT,`.

- [ ] **Krok 3: Pridať DB migráciu pre existujúce inštalácie**

  Aktuálna DB verzia je **38** (riadok 238: `version: 38`).

  **POZOR:** `_onUpgrade` má migrácie v neštandardnom poradí — posledný blok fyzicky v kóde je `if (oldVersion < 30)` na riadku 2114. Nový blok pridaj **za** riadok 2151 (za closing brace `if (oldVersion < 30)`), **pred** closing brace celej `_onUpgrade` metódy (riadok 2152).

  ```dart
  // Version 39: password hashing – add salt column
  if (oldVersion < 39) {
    final tableInfo = await db.rawQuery('PRAGMA table_info(users)');
    final hasSalt = tableInfo.any((c) => c['name'] == 'password_salt');
    if (!hasSalt) {
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
    }
    // Existujúce plaintext heslá ponecháme — pri ďalšom prihlásení
    // sa automaticky zahashujú (viď login_page.dart Task 4 Krok 6).
  }
  ```

  Zvýš verziu DB — nájdi riadok 238 (`version: 38`) a zmeň na:
  ```dart
  version: 39,
  ```

- [ ] **Krok 4: Aktualizovať `User` model — pridať `passwordSalt` pole**

  Otvor `lib/models/user.dart`.

  **DÔLEŽITÉ:** `passwordSalt` musí byť **optional** (`String?` bez `required`) aby 18 existujúcich callsites `User(...)` po celom projekte nepadli na compile errory. Existujúce volania jednoducho passwordSalt nevyplnia (bude `null`) — to je OK, migrácia nastane pri prvom logine.

  Pridaj pole (za `password`):
  ```dart
  final String? passwordSalt;
  ```

  Aktualizuj konštruktor — pridaj **bez** `required`:
  ```dart
  User({
    this.id,
    required this.username,
    required this.password,
    this.passwordSalt,        // <-- pridaj tu (optional, bez required)
    required this.fullName,
    ...
  });
  ```

  V `toMap()` pridaj:
  ```dart
  'password_salt': passwordSalt,
  ```

  V `fromMap()` pridaj:
  ```dart
  passwordSalt: map['password_salt'] as String?,
  ```

- [ ] **Krok 5: Kompletne prepísať `password_service.dart` — hash porovnanie + hash pri zmene**

  Otvor `lib/services/Auth/password_service.dart`.

  **Prepíš celý súbor** (aktuálny má 45 riadkov):

  ```dart
  import '../../models/user.dart';
  import '../Database/database_service.dart';
  import 'hash_service.dart';

  class PasswordService {
    final DatabaseService _dbService = DatabaseService();

    /// Overí, či je zadané heslo správne pre daného používateľa.
    /// Podporuje starý plaintext aj nový SHA-256+salt formát.
    Future<bool> verifyPassword(String username, String password) async {
      final user = await _dbService.getUserByUsername(username);
      if (user == null) return false;
      return _verifyUserPassword(user, password);
    }

    /// Zmení heslo pre daného používateľa.
    /// Vracia true ak bola zmena úspešná.
    Future<bool> changePassword(
      String username,
      String currentPassword,
      String newPassword,
    ) async {
      final user = await _dbService.getUserByUsername(username);
      if (user == null || !_verifyUserPassword(user, currentPassword)) {
        return false;
      }

      // Nové heslo vždy hashujeme — nikdy neukladáme plaintext.
      final newSalt = HashService.generateSalt();
      final newHash = HashService.hashPassword(newPassword, newSalt);

      final updatedUser = User(
        id: user.id,
        username: user.username,
        password: newHash,
        passwordSalt: newSalt,
        fullName: user.fullName,
        role: user.role,
        email: user.email,
        phone: user.phone,
        department: user.department,
        avatarUrl: user.avatarUrl,
        joinDate: user.joinDate,
      );

      await _dbService.updateUser(updatedUser);
      return true;
    }

    /// Overí heslo — podporuje plaintext (starý) aj hash (nový).
    /// Plaintext fallback je tu len pre migráciu; po prvom logine
    /// je záznam automaticky konvertovaný na hash.
    bool _verifyUserPassword(User user, String rawPassword) {
      final salt = user.passwordSalt;
      if (salt == null || salt.isEmpty) {
        // Starý plaintext záznam — porovnaj priamo.
        return user.password == rawPassword;
      }
      return HashService.verifyPassword(rawPassword, user.password, salt);
    }
  }
  ```

- [ ] **Krok 6: Aktualizovať `login_page.dart` — hash porovnanie + migrácia pri logine**

  Otvor `lib/screens/Login/login_page.dart`.

  Pridaj import:
  ```dart
  import '../../services/Auth/hash_service.dart';
  ```

  Nájdi riadok:
  ```dart
  final bool localOk = user != null && user.password == password;
  ```

  Nahraď:
  ```dart
  // Overenie hesla — ak salt chýba (starý záznam), porovnaj plaintext a ihneď zahashuj.
  bool localOk = false;
  if (user != null) {
    final salt = user.passwordSalt;
    if (salt == null || salt.isEmpty) {
      // Starý plaintext záznam — overíme a migrujeme na hash.
      if (user.password == password) {
        localOk = true;
        // Migruj na hash.
        final newSalt = HashService.generateSalt();
        final newHash = HashService.hashPassword(password, newSalt);
        final migratedUser = User(
          id: user.id,
          username: user.username,
          password: newHash,
          passwordSalt: newSalt,
          fullName: user.fullName,
          role: user.role,
          email: user.email,
          phone: user.phone,
          department: user.department,
          avatarUrl: user.avatarUrl,
          joinDate: user.joinDate,
        );
        await _dbService.updateUser(migratedUser);
        user = migratedUser;
      }
    } else {
      localOk = HashService.verifyPassword(password, user.password ?? '', salt);
    }
  }
  ```

- [ ] **Krok 7: Aktualizovať `userFromBackendProfile` v `api_sync_service.dart`**

  Nájdi funkciu `userFromBackendProfile` (riadok ~72). Aktuálne ukladá plaintext heslo.

  Pridaj import:
  ```dart
  import 'Auth/hash_service.dart';
  ```

  Uprav funkciu — pri ukladaní lokálneho usera z backendu, zahashuj heslo:
  ```dart
  User userFromBackendProfile(String username, String password, Map<String, dynamic>? profile) {
    final p = profile ?? {};
    // Nikdy neukladáme plaintext heslo — vždy hashujeme.
    final salt = HashService.generateSalt();
    final hashedPassword = HashService.hashPassword(password, salt);
    return User(
      id: null,
      username: p['username']?.toString() ?? username,
      password: hashedPassword,
      passwordSalt: salt,
      fullName: p['full_name']?.toString() ?? p['fullName']?.toString() ?? username,
      role: p['role']?.toString() ?? 'user',
      email: p['email']?.toString() ?? '',
      phone: p['phone']?.toString() ?? '',
      department: p['department']?.toString() ?? '',
      avatarUrl: p['avatar_url']?.toString() ?? p['avatarUrl']?.toString() ?? 'https://i.pravatar.cc/150?u=$username',
      joinDate: DateTime.now(),
    );
  }
  ```

- [ ] **Krok 8: Skontrolovať Home_screen.dart — neposielať password pri role sync**

  Otvor `lib/screens/Home/Home_screen.dart`, nájdi riadok:
  ```dart
  password: user.password,
  ```

  Toto ide do `syncUserToBackend` — backend by nemal dostávať lokálny hash.
  Nahraď na:
  ```dart
  password: '', // Heslo sa nesynchronizuje na backend — spravuje backend samostatne.
  ```

- [ ] **Krok 9: Flutter analyze**

  ```bash
  flutter analyze lib/services/Auth/ lib/models/user.dart lib/screens/Login/login_page.dart lib/services/api_sync_service.dart
  ```
  Očakávané: no errors.

- [ ] **Krok 10: Commit**

  ```bash
  git add lib/services/Auth/hash_service.dart lib/services/Auth/password_service.dart lib/models/user.dart lib/services/Database/database_service.dart lib/screens/Login/login_page.dart lib/services/api_sync_service.dart lib/screens/Home/Home_screen.dart
  git commit -m "security: implement SHA-256+salt password hashing, migrate plaintext passwords on login"
  ```

---

## Task 5: Centralizovať magic strings — AppConstants

**Súbory:**
- Vytvoriť: `lib/config/app_constants.dart`
- Upraviť: `lib/services/user_session.dart` (roly)
- Upraviť: `lib/services/Database/database_service.dart` (`'current_user_owner_name'` a podobné keys)

> **Kontext:** Reťazce ako `'admin'`, `'user'`, `'current_user_owner_name'` sú rozhádzané po viacerých súboroch. Centralizujeme ich.

- [ ] **Krok 1: Vytvoriť `lib/config/app_constants.dart`**

  ```dart
  /// Centrálne konštanty aplikácie — roly, SharedPreferences kľúče, defaults.
  class AppConstants {
    AppConstants._();

    // --- User roles ---
    static const String roleAdmin = 'admin';
    static const String roleUser = 'user';

    // --- SharedPreferences kľúče ---
    static const String keyDbPath = 'db_path';
    static const String keyRememberMe = 'remember_me';
    static const String keySavedUsername = 'saved_username';
    static const String keyCurrentUserOwnerName = 'current_user_owner_name';
    static const String keyCurrentUserOwnerUsername = 'current_user_owner_username';

    // --- Default values ---
    static const String defaultAvatarBase = 'https://i.pravatar.cc/150?u=';
  }
  ```

- [ ] **Krok 2: Nahradiť `'admin'` a `'user'` literály kde sú porovnávané**

  Nájdi v `lib/` všetky výskyty:
  ```bash
  grep -r "== 'admin'\|== 'user'\|!= 'admin'\|!= 'user'" lib/ --include="*.dart" -n
  ```

  Pre každý nájdený súbor pridaj import a nahraď:
  ```dart
  import '../config/app_constants.dart'; // (alebo správna relatívna cesta)

  // namiesto:
  if (role == 'admin')
  // použi:
  if (role == AppConstants.roleAdmin)
  ```

- [ ] **Krok 3: Nahradiť `'current_user_owner_name'` kľúč**

  ```bash
  grep -r "current_user_owner_name\|current_user_owner_username\|db_path\|remember_me\|saved_username" lib/ --include="*.dart" -l
  ```

  Pre každý nájdený súbor nahraď string literál konštantou z `AppConstants`.

- [ ] **Krok 4: Flutter analyze**

  ```bash
  flutter analyze lib/config/app_constants.dart
  flutter analyze
  ```

- [ ] **Krok 5: Commit**

  ```bash
  git add lib/config/app_constants.dart
  git add -u lib/
  git commit -m "refactor: centralize magic strings and roles into AppConstants"
  ```

---

## Záverečná verifikácia

- [ ] **Spusti kompletný flutter analyze**

  ```bash
  flutter analyze
  ```
  Očakávané: 0 errors, ideálne 0 warnings.

- [ ] **Manuálny test loginu**

  1. Spusti appku: `flutter run`
  2. Prihlás sa s existujúcim účtom — mal by automaticky migrovať plaintext heslo na hash
  3. Odhláś sa a znovu prihlás — druhý login musí fungovať (overuje hash)
  4. Skontroluj v SQLite DB že `password` stĺpec obsahuje 64-znakový hex string (nie plaintext)
  5. Skontroluj že `password_salt` stĺpec nie je NULL

- [ ] **Overenie žiadnych print() v produkcii**

  ```bash
  grep -r "print(" lib/ --include="*.dart"
  ```
  Očakávané: prázdny výstup.

- [ ] **Finálny commit**

  ```bash
  git tag security-hardening-v1
  ```

---

## Čo tento plán NERIEŠI (ďalší krok)

Tieto veci sú dôležité ale vyžadujú väčšie zmeny — riešiť samostatne:

| Problém | Odporúčanie |
|---------|-------------|
| Šifrovaná SQLite DB | Použiť `sqflite_cipher` — breaking change pre existujúce DB |
| Certificate pinning | Vlastný `HttpClient` s cert overením |
| Rate limiting loginu | Stav v `AuthStorageService` — count + timestamp |
| Server-side role verification | Zmena na backende |
| SharedPreferences → SecureStorage | Audit a postupná migrácia |
