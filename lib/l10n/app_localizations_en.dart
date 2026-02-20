// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StockPilot';

  @override
  String get settings => 'Settings';

  @override
  String get overview => 'Overview';

  @override
  String get scanProduct => 'Scan product';

  @override
  String get warehouseSupplies => 'Warehouse supplies';

  @override
  String get goodsReceipt => 'Goods receipt';

  @override
  String get warehouseMovements => 'Warehouse movements';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get logout => 'Log out';

  @override
  String get login => 'Login';

  @override
  String get stockSystem => 'Stock System';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get loginLabel => 'Login';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'SIGN IN';

  @override
  String get loginError => 'Invalid login or password';

  @override
  String get loginRequired => 'Enter login';

  @override
  String get passwordMinLength => 'Password must be at least 4 characters';

  @override
  String loggedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String roleChangedTo(String role) {
    return 'Role changed to $role';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get darkModeSubtitle => 'Use dark app theme';

  @override
  String get language => 'Language';

  @override
  String get notificationsSubtitle => 'Enable notifications and alerts';

  @override
  String get application => 'Application';

  @override
  String get database => 'Database';

  @override
  String get databaseLocation => 'Database location';

  @override
  String get defaultPath => 'Default';

  @override
  String get about => 'About';

  @override
  String get stockManagement => 'Stock management';

  @override
  String get close => 'Close';

  @override
  String get unknown => 'Unknown';

  @override
  String get darkModeOn => 'Dark mode on';

  @override
  String get darkModeOff => 'Dark mode off';

  @override
  String languageChanged(String lang) {
    return 'Language changed to $lang';
  }

  @override
  String get languageSlovak => 'Slovak';

  @override
  String get languageCzech => 'Czech';

  @override
  String get languageEnglish => 'English';

  @override
  String get search => 'Search';

  @override
  String get addSupplier => 'Add supplier';

  @override
  String get add => 'Add';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get all => 'All';

  @override
  String get allActive => 'Active';

  @override
  String get allInactive => 'Inactive';

  @override
  String get noSuppliers => 'No suppliers';

  @override
  String get noResults => 'No results';

  @override
  String get searchHintSuppliers => 'Search by name, ID, city...';

  @override
  String get deleteSupplier => 'Delete supplier?';

  @override
  String deleteSupplierConfirm(String name) {
    return 'Do you really want to delete supplier \"$name\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get supplierDeleted => 'Supplier was deleted';

  @override
  String get inbound => 'Inbound';

  @override
  String get outbound => 'Outbound';

  @override
  String get detail => 'Detail';

  @override
  String get stockMovements => 'Stock movements';

  @override
  String get recentMovements => 'Recent movements';

  @override
  String get inboundReceipts => 'Inbound receipts';

  @override
  String get inboundGoods => 'Goods receipt';

  @override
  String get outboundReceipts => 'Outbound';

  @override
  String get outboundGoods => 'Goods issue';

  @override
  String get customers => 'Customers';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get noCustomers => 'No customers';

  @override
  String get searchHintCustomers => 'Search by name, ID, city...';

  @override
  String get deleteCustomer => 'Delete customer?';

  @override
  String deleteCustomerConfirm(String name) {
    return 'Do you really want to delete customer \"$name\"?';
  }

  @override
  String get customerDeleted => 'Customer was deleted';

  @override
  String get priceQuote => 'Price quote';

  @override
  String get overviewNotesAndTasks => 'Notes and tasks';

  @override
  String get overviewNotesTitle => 'Notes';

  @override
  String get overviewTasksTitle => 'Tasks';

  @override
  String get overviewNotesPlaceholder => 'Add a note...';

  @override
  String get overviewNewTaskHint => 'New task...';

  @override
  String get overviewAddTask => 'Add task';

  @override
  String get quoteDetails => 'Quote details';

  @override
  String get quoteNumber => 'Quote number';

  @override
  String get validUntil => 'Valid until';

  @override
  String get notes => 'Notes';

  @override
  String get notesHint => 'Note for customer (shown on quote)';

  @override
  String get pricesIncludeVat => 'Prices include VAT';

  @override
  String get quoteItems => 'Quote items';

  @override
  String get addItem => 'Add item';

  @override
  String get noQuoteItems => 'No items. Add products.';

  @override
  String get subtotalWithoutVat => 'Subtotal without VAT';

  @override
  String get totalWithVat => 'Total with VAT';

  @override
  String get saveQuote => 'Save price quote';

  @override
  String get quoteSaved => 'Price quote was saved';

  @override
  String get quoteNumberRequired => 'Enter quote number';

  @override
  String get offerFor => 'Offer for:';

  @override
  String get dateOfIssue => 'Date of issue';

  @override
  String get itemDescription => 'Item description';

  @override
  String get quantity => 'Quantity';

  @override
  String get unitShort => 'Unit';

  @override
  String get pricePerUnit => 'Price per unit';

  @override
  String get totalWithoutVatShort => 'Total without VAT';

  @override
  String get vatShort => 'VAT';

  @override
  String get totalWithVatShort => 'Total with VAT';

  @override
  String get totalLabel => 'Total:';

  @override
  String get vatPayer => 'VAT payer';

  @override
  String get ourCompany => 'Our company';

  @override
  String get editCompany => 'Edit company details';

  @override
  String get printPdf => 'Print / PDF';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get noSavedQuotes => 'No saved quotes';

  @override
  String get oneSavedQuote => '1 saved quote';

  @override
  String savedQuotesCount(int count) {
    return '$count saved quotes';
  }

  @override
  String get warehouses => 'Warehouses';

  @override
  String get addWarehouse => 'Add warehouse';

  @override
  String get warehouseName => 'Warehouse name';

  @override
  String get warehouseCode => 'Warehouse code';

  @override
  String get warehouseType => 'Warehouse type';

  @override
  String get warehouseTypePredaj => 'Sales';

  @override
  String get warehouseTypeVyroba => 'Production';

  @override
  String get warehouseTypeRezijnyMaterial => 'Overhead material';

  @override
  String get warehouseTypeSklad => 'Warehouse';

  @override
  String get noWarehouses => 'No warehouses';

  @override
  String get searchHintWarehouses => 'Search by name, code, city...';

  @override
  String get deleteWarehouse => 'Delete warehouse?';

  @override
  String deleteWarehouseConfirm(String name) {
    return 'Are you sure you want to delete warehouse \"$name\"?';
  }

  @override
  String get warehouseDeleted => 'Warehouse was deleted';

  @override
  String get editWarehouse => 'Edit warehouse';

  @override
  String get addNewWarehouse => 'Add new warehouse';

  @override
  String get saveWarehouse => 'Save warehouse';

  @override
  String get warehouseSaved => 'Warehouse was saved';

  @override
  String get warehouseUpdated => 'Warehouse was updated';

  @override
  String get changePassword => 'Change password';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get currentPasswordRequired => 'Enter current password';

  @override
  String get newPasswordRequired => 'Enter new password';

  @override
  String get confirmPasswordRequired => 'Confirm new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordChanged => 'Password changed successfully';

  @override
  String get passwordChangeError => 'Error changing password';

  @override
  String get invalidCurrentPassword => 'Invalid current password';

  @override
  String get usernameRequired => 'Enter username';

  @override
  String get category => 'Category';

  @override
  String get city => 'City';

  @override
  String get clearDatabase => 'Clear database data?';

  @override
  String get clearDatabaseConfirm =>
      'Do you really want to delete all data from the database? This action cannot be undone. Users will be preserved.';

  @override
  String get clearDatabaseDone => 'Database data has been cleared.';

  @override
  String get adminOnly => 'Only administrator can clear database data.';

  @override
  String get margin => 'Margin';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventorySearchHint => 'Search by name or code';

  @override
  String get actualStock => 'Actual count';

  @override
  String get inSystemKs => 'In system:';

  @override
  String get saveInventory => 'Save inventory';

  @override
  String get inventorySaved => 'Inventory has been saved';

  @override
  String get exportReport => 'Export report';

  @override
  String get exportFormat => 'Report format';

  @override
  String get formatPdf => 'PDF';

  @override
  String get formatExcel => 'Excel';

  @override
  String get chooseWarehouse => 'Choose warehouse';

  @override
  String get reportGenerated => 'Report generated. You can share it.';

  @override
  String get reportError => 'Error generating report';

  @override
  String get reportProduct => 'Product';

  @override
  String get reportQuantity => 'Quantity';

  @override
  String get importFromExcel => 'Import from Excel';

  @override
  String get bulkReceiptImport => 'Bulk receipt import';

  @override
  String get importPreview => 'Import preview';

  @override
  String matchedRowsCount(int count) {
    return 'Matched with products: $count';
  }

  @override
  String unmatchedRowsCount(int count) {
    return 'Unmatched rows: $count';
  }

  @override
  String get createDraftReceipt => 'Create draft receipt';

  @override
  String get importSuccess => 'Receipt created. You can edit and approve it.';

  @override
  String get selectExcelFile => 'Select Excel file (.xlsx)';

  @override
  String get excelFormatHint =>
      'Columns: PLU (or Code), Quantity, Unit, Price. First row can be header.';

  @override
  String get noRowsMatched => 'No rows matched products in the system.';

  @override
  String get importError => 'Import error';
}
