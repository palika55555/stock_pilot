import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';
import 'app_localizations_sk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en'),
    Locale('sk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In sk, this message translates to:
  /// **'StockPilot'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In sk, this message translates to:
  /// **'Nastavenia'**
  String get settings;

  /// No description provided for @overview.
  ///
  /// In sk, this message translates to:
  /// **'Prehľad'**
  String get overview;

  /// No description provided for @scanProduct.
  ///
  /// In sk, this message translates to:
  /// **'Skenovať tovar'**
  String get scanProduct;

  /// No description provided for @warehouseSupplies.
  ///
  /// In sk, this message translates to:
  /// **'Skladové zásoby'**
  String get warehouseSupplies;

  /// No description provided for @goodsReceipt.
  ///
  /// In sk, this message translates to:
  /// **'Príjem tovaru'**
  String get goodsReceipt;

  /// No description provided for @warehouseMovements.
  ///
  /// In sk, this message translates to:
  /// **'Pohyby na sklade'**
  String get warehouseMovements;

  /// No description provided for @suppliers.
  ///
  /// In sk, this message translates to:
  /// **'Dodávatelia'**
  String get suppliers;

  /// No description provided for @logout.
  ///
  /// In sk, this message translates to:
  /// **'Odhlásiť sa'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In sk, this message translates to:
  /// **'Prihlásenie'**
  String get login;

  /// No description provided for @stockSystem.
  ///
  /// In sk, this message translates to:
  /// **'Skladový Systém'**
  String get stockSystem;

  /// No description provided for @loginSubtitle.
  ///
  /// In sk, this message translates to:
  /// **'Prihláste sa pre pokračovanie'**
  String get loginSubtitle;

  /// No description provided for @loginLabel.
  ///
  /// In sk, this message translates to:
  /// **'Login'**
  String get loginLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In sk, this message translates to:
  /// **'Heslo'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In sk, this message translates to:
  /// **'PRIHLÁSIŤ SA'**
  String get loginButton;

  /// No description provided for @loginError.
  ///
  /// In sk, this message translates to:
  /// **'Nesprávny login alebo heslo'**
  String get loginError;

  /// No description provided for @loginRequired.
  ///
  /// In sk, this message translates to:
  /// **'Zadajte login'**
  String get loginRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In sk, this message translates to:
  /// **'Heslo musí mať aspoň 4 znaky'**
  String get passwordMinLength;

  /// No description provided for @loggedInAs.
  ///
  /// In sk, this message translates to:
  /// **'Prihlásený ako {name}'**
  String loggedInAs(String name);

  /// No description provided for @roleChangedTo.
  ///
  /// In sk, this message translates to:
  /// **'Rola zmenená na {role}'**
  String roleChangedTo(String role);

  /// No description provided for @notifications.
  ///
  /// In sk, this message translates to:
  /// **'Notifikácie'**
  String get notifications;

  /// No description provided for @darkMode.
  ///
  /// In sk, this message translates to:
  /// **'Tmavý režim'**
  String get darkMode;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In sk, this message translates to:
  /// **'Použiť tmavú tému aplikácie'**
  String get darkModeSubtitle;

  /// No description provided for @language.
  ///
  /// In sk, this message translates to:
  /// **'Jazyk'**
  String get language;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In sk, this message translates to:
  /// **'Povoliť upozornenia a oznámenia'**
  String get notificationsSubtitle;

  /// No description provided for @application.
  ///
  /// In sk, this message translates to:
  /// **'Aplikácia'**
  String get application;

  /// No description provided for @database.
  ///
  /// In sk, this message translates to:
  /// **'Databáza'**
  String get database;

  /// No description provided for @databaseLocation.
  ///
  /// In sk, this message translates to:
  /// **'Umiestnenie databázy'**
  String get databaseLocation;

  /// No description provided for @defaultPath.
  ///
  /// In sk, this message translates to:
  /// **'Predvolené'**
  String get defaultPath;

  /// No description provided for @about.
  ///
  /// In sk, this message translates to:
  /// **'O aplikácii'**
  String get about;

  /// No description provided for @stockManagement.
  ///
  /// In sk, this message translates to:
  /// **'Skladový manažment'**
  String get stockManagement;

  /// No description provided for @close.
  ///
  /// In sk, this message translates to:
  /// **'Zavrieť'**
  String get close;

  /// No description provided for @unknown.
  ///
  /// In sk, this message translates to:
  /// **'Neznáme'**
  String get unknown;

  /// No description provided for @darkModeOn.
  ///
  /// In sk, this message translates to:
  /// **'Tmavý režim zapnutý'**
  String get darkModeOn;

  /// No description provided for @darkModeOff.
  ///
  /// In sk, this message translates to:
  /// **'Tmavý režim vypnutý'**
  String get darkModeOff;

  /// No description provided for @languageChanged.
  ///
  /// In sk, this message translates to:
  /// **'Jazyk zmenený na {lang}'**
  String languageChanged(String lang);

  /// No description provided for @languageSlovak.
  ///
  /// In sk, this message translates to:
  /// **'Slovenčina'**
  String get languageSlovak;

  /// No description provided for @languageCzech.
  ///
  /// In sk, this message translates to:
  /// **'Čeština'**
  String get languageCzech;

  /// No description provided for @languageEnglish.
  ///
  /// In sk, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @search.
  ///
  /// In sk, this message translates to:
  /// **'Hľadať'**
  String get search;

  /// No description provided for @addSupplier.
  ///
  /// In sk, this message translates to:
  /// **'Pridať dodávateľa'**
  String get addSupplier;

  /// No description provided for @add.
  ///
  /// In sk, this message translates to:
  /// **'Pridať'**
  String get add;

  /// No description provided for @active.
  ///
  /// In sk, this message translates to:
  /// **'Aktívny'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In sk, this message translates to:
  /// **'Neaktívny'**
  String get inactive;

  /// No description provided for @all.
  ///
  /// In sk, this message translates to:
  /// **'Všetci'**
  String get all;

  /// No description provided for @allActive.
  ///
  /// In sk, this message translates to:
  /// **'Aktívni'**
  String get allActive;

  /// No description provided for @allInactive.
  ///
  /// In sk, this message translates to:
  /// **'Neaktívni'**
  String get allInactive;

  /// No description provided for @noSuppliers.
  ///
  /// In sk, this message translates to:
  /// **'Žiadni dodávatelia'**
  String get noSuppliers;

  /// No description provided for @noResults.
  ///
  /// In sk, this message translates to:
  /// **'Žiadne výsledky'**
  String get noResults;

  /// No description provided for @searchHintSuppliers.
  ///
  /// In sk, this message translates to:
  /// **'Hľadať podľa názvu, IČO, mesta...'**
  String get searchHintSuppliers;

  /// No description provided for @deleteSupplier.
  ///
  /// In sk, this message translates to:
  /// **'Vymazať dodávateľa?'**
  String get deleteSupplier;

  /// No description provided for @deleteSupplierConfirm.
  ///
  /// In sk, this message translates to:
  /// **'Naozaj chcete vymazať dodávateľa \"{name}\"?'**
  String deleteSupplierConfirm(String name);

  /// No description provided for @cancel.
  ///
  /// In sk, this message translates to:
  /// **'Zrušiť'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In sk, this message translates to:
  /// **'Vymazať'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In sk, this message translates to:
  /// **'Upraviť'**
  String get edit;

  /// No description provided for @supplierDeleted.
  ///
  /// In sk, this message translates to:
  /// **'Dodávateľ bol vymazaný'**
  String get supplierDeleted;

  /// No description provided for @inbound.
  ///
  /// In sk, this message translates to:
  /// **'Príchod'**
  String get inbound;

  /// No description provided for @outbound.
  ///
  /// In sk, this message translates to:
  /// **'Výdaj'**
  String get outbound;

  /// No description provided for @detail.
  ///
  /// In sk, this message translates to:
  /// **'Detail'**
  String get detail;

  /// No description provided for @stockMovements.
  ///
  /// In sk, this message translates to:
  /// **'Pohyby zásob'**
  String get stockMovements;

  /// No description provided for @recentMovements.
  ///
  /// In sk, this message translates to:
  /// **'Posledné pohyby'**
  String get recentMovements;

  /// No description provided for @inboundReceipts.
  ///
  /// In sk, this message translates to:
  /// **'Príjemky'**
  String get inboundReceipts;

  /// No description provided for @inboundGoods.
  ///
  /// In sk, this message translates to:
  /// **'Príjem tovaru'**
  String get inboundGoods;

  /// No description provided for @outboundReceipts.
  ///
  /// In sk, this message translates to:
  /// **'Výdajky'**
  String get outboundReceipts;

  /// No description provided for @outboundGoods.
  ///
  /// In sk, this message translates to:
  /// **'Výdaj tovaru'**
  String get outboundGoods;

  /// No description provided for @customers.
  ///
  /// In sk, this message translates to:
  /// **'Zákazníci'**
  String get customers;

  /// No description provided for @addCustomer.
  ///
  /// In sk, this message translates to:
  /// **'Pridať zákazníka'**
  String get addCustomer;

  /// No description provided for @noCustomers.
  ///
  /// In sk, this message translates to:
  /// **'Žiadni zákazníci'**
  String get noCustomers;

  /// No description provided for @searchHintCustomers.
  ///
  /// In sk, this message translates to:
  /// **'Hľadať podľa názvu, IČO, mesta...'**
  String get searchHintCustomers;

  /// No description provided for @deleteCustomer.
  ///
  /// In sk, this message translates to:
  /// **'Vymazať zákazníka?'**
  String get deleteCustomer;

  /// No description provided for @deleteCustomerConfirm.
  ///
  /// In sk, this message translates to:
  /// **'Naozaj chcete vymazať zákazníka \"{name}\"?'**
  String deleteCustomerConfirm(String name);

  /// No description provided for @customerDeleted.
  ///
  /// In sk, this message translates to:
  /// **'Zákazník bol vymazaný'**
  String get customerDeleted;

  /// No description provided for @priceQuote.
  ///
  /// In sk, this message translates to:
  /// **'Cenová ponuka'**
  String get priceQuote;

  /// No description provided for @overviewNotesAndTasks.
  ///
  /// In sk, this message translates to:
  /// **'Poznámky a úlohy'**
  String get overviewNotesAndTasks;

  /// No description provided for @overviewNotesTitle.
  ///
  /// In sk, this message translates to:
  /// **'Poznámky'**
  String get overviewNotesTitle;

  /// No description provided for @overviewTasksTitle.
  ///
  /// In sk, this message translates to:
  /// **'Úlohy'**
  String get overviewTasksTitle;

  /// No description provided for @overviewNotesPlaceholder.
  ///
  /// In sk, this message translates to:
  /// **'Pridajte poznámku...'**
  String get overviewNotesPlaceholder;

  /// No description provided for @overviewNewTaskHint.
  ///
  /// In sk, this message translates to:
  /// **'Nová úloha...'**
  String get overviewNewTaskHint;

  /// No description provided for @overviewAddTask.
  ///
  /// In sk, this message translates to:
  /// **'Pridať úlohu'**
  String get overviewAddTask;

  /// No description provided for @quoteDetails.
  ///
  /// In sk, this message translates to:
  /// **'Údaje cenovej ponuky'**
  String get quoteDetails;

  /// No description provided for @quoteNumber.
  ///
  /// In sk, this message translates to:
  /// **'Číslo ponuky'**
  String get quoteNumber;

  /// No description provided for @validUntil.
  ///
  /// In sk, this message translates to:
  /// **'Platnosť do'**
  String get validUntil;

  /// No description provided for @notes.
  ///
  /// In sk, this message translates to:
  /// **'Poznámky'**
  String get notes;

  /// No description provided for @notesHint.
  ///
  /// In sk, this message translates to:
  /// **'Poznámka pre zákazníka (zobrazí sa na ponuke)'**
  String get notesHint;

  /// No description provided for @pricesIncludeVat.
  ///
  /// In sk, this message translates to:
  /// **'Ceny vrátane DPH'**
  String get pricesIncludeVat;

  /// No description provided for @quoteItems.
  ///
  /// In sk, this message translates to:
  /// **'Položky ponuky'**
  String get quoteItems;

  /// No description provided for @addItem.
  ///
  /// In sk, this message translates to:
  /// **'Pridať položku'**
  String get addItem;

  /// No description provided for @noQuoteItems.
  ///
  /// In sk, this message translates to:
  /// **'Žiadne položky. Pridajte produkty.'**
  String get noQuoteItems;

  /// No description provided for @subtotalWithoutVat.
  ///
  /// In sk, this message translates to:
  /// **'Medzisúčet bez DPH'**
  String get subtotalWithoutVat;

  /// No description provided for @totalWithVat.
  ///
  /// In sk, this message translates to:
  /// **'Spolu s DPH'**
  String get totalWithVat;

  /// No description provided for @saveQuote.
  ///
  /// In sk, this message translates to:
  /// **'Uložiť cenovú ponuku'**
  String get saveQuote;

  /// No description provided for @quoteSaved.
  ///
  /// In sk, this message translates to:
  /// **'Cenová ponuka bola uložená'**
  String get quoteSaved;

  /// No description provided for @quoteNumberRequired.
  ///
  /// In sk, this message translates to:
  /// **'Zadajte číslo ponuky'**
  String get quoteNumberRequired;

  /// No description provided for @offerFor.
  ///
  /// In sk, this message translates to:
  /// **'Ponuka pre:'**
  String get offerFor;

  /// No description provided for @dateOfIssue.
  ///
  /// In sk, this message translates to:
  /// **'Dátum vystavenia'**
  String get dateOfIssue;

  /// No description provided for @itemDescription.
  ///
  /// In sk, this message translates to:
  /// **'Popis položky'**
  String get itemDescription;

  /// No description provided for @quantity.
  ///
  /// In sk, this message translates to:
  /// **'Množstvo'**
  String get quantity;

  /// No description provided for @unitShort.
  ///
  /// In sk, this message translates to:
  /// **'MJ'**
  String get unitShort;

  /// No description provided for @pricePerUnit.
  ///
  /// In sk, this message translates to:
  /// **'Cena za MJ'**
  String get pricePerUnit;

  /// No description provided for @totalWithoutVatShort.
  ///
  /// In sk, this message translates to:
  /// **'Celkom bez DPH'**
  String get totalWithoutVatShort;

  /// No description provided for @vatShort.
  ///
  /// In sk, this message translates to:
  /// **'DPH'**
  String get vatShort;

  /// No description provided for @totalWithVatShort.
  ///
  /// In sk, this message translates to:
  /// **'Celkom s DPH'**
  String get totalWithVatShort;

  /// No description provided for @totalLabel.
  ///
  /// In sk, this message translates to:
  /// **'Spolu:'**
  String get totalLabel;

  /// No description provided for @vatPayer.
  ///
  /// In sk, this message translates to:
  /// **'Platiteľ DPH'**
  String get vatPayer;

  /// No description provided for @ourCompany.
  ///
  /// In sk, this message translates to:
  /// **'Naša firma'**
  String get ourCompany;

  /// No description provided for @editCompany.
  ///
  /// In sk, this message translates to:
  /// **'Upraviť údaje firmy'**
  String get editCompany;

  /// No description provided for @printPdf.
  ///
  /// In sk, this message translates to:
  /// **'Tlačiť / PDF'**
  String get printPdf;

  /// No description provided for @saveChanges.
  ///
  /// In sk, this message translates to:
  /// **'Uložiť zmeny'**
  String get saveChanges;

  /// No description provided for @noSavedQuotes.
  ///
  /// In sk, this message translates to:
  /// **'Žiadne uložené ponuky'**
  String get noSavedQuotes;

  /// No description provided for @oneSavedQuote.
  ///
  /// In sk, this message translates to:
  /// **'1 uložená ponuka'**
  String get oneSavedQuote;

  /// No description provided for @savedQuotesCount.
  ///
  /// In sk, this message translates to:
  /// **'{count} uložených ponúk'**
  String savedQuotesCount(int count);

  /// No description provided for @warehouses.
  ///
  /// In sk, this message translates to:
  /// **'Sklady'**
  String get warehouses;

  /// No description provided for @addWarehouse.
  ///
  /// In sk, this message translates to:
  /// **'Pridať sklad'**
  String get addWarehouse;

  /// No description provided for @warehouseName.
  ///
  /// In sk, this message translates to:
  /// **'Názov skladu'**
  String get warehouseName;

  /// No description provided for @warehouseCode.
  ///
  /// In sk, this message translates to:
  /// **'Kód skladu'**
  String get warehouseCode;

  /// No description provided for @warehouseType.
  ///
  /// In sk, this message translates to:
  /// **'Typ skladu'**
  String get warehouseType;

  /// No description provided for @warehouseTypePredaj.
  ///
  /// In sk, this message translates to:
  /// **'Predaj'**
  String get warehouseTypePredaj;

  /// No description provided for @warehouseTypeVyroba.
  ///
  /// In sk, this message translates to:
  /// **'Výroba'**
  String get warehouseTypeVyroba;

  /// No description provided for @warehouseTypeRezijnyMaterial.
  ///
  /// In sk, this message translates to:
  /// **'Režijný materiál'**
  String get warehouseTypeRezijnyMaterial;

  /// No description provided for @warehouseTypeSklad.
  ///
  /// In sk, this message translates to:
  /// **'Sklad'**
  String get warehouseTypeSklad;

  /// No description provided for @noWarehouses.
  ///
  /// In sk, this message translates to:
  /// **'Žiadne sklady'**
  String get noWarehouses;

  /// No description provided for @searchHintWarehouses.
  ///
  /// In sk, this message translates to:
  /// **'Hľadať podľa názvu, kódu, mesta...'**
  String get searchHintWarehouses;

  /// No description provided for @deleteWarehouse.
  ///
  /// In sk, this message translates to:
  /// **'Vymazať sklad?'**
  String get deleteWarehouse;

  /// No description provided for @deleteWarehouseConfirm.
  ///
  /// In sk, this message translates to:
  /// **'Naozaj chcete vymazať sklad \"{name}\"?'**
  String deleteWarehouseConfirm(String name);

  /// No description provided for @warehouseDeleted.
  ///
  /// In sk, this message translates to:
  /// **'Sklad bol vymazaný'**
  String get warehouseDeleted;

  /// No description provided for @editWarehouse.
  ///
  /// In sk, this message translates to:
  /// **'Upraviť sklad'**
  String get editWarehouse;

  /// No description provided for @addNewWarehouse.
  ///
  /// In sk, this message translates to:
  /// **'Pridať nový sklad'**
  String get addNewWarehouse;

  /// No description provided for @saveWarehouse.
  ///
  /// In sk, this message translates to:
  /// **'Uložiť sklad'**
  String get saveWarehouse;

  /// No description provided for @warehouseSaved.
  ///
  /// In sk, this message translates to:
  /// **'Sklad bol uložený'**
  String get warehouseSaved;

  /// No description provided for @warehouseUpdated.
  ///
  /// In sk, this message translates to:
  /// **'Sklad bol upravený'**
  String get warehouseUpdated;

  /// No description provided for @changePassword.
  ///
  /// In sk, this message translates to:
  /// **'Zmeniť heslo'**
  String get changePassword;

  /// No description provided for @changePasswordTitle.
  ///
  /// In sk, this message translates to:
  /// **'Zmena hesla'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In sk, this message translates to:
  /// **'Súčasné heslo'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In sk, this message translates to:
  /// **'Nové heslo'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In sk, this message translates to:
  /// **'Potvrďte nové heslo'**
  String get confirmPassword;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In sk, this message translates to:
  /// **'Zadajte súčasné heslo'**
  String get currentPasswordRequired;

  /// No description provided for @newPasswordRequired.
  ///
  /// In sk, this message translates to:
  /// **'Zadajte nové heslo'**
  String get newPasswordRequired;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In sk, this message translates to:
  /// **'Potvrďte nové heslo'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In sk, this message translates to:
  /// **'Heslá sa nezhodujú'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordChanged.
  ///
  /// In sk, this message translates to:
  /// **'Heslo bolo úspešne zmenené'**
  String get passwordChanged;

  /// No description provided for @passwordChangeError.
  ///
  /// In sk, this message translates to:
  /// **'Chyba pri zmene hesla'**
  String get passwordChangeError;

  /// No description provided for @invalidCurrentPassword.
  ///
  /// In sk, this message translates to:
  /// **'Nesprávne súčasné heslo'**
  String get invalidCurrentPassword;

  /// No description provided for @usernameRequired.
  ///
  /// In sk, this message translates to:
  /// **'Zadajte používateľské meno'**
  String get usernameRequired;

  /// No description provided for @category.
  ///
  /// In sk, this message translates to:
  /// **'Kategória'**
  String get category;

  /// No description provided for @city.
  ///
  /// In sk, this message translates to:
  /// **'Mesto'**
  String get city;

  /// No description provided for @clearDatabase.
  ///
  /// In sk, this message translates to:
  /// **'Vymazať dáta z databázy?'**
  String get clearDatabase;

  /// No description provided for @clearDatabaseConfirm.
  ///
  /// In sk, this message translates to:
  /// **'Naozaj chcete vymazať všetky dáta z databázy? Táto akcia je nevratná. Používatelia zostanú zachovaní.'**
  String get clearDatabaseConfirm;

  /// No description provided for @clearDatabaseDone.
  ///
  /// In sk, this message translates to:
  /// **'Dáta z databázy boli vymazané.'**
  String get clearDatabaseDone;

  /// No description provided for @backupDatabaseDownload.
  ///
  /// In sk, this message translates to:
  /// **'Záloha databázy – stiahnuť'**
  String get backupDatabaseDownload;

  /// No description provided for @backupDatabaseSuccess.
  ///
  /// In sk, this message translates to:
  /// **'Záloha bola uložená.'**
  String get backupDatabaseSuccess;

  /// No description provided for @backupDatabaseError.
  ///
  /// In sk, this message translates to:
  /// **'Záloha zlyhala.'**
  String get backupDatabaseError;

  /// No description provided for @backupDatabaseAction.
  ///
  /// In sk, this message translates to:
  /// **'Stiahnuť'**
  String get backupDatabaseAction;

  /// No description provided for @adminOnly.
  ///
  /// In sk, this message translates to:
  /// **'Iba administrátor môže vymazať dáta z databázy.'**
  String get adminOnly;

  /// No description provided for @margin.
  ///
  /// In sk, this message translates to:
  /// **'Marža'**
  String get margin;

  /// No description provided for @inventoryTitle.
  ///
  /// In sk, this message translates to:
  /// **'Inventúra'**
  String get inventoryTitle;

  /// No description provided for @inventorySearchHint.
  ///
  /// In sk, this message translates to:
  /// **'Hľadať podľa názvu alebo kódu'**
  String get inventorySearchHint;

  /// No description provided for @actualStock.
  ///
  /// In sk, this message translates to:
  /// **'Skutočný stav'**
  String get actualStock;

  /// No description provided for @inSystemKs.
  ///
  /// In sk, this message translates to:
  /// **'V systéme:'**
  String get inSystemKs;

  /// No description provided for @saveInventory.
  ///
  /// In sk, this message translates to:
  /// **'Uložiť inventúru'**
  String get saveInventory;

  /// No description provided for @inventorySaved.
  ///
  /// In sk, this message translates to:
  /// **'Inventúra bola uložená'**
  String get inventorySaved;

  /// No description provided for @exportReport.
  ///
  /// In sk, this message translates to:
  /// **'Exportovať report'**
  String get exportReport;

  /// No description provided for @exportFormat.
  ///
  /// In sk, this message translates to:
  /// **'Formát reportu'**
  String get exportFormat;

  /// No description provided for @formatPdf.
  ///
  /// In sk, this message translates to:
  /// **'PDF'**
  String get formatPdf;

  /// No description provided for @formatExcel.
  ///
  /// In sk, this message translates to:
  /// **'Excel'**
  String get formatExcel;

  /// No description provided for @chooseWarehouse.
  ///
  /// In sk, this message translates to:
  /// **'Vyberte sklad'**
  String get chooseWarehouse;

  /// No description provided for @warehouseFilterAll.
  ///
  /// In sk, this message translates to:
  /// **'Všetky sklady'**
  String get warehouseFilterAll;

  /// No description provided for @reportGenerated.
  ///
  /// In sk, this message translates to:
  /// **'Report bol vygenerovaný. Môžete ho zdieľať.'**
  String get reportGenerated;

  /// No description provided for @reportError.
  ///
  /// In sk, this message translates to:
  /// **'Chyba pri generovaní reportu'**
  String get reportError;

  /// No description provided for @reportProduct.
  ///
  /// In sk, this message translates to:
  /// **'Produkt'**
  String get reportProduct;

  /// No description provided for @reportQuantity.
  ///
  /// In sk, this message translates to:
  /// **'Počet'**
  String get reportQuantity;

  /// No description provided for @importFromExcel.
  ///
  /// In sk, this message translates to:
  /// **'Import z Excelu'**
  String get importFromExcel;

  /// No description provided for @bulkReceiptImport.
  ///
  /// In sk, this message translates to:
  /// **'Hromadný príjem'**
  String get bulkReceiptImport;

  /// No description provided for @importPreview.
  ///
  /// In sk, this message translates to:
  /// **'Náhľad importu'**
  String get importPreview;

  /// No description provided for @matchedRowsCount.
  ///
  /// In sk, this message translates to:
  /// **'Zhodné s produktami: {count}'**
  String matchedRowsCount(int count);

  /// No description provided for @unmatchedRowsCount.
  ///
  /// In sk, this message translates to:
  /// **'Nezhodné riadky: {count}'**
  String unmatchedRowsCount(int count);

  /// No description provided for @createDraftReceipt.
  ///
  /// In sk, this message translates to:
  /// **'Vytvoriť rozpracovanú príjemku'**
  String get createDraftReceipt;

  /// No description provided for @importSuccess.
  ///
  /// In sk, this message translates to:
  /// **'Príjemka vytvorená. Môžete ju upraviť a schváliť.'**
  String get importSuccess;

  /// No description provided for @selectExcelFile.
  ///
  /// In sk, this message translates to:
  /// **'Vyberte súbor Excel (.xlsx)'**
  String get selectExcelFile;

  /// No description provided for @excelFormatHint.
  ///
  /// In sk, this message translates to:
  /// **'Stĺpce: PLU (alebo Kód), Množstvo, MJ, Cena. Prvý riadok môže byť hlavička.'**
  String get excelFormatHint;

  /// No description provided for @noRowsMatched.
  ///
  /// In sk, this message translates to:
  /// **'Žiadny riadok sa nezhodoval s produktami v systéme.'**
  String get noRowsMatched;

  /// No description provided for @importError.
  ///
  /// In sk, this message translates to:
  /// **'Chyba importu'**
  String get importError;

  /// No description provided for @downloadImportTemplate.
  ///
  /// In sk, this message translates to:
  /// **'Stiahnuť šablónu importu'**
  String get downloadImportTemplate;

  /// No description provided for @downloadImportTemplateSuccess.
  ///
  /// In sk, this message translates to:
  /// **'Šablóna pripravená na uloženie alebo zdieľanie.'**
  String get downloadImportTemplateSuccess;

  /// No description provided for @importSummaryTitle.
  ///
  /// In sk, this message translates to:
  /// **'Kontrola a súhrn'**
  String get importSummaryTitle;

  /// No description provided for @importTotalRowsInFile.
  ///
  /// In sk, this message translates to:
  /// **'Riadkov v súbore: {count}'**
  String importTotalRowsInFile(int count);

  /// No description provided for @importSkippedRows.
  ///
  /// In sk, this message translates to:
  /// **'Riadkov vynechaných: {count}'**
  String importSkippedRows(int count);

  /// No description provided for @importTotalValue.
  ///
  /// In sk, this message translates to:
  /// **'Celková hodnota: {value}'**
  String importTotalValue(String value);

  /// No description provided for @importWarnings.
  ///
  /// In sk, this message translates to:
  /// **'Varovania'**
  String get importWarnings;

  /// No description provided for @importExistingProducts.
  ///
  /// In sk, this message translates to:
  /// **'Existujúce produkty'**
  String get importExistingProducts;

  /// No description provided for @importNewProducts.
  ///
  /// In sk, this message translates to:
  /// **'Nové produkty (budú vytvorené)'**
  String get importNewProducts;

  /// No description provided for @importFullTable.
  ///
  /// In sk, this message translates to:
  /// **'Kompletná tabuľka produktov'**
  String get importFullTable;

  /// No description provided for @importStatusExisting.
  ///
  /// In sk, this message translates to:
  /// **'Existujúci'**
  String get importStatusExisting;

  /// No description provided for @importStatusNew.
  ///
  /// In sk, this message translates to:
  /// **'Nový'**
  String get importStatusNew;

  /// No description provided for @importSupplierLabel.
  ///
  /// In sk, this message translates to:
  /// **'Dodávateľ pre príjemku'**
  String get importSupplierLabel;

  /// No description provided for @importWarehouseLabel.
  ///
  /// In sk, this message translates to:
  /// **'Sklad pre nové produkty'**
  String get importWarehouseLabel;

  /// No description provided for @importOptionalNone.
  ///
  /// In sk, this message translates to:
  /// **'— Nevybrať'**
  String get importOptionalNone;

  /// No description provided for @importPricePurchaseWithoutVat.
  ///
  /// In sk, this message translates to:
  /// **'Nákup bez DPH'**
  String get importPricePurchaseWithoutVat;

  /// No description provided for @importPricePurchaseWithVat.
  ///
  /// In sk, this message translates to:
  /// **'Nákup s DPH'**
  String get importPricePurchaseWithVat;

  /// No description provided for @importVatPurchase.
  ///
  /// In sk, this message translates to:
  /// **'DPH nákup %'**
  String get importVatPurchase;

  /// No description provided for @importPriceSaleWithoutVat.
  ///
  /// In sk, this message translates to:
  /// **'Predaj bez DPH'**
  String get importPriceSaleWithoutVat;

  /// No description provided for @importPriceSaleWithVat.
  ///
  /// In sk, this message translates to:
  /// **'Predaj s DPH'**
  String get importPriceSaleWithVat;

  /// No description provided for @importVatSale.
  ///
  /// In sk, this message translates to:
  /// **'DPH predaj %'**
  String get importVatSale;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In sk, this message translates to:
  /// **'Je dostupná nová verzia'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In sk, this message translates to:
  /// **'K dispozícii je verzia {version} (aktuálna: {current}).'**
  String updateAvailableBody(String version, String current);

  /// No description provided for @updateDownload.
  ///
  /// In sk, this message translates to:
  /// **'Stiahnuť'**
  String get updateDownload;

  /// No description provided for @updateLater.
  ///
  /// In sk, this message translates to:
  /// **'Neskôr'**
  String get updateLater;

  /// No description provided for @monthlyClosingsTitle.
  ///
  /// In sk, this message translates to:
  /// **'Mesačné uzávierky'**
  String get monthlyClosingsTitle;

  /// No description provided for @monthlyClosingsOpenScreen.
  ///
  /// In sk, this message translates to:
  /// **'Otvoriť'**
  String get monthlyClosingsOpenScreen;

  /// No description provided for @monthlyClosingsIntro.
  ///
  /// In sk, this message translates to:
  /// **'V uzavretom kalendárnom mesiaci nie je možné vytvárať ani upravovať príjemky, výdajky, presuny skladom, inventúru, faktúry, cenové ponuky ani súvisiace výrobné príkazy (podľa dátumu dokladu, dátumu výroby alebo dátumov na faktúre).'**
  String get monthlyClosingsIntro;

  /// No description provided for @monthlyClosingsEmpty.
  ///
  /// In sk, this message translates to:
  /// **'Žiadny uzavretý mesiac'**
  String get monthlyClosingsEmpty;

  /// No description provided for @monthlyClosingsCloseMonth.
  ///
  /// In sk, this message translates to:
  /// **'Uzavrieť mesiac'**
  String get monthlyClosingsCloseMonth;

  /// No description provided for @monthlyClosingsReopenMonth.
  ///
  /// In sk, this message translates to:
  /// **'Znovu otvoriť'**
  String get monthlyClosingsReopenMonth;

  /// No description provided for @monthlyClosingsClosedAt.
  ///
  /// In sk, this message translates to:
  /// **'Uzavreté'**
  String get monthlyClosingsClosedAt;

  /// No description provided for @monthlyClosingsBy.
  ///
  /// In sk, this message translates to:
  /// **'Kto'**
  String get monthlyClosingsBy;

  /// No description provided for @monthlyClosingsAdminOnly.
  ///
  /// In sk, this message translates to:
  /// **'Uzatváranie a otváranie mesiacov môže len administrátor.'**
  String get monthlyClosingsAdminOnly;

  /// No description provided for @monthlyClosingsPickMonth.
  ///
  /// In sk, this message translates to:
  /// **'Vyberte mesiac'**
  String get monthlyClosingsPickMonth;

  /// No description provided for @monthlyClosingsNoteOptional.
  ///
  /// In sk, this message translates to:
  /// **'Poznámka (voliteľné)'**
  String get monthlyClosingsNoteOptional;

  /// No description provided for @monthlyClosingsConfirmReopen.
  ///
  /// In sk, this message translates to:
  /// **'Znovu otvoriť mesiac {month}?'**
  String monthlyClosingsConfirmReopen(String month);

  /// No description provided for @monthlyClosingsAlreadyClosed.
  ///
  /// In sk, this message translates to:
  /// **'Tento mesiac je už uzavretý.'**
  String get monthlyClosingsAlreadyClosed;

  /// No description provided for @monthlyClosingsClosedSuccess.
  ///
  /// In sk, this message translates to:
  /// **'Mesiac bol uzavretý.'**
  String get monthlyClosingsClosedSuccess;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en', 'sk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
    case 'sk':
      return AppLocalizationsSk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
