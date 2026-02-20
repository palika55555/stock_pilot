// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class AppLocalizationsSk extends AppLocalizations {
  AppLocalizationsSk([String locale = 'sk']) : super(locale);

  @override
  String get appTitle => 'StockPilot';

  @override
  String get settings => 'Nastavenia';

  @override
  String get overview => 'Prehľad';

  @override
  String get scanProduct => 'Skenovať tovar';

  @override
  String get warehouseSupplies => 'Skladové zásoby';

  @override
  String get goodsReceipt => 'Príjem tovaru';

  @override
  String get warehouseMovements => 'Pohyby na sklade';

  @override
  String get suppliers => 'Dodávatelia';

  @override
  String get logout => 'Odhlásiť sa';

  @override
  String get login => 'Prihlásenie';

  @override
  String get stockSystem => 'Skladový Systém';

  @override
  String get loginSubtitle => 'Prihláste sa pre pokračovanie';

  @override
  String get loginLabel => 'Login';

  @override
  String get passwordLabel => 'Heslo';

  @override
  String get loginButton => 'PRIHLÁSIŤ SA';

  @override
  String get loginError => 'Nesprávny login alebo heslo';

  @override
  String get loginRequired => 'Zadajte login';

  @override
  String get passwordMinLength => 'Heslo musí mať aspoň 4 znaky';

  @override
  String loggedInAs(String name) {
    return 'Prihlásený ako $name';
  }

  @override
  String roleChangedTo(String role) {
    return 'Rola zmenená na $role';
  }

  @override
  String get notifications => 'Notifikácie';

  @override
  String get darkMode => 'Tmavý režim';

  @override
  String get darkModeSubtitle => 'Použiť tmavú tému aplikácie';

  @override
  String get language => 'Jazyk';

  @override
  String get notificationsSubtitle => 'Povoliť upozornenia a oznámenia';

  @override
  String get application => 'Aplikácia';

  @override
  String get database => 'Databáza';

  @override
  String get databaseLocation => 'Umiestnenie databázy';

  @override
  String get defaultPath => 'Predvolené';

  @override
  String get about => 'O aplikácii';

  @override
  String get stockManagement => 'Skladový manažment';

  @override
  String get close => 'Zavrieť';

  @override
  String get unknown => 'Neznáme';

  @override
  String get darkModeOn => 'Tmavý režim zapnutý';

  @override
  String get darkModeOff => 'Tmavý režim vypnutý';

  @override
  String languageChanged(String lang) {
    return 'Jazyk zmenený na $lang';
  }

  @override
  String get languageSlovak => 'Slovenčina';

  @override
  String get languageCzech => 'Čeština';

  @override
  String get languageEnglish => 'English';

  @override
  String get search => 'Hľadať';

  @override
  String get addSupplier => 'Pridať dodávateľa';

  @override
  String get add => 'Pridať';

  @override
  String get active => 'Aktívny';

  @override
  String get inactive => 'Neaktívny';

  @override
  String get all => 'Všetci';

  @override
  String get allActive => 'Aktívni';

  @override
  String get allInactive => 'Neaktívni';

  @override
  String get noSuppliers => 'Žiadni dodávatelia';

  @override
  String get noResults => 'Žiadne výsledky';

  @override
  String get searchHintSuppliers => 'Hľadať podľa názvu, IČO, mesta...';

  @override
  String get deleteSupplier => 'Vymazať dodávateľa?';

  @override
  String deleteSupplierConfirm(String name) {
    return 'Naozaj chcete vymazať dodávateľa \"$name\"?';
  }

  @override
  String get cancel => 'Zrušiť';

  @override
  String get delete => 'Vymazať';

  @override
  String get edit => 'Upraviť';

  @override
  String get supplierDeleted => 'Dodávateľ bol vymazaný';

  @override
  String get inbound => 'Príchod';

  @override
  String get outbound => 'Výdaj';

  @override
  String get detail => 'Detail';

  @override
  String get stockMovements => 'Pohyby zásob';

  @override
  String get recentMovements => 'Posledné pohyby';

  @override
  String get inboundReceipts => 'Príjemky';

  @override
  String get inboundGoods => 'Príjem tovaru';

  @override
  String get outboundReceipts => 'Výdajky';

  @override
  String get outboundGoods => 'Výdaj tovaru';

  @override
  String get customers => 'Zákazníci';

  @override
  String get addCustomer => 'Pridať zákazníka';

  @override
  String get noCustomers => 'Žiadni zákazníci';

  @override
  String get searchHintCustomers => 'Hľadať podľa názvu, IČO, mesta...';

  @override
  String get deleteCustomer => 'Vymazať zákazníka?';

  @override
  String deleteCustomerConfirm(String name) {
    return 'Naozaj chcete vymazať zákazníka \"$name\"?';
  }

  @override
  String get customerDeleted => 'Zákazník bol vymazaný';

  @override
  String get priceQuote => 'Cenová ponuka';

  @override
  String get overviewNotesAndTasks => 'Poznámky a úlohy';

  @override
  String get overviewNotesTitle => 'Poznámky';

  @override
  String get overviewTasksTitle => 'Úlohy';

  @override
  String get overviewNotesPlaceholder => 'Pridajte poznámku...';

  @override
  String get overviewNewTaskHint => 'Nová úloha...';

  @override
  String get overviewAddTask => 'Pridať úlohu';

  @override
  String get quoteDetails => 'Údaje cenovej ponuky';

  @override
  String get quoteNumber => 'Číslo ponuky';

  @override
  String get validUntil => 'Platnosť do';

  @override
  String get notes => 'Poznámky';

  @override
  String get notesHint => 'Poznámka pre zákazníka (zobrazí sa na ponuke)';

  @override
  String get pricesIncludeVat => 'Ceny vrátane DPH';

  @override
  String get quoteItems => 'Položky ponuky';

  @override
  String get addItem => 'Pridať položku';

  @override
  String get noQuoteItems => 'Žiadne položky. Pridajte produkty.';

  @override
  String get subtotalWithoutVat => 'Medzisúčet bez DPH';

  @override
  String get totalWithVat => 'Spolu s DPH';

  @override
  String get saveQuote => 'Uložiť cenovú ponuku';

  @override
  String get quoteSaved => 'Cenová ponuka bola uložená';

  @override
  String get quoteNumberRequired => 'Zadajte číslo ponuky';

  @override
  String get offerFor => 'Ponuka pre:';

  @override
  String get dateOfIssue => 'Dátum vystavenia';

  @override
  String get itemDescription => 'Popis položky';

  @override
  String get quantity => 'Množstvo';

  @override
  String get unitShort => 'MJ';

  @override
  String get pricePerUnit => 'Cena za MJ';

  @override
  String get totalWithoutVatShort => 'Celkom bez DPH';

  @override
  String get vatShort => 'DPH';

  @override
  String get totalWithVatShort => 'Celkom s DPH';

  @override
  String get totalLabel => 'Spolu:';

  @override
  String get vatPayer => 'Platiteľ DPH';

  @override
  String get ourCompany => 'Naša firma';

  @override
  String get editCompany => 'Upraviť údaje firmy';

  @override
  String get printPdf => 'Tlačiť / PDF';

  @override
  String get saveChanges => 'Uložiť zmeny';

  @override
  String get noSavedQuotes => 'Žiadne uložené ponuky';

  @override
  String get oneSavedQuote => '1 uložená ponuka';

  @override
  String savedQuotesCount(int count) {
    return '$count uložených ponúk';
  }

  @override
  String get warehouses => 'Sklady';

  @override
  String get addWarehouse => 'Pridať sklad';

  @override
  String get warehouseName => 'Názov skladu';

  @override
  String get warehouseCode => 'Kód skladu';

  @override
  String get warehouseType => 'Typ skladu';

  @override
  String get warehouseTypePredaj => 'Predaj';

  @override
  String get warehouseTypeVyroba => 'Výroba';

  @override
  String get warehouseTypeRezijnyMaterial => 'Režijný materiál';

  @override
  String get warehouseTypeSklad => 'Sklad';

  @override
  String get noWarehouses => 'Žiadne sklady';

  @override
  String get searchHintWarehouses => 'Hľadať podľa názvu, kódu, mesta...';

  @override
  String get deleteWarehouse => 'Vymazať sklad?';

  @override
  String deleteWarehouseConfirm(String name) {
    return 'Naozaj chcete vymazať sklad \"$name\"?';
  }

  @override
  String get warehouseDeleted => 'Sklad bol vymazaný';

  @override
  String get editWarehouse => 'Upraviť sklad';

  @override
  String get addNewWarehouse => 'Pridať nový sklad';

  @override
  String get saveWarehouse => 'Uložiť sklad';

  @override
  String get warehouseSaved => 'Sklad bol uložený';

  @override
  String get warehouseUpdated => 'Sklad bol upravený';

  @override
  String get changePassword => 'Zmeniť heslo';

  @override
  String get changePasswordTitle => 'Zmena hesla';

  @override
  String get currentPassword => 'Súčasné heslo';

  @override
  String get newPassword => 'Nové heslo';

  @override
  String get confirmPassword => 'Potvrďte nové heslo';

  @override
  String get currentPasswordRequired => 'Zadajte súčasné heslo';

  @override
  String get newPasswordRequired => 'Zadajte nové heslo';

  @override
  String get confirmPasswordRequired => 'Potvrďte nové heslo';

  @override
  String get passwordsDoNotMatch => 'Heslá sa nezhodujú';

  @override
  String get passwordChanged => 'Heslo bolo úspešne zmenené';

  @override
  String get passwordChangeError => 'Chyba pri zmene hesla';

  @override
  String get invalidCurrentPassword => 'Nesprávne súčasné heslo';

  @override
  String get usernameRequired => 'Zadajte používateľské meno';

  @override
  String get category => 'Kategória';

  @override
  String get city => 'Mesto';

  @override
  String get clearDatabase => 'Vymazať dáta z databázy?';

  @override
  String get clearDatabaseConfirm =>
      'Naozaj chcete vymazať všetky dáta z databázy? Táto akcia je nevratná. Používatelia zostanú zachovaní.';

  @override
  String get clearDatabaseDone => 'Dáta z databázy boli vymazané.';

  @override
  String get adminOnly => 'Iba administrátor môže vymazať dáta z databázy.';

  @override
  String get margin => 'Marža';

  @override
  String get inventoryTitle => 'Inventúra';

  @override
  String get inventorySearchHint => 'Hľadať podľa názvu alebo kódu';

  @override
  String get actualStock => 'Skutočný stav';

  @override
  String get inSystemKs => 'V systéme:';

  @override
  String get saveInventory => 'Uložiť inventúru';

  @override
  String get inventorySaved => 'Inventúra bola uložená';

  @override
  String get exportReport => 'Exportovať report';

  @override
  String get exportFormat => 'Formát reportu';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatExcel => 'Excel';

  @override
  String get chooseWarehouse => 'Vyberte sklad';

  @override
  String get reportGenerated => 'Report bol vygenerovaný. Môžete ho zdieľať.';

  @override
  String get reportError => 'Chyba pri generovaní reportu';

  @override
  String get reportProduct => 'Produkt';

  @override
  String get reportQuantity => 'Počet';

  @override
  String get importFromExcel => 'Import z Excelu';

  @override
  String get bulkReceiptImport => 'Hromadný príjem';

  @override
  String get importPreview => 'Náhľad importu';

  @override
  String matchedRowsCount(int count) {
    return 'Zhodné s produktami: $count';
  }

  @override
  String unmatchedRowsCount(int count) {
    return 'Nezhodné riadky: $count';
  }

  @override
  String get createDraftReceipt => 'Vytvoriť rozpracovanú príjemku';

  @override
  String get importSuccess =>
      'Príjemka vytvorená. Môžete ju upraviť a schváliť.';

  @override
  String get selectExcelFile => 'Vyberte súbor Excel (.xlsx)';

  @override
  String get excelFormatHint =>
      'Stĺpce: PLU (alebo Kód), Množstvo, MJ, Cena. Prvý riadok môže byť hlavička.';

  @override
  String get noRowsMatched =>
      'Žiadny riadok sa nezhodoval s produktami v systéme.';

  @override
  String get importError => 'Chyba importu';
}
