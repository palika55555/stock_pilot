import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Čítanie Microsoft Access (.mdb / .accdb) na Windows cez PowerShell + System.Data.OleDb.
/// Vyžaduje nainštalovaný [Microsoft Access Database Engine](https://www.microsoft.com/en-us/download/details.aspx?id=54920)
/// (64-bit, ak je aplikácia 64-bit).
class AccessMdbWindows {
  AccessMdbWindows._();

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  static Future<List<String>> listTables(String mdbPath) async {
    final r = await _run(mdbPath, 'tables');
    if (r.exitCode != 0) {
      throw FormatException(_formatPsError(r));
    }
    return r.stdout
        .toString()
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<List<String>> listColumns(String mdbPath, String tableName) async {
    final r = await _run(mdbPath, 'columns', tableName: tableName);
    if (r.exitCode != 0) {
      throw FormatException(_formatPsError(r));
    }
    return r.stdout
        .toString()
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Exportuje tabuľku do dočasného UTF-8 CSV. Volajúci má súbor zmazať po použití.
  static Future<String> exportTableToCsv(String mdbPath, String tableName) async {
    final tmp = await getTemporaryDirectory();
    final csvPath = p.join(
      tmp.path,
      'stock_pilot_mdb_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    final r = await _run(mdbPath, 'export', tableName: tableName, outCsv: csvPath);
    if (r.exitCode != 0) {
      throw FormatException(_formatPsError(r));
    }
    final f = File(csvPath);
    if (!await f.exists()) {
      throw FormatException('Export CSV sa nepodarilo vytvoriť.');
    }
    return csvPath;
  }

  static Future<ProcessResult> _run(
    String mdbPath,
    String mode, {
    String? tableName,
    String? outCsv,
  }) async {
    if (!isSupported) {
      throw StateError('Access MDB je podporovaný len na Windows.');
    }
    final scriptFile = File(
      p.join(
        (await getTemporaryDirectory()).path,
        'stock_pilot_access_${DateTime.now().millisecondsSinceEpoch}.ps1',
      ),
    );
    await scriptFile.writeAsString(_embeddedPs1, encoding: utf8);
    try {
      final args = <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-MdbPath',
        mdbPath,
        '-Mode',
        mode,
      ];
      if (tableName != null) {
        args.addAll(['-TableName', tableName]);
      }
      if (outCsv != null) {
        args.addAll(['-OutCsv', outCsv]);
      }
      // Musí byť await: bez neho sa `finally` spustí hneď a zmaže .ps1 skôr,
      // než PowerShell stihne načítať -File (chyba „does not exist“).
      return await Process.run(
        'powershell.exe',
        args,
        runInShell: false,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } finally {
      try {
        if (await scriptFile.exists()) await scriptFile.delete();
      } catch (_) {}
    }
  }

  static String _formatPsError(ProcessResult r) {
    final err = r.stderr.toString().trim();
    final out = r.stdout.toString().trim();
    final combined = err.isNotEmpty ? err : out;
    final lower = combined.toLowerCase();
    if (lower.contains('ace') ||
        lower.contains('jet') ||
        lower.contains('ole db') ||
        lower.contains('provider') ||
        lower.contains('registered')) {
      return 'Nepodarilo sa otvoriť .mdb/.accdb. Nainštalujte „Microsoft Access Database Engine“ '
          '(64-bit, ak je StockPilot 64-bit) z webu Microsoft. Pôvodná chyba: $combined';
    }
    return combined.isNotEmpty ? combined : 'PowerShell skončil s kódom ${r.exitCode}.';
  }

  /// Skript: tabuľky / stĺpce / export CSV cez OleDb + ACE alebo Jet.
  static const String _embeddedPs1 = r'''
param(
  [Parameter(Mandatory=$true)][string]$MdbPath,
  [Parameter(Mandatory=$true)][ValidateSet('tables','columns','export')][string]$Mode,
  [string]$TableName = '',
  [string]$OutCsv = ''
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Open-AccessConnection {
  param([string]$p)
  $candidates = @(
    "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$p`";",
    "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=`"$p`";"
  )
  foreach ($c in $candidates) {
    try {
      $conn = New-Object System.Data.OleDb.OleDbConnection $c
      $conn.Open()
      return $conn
    } catch {
      continue
    }
  }
  throw "Cannot open database. Install Microsoft Access Database Engine 64-bit. Last error: $($_.Exception.Message)"
}

$conn = Open-AccessConnection $MdbPath

try {
  switch ($Mode) {
    'tables' {
      $dt = $null
      try {
        $dt = $conn.GetSchema("Tables")
      } catch {
        $dt = $conn.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables, $null)
      }
      foreach ($row in $dt.Rows) {
        $t = $row["TABLE_NAME"].ToString()
        $type = "TABLE"
        try { $type = $row["TABLE_TYPE"].ToString() } catch { }
        if ($type -eq "TABLE" -and $t -notlike "MSys*" -and $t -notlike "~*") {
          [Console]::WriteLine($t)
        }
      }
    }
    'columns' {
      if ([string]::IsNullOrWhiteSpace($TableName)) { throw "TableName is required for columns" }
      # GetSchema("Columns", restrictions) s $null často hodí OleDbException „The parameter is incorrect“.
      # Načítame všetky stĺpce a vyfiltrujeme podľa TABLE_NAME (bez ohľadu na veľkosť písmen).
      $dt = $conn.GetSchema("Columns")
      foreach ($row in $dt.Rows) {
        $tn = $row["TABLE_NAME"].ToString()
        if ([string]::Compare($tn, $TableName, $true) -eq 0) {
          [Console]::WriteLine($row["COLUMN_NAME"].ToString())
        }
      }
    }
    'export' {
      if ([string]::IsNullOrWhiteSpace($TableName) -or [string]::IsNullOrWhiteSpace($OutCsv)) {
        throw "TableName and OutCsv are required for export"
      }
      $safe = $TableName.Replace(']', ']]')
      $sql = "SELECT * FROM [$safe]"
      $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $sql, $conn
      $ds = New-Object System.Data.DataSet
      $null = $adapter.Fill($ds)
      if ($ds.Tables.Count -eq 0) { throw "No result set" }
      $ds.Tables[0] | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
    }
  }
}
finally {
  if ($null -ne $conn) { $conn.Close() }
}
''';
}
