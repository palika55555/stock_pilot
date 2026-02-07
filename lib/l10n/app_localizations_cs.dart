// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'StockPilot';

  @override
  String get settings => 'Nastavení';

  @override
  String get overview => 'Přehled';

  @override
  String get scanProduct => 'Skenovat zboží';

  @override
  String get warehouseSupplies => 'Skladové zásoby';

  @override
  String get goodsReceipt => 'Příjem zboží';

  @override
  String get warehouseMovements => 'Pohyby na skladu';

  @override
  String get suppliers => 'Dodavatelé';

  @override
  String get logout => 'Odhlásit se';

  @override
  String get login => 'Přihlášení';

  @override
  String get stockSystem => 'Skladový systém';

  @override
  String get loginSubtitle => 'Přihlaste se pro pokračování';

  @override
  String get loginLabel => 'Login';

  @override
  String get passwordLabel => 'Heslo';

  @override
  String get loginButton => 'PŘIHLÁSIT SE';

  @override
  String get loginError => 'Nesprávný login nebo heslo';

  @override
  String get loginRequired => 'Zadejte login';

  @override
  String get passwordMinLength => 'Heslo musí mít alespoň 4 znaky';

  @override
  String loggedInAs(String name) {
    return 'Přihlášen jako $name';
  }

  @override
  String roleChangedTo(String role) {
    return 'Role změněna na $role';
  }

  @override
  String get notifications => 'Oznámení';

  @override
  String get darkMode => 'Tmavý režim';

  @override
  String get darkModeSubtitle => 'Použít tmavé téma aplikace';

  @override
  String get language => 'Jazyk';

  @override
  String get notificationsSubtitle => 'Povolit upozornění a oznámení';

  @override
  String get application => 'Aplikace';

  @override
  String get database => 'Databáze';

  @override
  String get databaseLocation => 'Umístění databáze';

  @override
  String get defaultPath => 'Výchozí';

  @override
  String get about => 'O aplikaci';

  @override
  String get stockManagement => 'Skladové řízení';

  @override
  String get close => 'Zavřít';

  @override
  String get unknown => 'Neznámé';

  @override
  String get darkModeOn => 'Tmavý režim zapnut';

  @override
  String get darkModeOff => 'Tmavý režim vypnut';

  @override
  String languageChanged(String lang) {
    return 'Jazyk změněn na $lang';
  }

  @override
  String get languageSlovak => 'Slovenština';

  @override
  String get languageCzech => 'Čeština';

  @override
  String get languageEnglish => 'Angličtina';

  @override
  String get search => 'Hledat';

  @override
  String get addSupplier => 'Přidat dodavatele';

  @override
  String get add => 'Přidat';

  @override
  String get active => 'Aktivní';

  @override
  String get inactive => 'Neaktivní';

  @override
  String get all => 'Všichni';

  @override
  String get allActive => 'Aktivní';

  @override
  String get allInactive => 'Neaktivní';

  @override
  String get noSuppliers => 'Žádní dodavatelé';

  @override
  String get noResults => 'Žádné výsledky';

  @override
  String get searchHintSuppliers => 'Hledat podle názvu, IČO, města...';

  @override
  String get deleteSupplier => 'Smazat dodavatele?';

  @override
  String deleteSupplierConfirm(String name) {
    return 'Opravdu chcete smazat dodavatele \"$name\"?';
  }

  @override
  String get cancel => 'Zrušit';

  @override
  String get delete => 'Smazat';

  @override
  String get edit => 'Upravit';

  @override
  String get supplierDeleted => 'Dodavatel byl smazán';

  @override
  String get inbound => 'Příjem';

  @override
  String get outbound => 'Výdej';

  @override
  String get detail => 'Detail';

  @override
  String get stockMovements => 'Pohyby zásob';

  @override
  String get inboundReceipts => 'Příjemky';

  @override
  String get inboundGoods => 'Příjem zboží';

  @override
  String get outboundReceipts => 'Výdejky';

  @override
  String get outboundGoods => 'Výdej zboží';

  @override
  String get customers => 'Zákazníci';

  @override
  String get addCustomer => 'Přidat zákazníka';

  @override
  String get noCustomers => 'Žádní zákazníci';

  @override
  String get searchHintCustomers => 'Hledat podle názvu, IČO, města...';

  @override
  String get deleteCustomer => 'Smazat zákazníka?';

  @override
  String deleteCustomerConfirm(String name) {
    return 'Opravdu chcete smazat zákazníka \"$name\"?';
  }

  @override
  String get customerDeleted => 'Zákazník byl smazán';

  @override
  String get priceQuote => 'Cenová nabídka';

  @override
  String get quoteDetails => 'Údaje cenové nabídky';

  @override
  String get quoteNumber => 'Číslo nabídky';

  @override
  String get validUntil => 'Platnost do';

  @override
  String get notes => 'Poznámky';

  @override
  String get notesHint => 'Poznámka pro zákazníka (zobrazí se na nabídce)';

  @override
  String get pricesIncludeVat => 'Ceny včetně DPH';

  @override
  String get quoteItems => 'Položky nabídky';

  @override
  String get addItem => 'Přidat položku';

  @override
  String get noQuoteItems => 'Žádné položky. Přidejte produkty.';

  @override
  String get subtotalWithoutVat => 'Mezisoučet bez DPH';

  @override
  String get totalWithVat => 'Celkem s DPH';

  @override
  String get saveQuote => 'Uložit cenovou nabídku';

  @override
  String get quoteSaved => 'Cenová nabídka byla uložena';

  @override
  String get quoteNumberRequired => 'Zadejte číslo nabídky';

  @override
  String get offerFor => 'Nabídka pro:';

  @override
  String get dateOfIssue => 'Datum vystavení';

  @override
  String get itemDescription => 'Popis položky';

  @override
  String get quantity => 'Množství';

  @override
  String get unitShort => 'MJ';

  @override
  String get pricePerUnit => 'Cena za MJ';

  @override
  String get totalWithoutVatShort => 'Celkem bez DPH';

  @override
  String get vatShort => 'DPH';

  @override
  String get totalWithVatShort => 'Celkem s DPH';

  @override
  String get totalLabel => 'Spolu:';

  @override
  String get vatPayer => 'Plátce DPH';

  @override
  String get ourCompany => 'Naše firma';

  @override
  String get editCompany => 'Upravit údaje firmy';

  @override
  String get printPdf => 'Tisk / PDF';

  @override
  String get saveChanges => 'Uložit změny';

  @override
  String get noSavedQuotes => 'Žádné uložené nabídky';

  @override
  String get oneSavedQuote => '1 uložená nabídka';

  @override
  String savedQuotesCount(int count) {
    return '$count uložených nabídek';
  }

  @override
  String get warehouses => 'Sklady';

  @override
  String get addWarehouse => 'Přidat sklad';

  @override
  String get warehouseName => 'Název skladu';

  @override
  String get warehouseCode => 'Kód skladu';

  @override
  String get noWarehouses => 'Žádné sklady';

  @override
  String get searchHintWarehouses => 'Hledat podle názvu, kódu, města...';

  @override
  String get deleteWarehouse => 'Smazat sklad?';

  @override
  String deleteWarehouseConfirm(String name) {
    return 'Opravdu chcete smazat sklad \"$name\"?';
  }

  @override
  String get warehouseDeleted => 'Sklad byl smazán';

  @override
  String get editWarehouse => 'Upravit sklad';

  @override
  String get addNewWarehouse => 'Přidat nový sklad';

  @override
  String get saveWarehouse => 'Uložit sklad';

  @override
  String get warehouseSaved => 'Sklad byl uložen';

  @override
  String get warehouseUpdated => 'Sklad byl upraven';

  @override
  String get changePassword => 'Změnit heslo';

  @override
  String get changePasswordTitle => 'Změna hesla';

  @override
  String get currentPassword => 'Současné heslo';

  @override
  String get newPassword => 'Nové heslo';

  @override
  String get confirmPassword => 'Potvrďte nové heslo';

  @override
  String get currentPasswordRequired => 'Zadejte současné heslo';

  @override
  String get newPasswordRequired => 'Zadejte nové heslo';

  @override
  String get confirmPasswordRequired => 'Potvrďte nové heslo';

  @override
  String get passwordsDoNotMatch => 'Hesla se neshodují';

  @override
  String get passwordChanged => 'Heslo bylo úspěšně změněno';

  @override
  String get passwordChangeError => 'Chyba při změně hesla';

  @override
  String get invalidCurrentPassword => 'Nesprávné současné heslo';

  @override
  String get usernameRequired => 'Zadejte uživatelské jméno';

  @override
  String get category => 'Kategorie';

  @override
  String get city => 'Město';
}
