# ============================================================
# export_pohoda.ps1
# Číta tabuľku SkladoveKarty00001 z Pohoda MDB súboru
# a exportuje produkty do pohoda_products.json
# ============================================================

$MdbPath = "C:\Users\pavol\Desktop\stock_pilot\stock_pilot\ProBlock_s_r_o.mdb"
$OutputPath = "$PSScriptRoot\pohoda_products.json"
$TableName = "SkladoveKarty00001"

Write-Host "=== Pohoda MDB Export ===" -ForegroundColor Cyan
Write-Host "Súbor: $MdbPath"
Write-Host "Tabuľka: $TableName"
Write-Host ""

if (-not (Test-Path $MdbPath)) {
    Write-Error "MDB súbor neexistuje: $MdbPath"
    exit 1
}

# Skúsiť Microsoft ACE OLEDB 12.0 (Access 2010+), potom Jet 4.0 (starší)
$providers = @(
    "Provider=Microsoft.ACE.OLEDB.12.0;",
    "Provider=Microsoft.Jet.OLEDB.4.0;"
)

$conn = $null
foreach ($prov in $providers) {
    try {
        $conn = New-Object -ComObject ADODB.Connection
        $connStr = "${prov}Data Source=$MdbPath;Mode=Read;"
        $conn.Open($connStr)
        Write-Host "Pripojenie OK cez: $prov" -ForegroundColor Green
        break
    } catch {
        Write-Host "Provider zlyhal: $prov - $($_.Exception.Message)" -ForegroundColor Yellow
        $conn = $null
    }
}

if ($null -eq $conn) {
    Write-Error "Nepodarilo sa pripojiť k MDB súboru. Nainštaluj Microsoft Access Database Engine:"
    Write-Error "https://www.microsoft.com/en-us/download/details.aspx?id=54920"
    exit 1
}

Write-Host "Načítavam záznamy z $TableName ..." -ForegroundColor Cyan

$rs = New-Object -ComObject ADODB.Recordset
try {
    $rs.Open("SELECT * FROM [$TableName]", $conn, 3, 1)  # adOpenStatic, adLockReadOnly
} catch {
    Write-Error "Chyba pri otváraní tabuľky: $($_.Exception.Message)"
    $conn.Close()
    exit 1
}

# Načítaj názvy stĺpcov
$cols = @()
for ($i = 0; $i -lt $rs.Fields.Count; $i++) {
    $cols += $rs.Fields.Item($i).Name
}
Write-Host "Stĺpce ($($cols.Count)): $($cols -join ', ')" -ForegroundColor Gray
Write-Host ""

$products = @()
$count = 0

$rs.MoveFirst()
while (-not $rs.EOF) {
    $row = @{}
    foreach ($col in $cols) {
        $val = $rs.Fields.Item($col).Value
        # Konverzia COM typov
        if ($null -eq $val -or $val -is [System.DBNull] -or ($val -is [string] -and $val -eq "")) {
            $row[$col] = $null
        } elseif ($val -is [decimal] -or $val -is [double] -or $val -is [float]) {
            $row[$col] = [double]$val
        } elseif ($val -is [int] -or $val -is [long] -or $val -is [int16] -or $val -is [int32] -or $val -is [int64]) {
            $row[$col] = [long]$val
        } elseif ($val -is [bool]) {
            $row[$col] = [bool]$val
        } elseif ($val -is [DateTime]) {
            $row[$col] = $val.ToString("yyyy-MM-dd")
        } else {
            $row[$col] = [string]$val
        }
    }
    $products += $row
    $count++
    if ($count % 100 -eq 0) {
        Write-Host "  Spracované: $count záznamy..." -ForegroundColor Gray
    }
    $rs.MoveNext()
}

$rs.Close()
$conn.Close()

Write-Host ""
Write-Host "Celkovo načítaných: $count produktov" -ForegroundColor Green

# Export do JSON
$json = $products | ConvertTo-Json -Depth 3 -Compress:$false
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.Encoding]::UTF8)

Write-Host "Exportované do: $OutputPath" -ForegroundColor Green
Write-Host "Hotovo!" -ForegroundColor Cyan
