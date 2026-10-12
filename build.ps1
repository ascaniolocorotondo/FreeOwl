<#
  Free Owl - build script
  Prende LibreWolf portable (ufficiale) e lo trasforma in Free Owl:
  nome, impostazioni, policy, logo. Nessuna compilazione.

  Uso:
    powershell -ExecutionPolicy Bypass -File build.ps1              # ultima versione di LibreWolf
    powershell -ExecutionPolicy Bypass -File build.ps1 -Version 157.0.1-1
#>
param(
  [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

$BrandName = "Free Owl"
$Root      = $PSScriptRoot
$Config    = Join-Path $Root "config"
$Assets    = Join-Path $Root "assets"
$Download  = Join-Path $Root "download"
$Dist      = Join-Path $Root "dist"
$Utf8      = New-Object System.Text.UTF8Encoding($false)

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# ---------------------------------------------------------------- 1. download
if (-not $Version) {
  Step "Cerco l'ultima versione di LibreWolf"
  $page = Invoke-WebRequest "https://librewolf.net/installation/windows/" -UseBasicParsing
  $link = $page.Links.href | Where-Object { $_ -match "windows-x86_64-portable\.zip$" } | Select-Object -First 1
  if (-not $link) { throw "Link al pacchetto portable non trovato su librewolf.net" }
  $Version = [regex]::Match($link, "librewolf/([^/]+)/").Groups[1].Value
}
Write-Host "    Versione LibreWolf: $Version"

$zipName = "librewolf-$Version-windows-x86_64-portable.zip"
$zipPath = Join-Path $Download $zipName
$baseUrl = "https://dl.librewolf.net/librewolf/$Version"
New-Item -ItemType Directory -Force $Download | Out-Null

if (-not (Test-Path $zipPath)) {
  Step "Scarico $zipName"
  Invoke-WebRequest "$baseUrl/$zipName" -OutFile $zipPath -UseBasicParsing
}

Step "Verifico il checksum SHA256"
$sums = (Invoke-WebRequest "$baseUrl/sha256sums.txt" -UseBasicParsing).Content
$expected = ($sums -split "`n" | Where-Object { $_ -match [regex]::Escape($zipName) }) -split "\s+" | Select-Object -First 1
$actual = (Get-FileHash $zipPath -Algorithm SHA256).Hash
if (-not $expected -or $actual -ne $expected.ToUpper()) {
  Remove-Item $zipPath -Force
  throw "Checksum NON valido per $zipName (atteso $expected, trovato $actual). File eliminato."
}

# ---------------------------------------------------------------- 2. estrazione
$out = Join-Path $Dist "FreeOwl"
Step "Estraggo in $out"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
$tmp = Join-Path $Dist "_tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive $zipPath -DestinationPath $tmp
Move-Item (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName $out
Remove-Item $tmp -Recurse -Force
$app = Join-Path $out "LibreWolf"

# L'updater di LibreWolf riscriverebbe Free Owl con LibreWolf: lo togliamo.
Remove-Item (Join-Path $out "LibreWolf-WinUpdater.exe"), (Join-Path $out "ScheduledTask-*.ps1") -Force -ErrorAction SilentlyContinue
Rename-Item (Join-Path $out "LibreWolf-Portable.exe") "FreeOwl.exe"

# ---------------------------------------------------------------- 3. nome dentro omni.ja
function Update-OmniJa([string]$path, [scriptblock]$shouldEdit) {
  $zip = [IO.Compression.ZipFile]::Open($path, [IO.Compression.ZipArchiveMode]::Update)
  $changed = 0
  try {
    $targets = @($zip.Entries | Where-Object { & $shouldEdit $_.FullName })
    foreach ($entry in $targets) {
      $reader = New-Object IO.StreamReader($entry.Open(), $Utf8)
      $text = $reader.ReadToEnd()
      $reader.Close()
      if ($text -cnotmatch "LibreWolf") { continue }
      $new = $text -creplace "LibreWolf", $BrandName
      $name = $entry.FullName
      $entry.Delete()
      $writer = New-Object IO.StreamWriter($zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal).Open(), $Utf8)
      $writer.Write($new)
      $writer.Close()
      $changed++
    }
  } finally {
    $zip.Dispose()
  }
  return $changed
}

function Replace-OmniJaFile([string]$path, [string]$entryName, [byte[]]$bytes) {
  $zip = [IO.Compression.ZipFile]::Open($path, [IO.Compression.ZipArchiveMode]::Update)
  try {
    $old = $zip.GetEntry($entryName)
    if (-not $old) { return }
    $old.Delete()
    $s = $zip.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal).Open()
    $s.Write($bytes, 0, $bytes.Length)
    $s.Close()
  } finally {
    $zip.Dispose()
  }
}

# Solo file di testo visibili all'utente (traduzioni), mai il codice.
$isLocaleText = {
  param($n)
  ($n -match "^localization/.+\.ftl$") -or ($n -match "^chrome/[^/]+/locale/.+\.(dtd|properties)$")
}

Step "Applico il nome '$BrandName' (browser/omni.ja)"
$n1 = Update-OmniJa (Join-Path $app "browser\omni.ja") $isLocaleText
Write-Host "    file modificati: $n1"
Step "Applico il nome '$BrandName' (omni.ja)"
$n2 = Update-OmniJa (Join-Path $app "omni.ja") $isLocaleText
Write-Host "    file modificati: $n2"

# ---------------------------------------------------------------- 4. logo (se presente)
$logo = Join-Path $Assets "logo.png"
if (Test-Path $logo) {
  Step "Applico il logo"
  $src = [Drawing.Image]::FromFile($logo)
  function Get-PngBytes([int]$size) {
    $bmp = New-Object Drawing.Bitmap($size, $size)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.Clear([Drawing.Color]::Transparent)
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return ,$ms.ToArray()
  }
  $omni = Join-Path $app "browser\omni.ja"
  $icons = @{
    "chrome/browser/content/branding/icon16.png" = 16
    "chrome/browser/content/branding/icon32.png" = 32
    "chrome/browser/content/branding/icon48.png" = 48
    "chrome/browser/content/branding/icon64.png" = 64
    "chrome/browser/content/branding/icon128.png" = 128
    "chrome/browser/content/branding/about.png" = 192
    "chrome/browser/content/branding/about-logo.png" = 192
    "chrome/browser/content/branding/about-logo@2x.png" = 384
    "chrome/browser/content/branding/about-logo-private.png" = 192
    "chrome/browser/content/branding/about-logo-private@2x.png" = 384
  }
  foreach ($k in $icons.Keys) { Replace-OmniJaFile $omni $k (Get-PngBytes $icons[$k]) }

  # Icona Windows (.ico con PNG dentro): finestra del browser + collegamento.
  $sizes = 16, 24, 32, 48, 64, 128, 256
  $images = $sizes | ForEach-Object { ,(Get-PngBytes $_) }
  $ms = New-Object IO.MemoryStream
  $bw = New-Object IO.BinaryWriter($ms)
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
  $offset = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$images[$i].Length); $bw.Write([uint32]$offset)
    $offset += $images[$i].Length
  }
  foreach ($img in $images) { $bw.Write($img) }
  $bw.Flush()
  $icoBytes = $ms.ToArray()
  $src.Dispose()

  [IO.File]::WriteAllBytes((Join-Path $out "FreeOwl.ico"), $icoBytes)
  $winIcons = Join-Path $app "browser\chrome\icons\default"
  New-Item -ItemType Directory -Force $winIcons | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $winIcons "main-window.ico"), $icoBytes)
  [IO.File]::WriteAllBytes((Join-Path $app "librewolf.ico"), $icoBytes)

  # Icona e nome dentro i .exe (barra delle applicazioni, Esplora file, Gestione attivita').
  $rcedit = Join-Path $Root "tools\rcedit-x64.exe"
  $rceditSha = "3E7801DB1A5EDBEC91B49A24A094AAD776CB4515488EA5A4CA2289C400EADE2A"
  if (-not (Test-Path $rcedit)) {
    Step "Scarico rcedit (cambia l'icona dei .exe)"
    New-Item -ItemType Directory -Force (Split-Path $rcedit) | Out-Null
    Invoke-WebRequest "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe" -OutFile $rcedit -UseBasicParsing
  }
  if ((Get-FileHash $rcedit -Algorithm SHA256).Hash -ne $rceditSha) {
    Remove-Item $rcedit -Force
    throw "rcedit-x64.exe non corrisponde all'impronta attesa: eliminato."
  }
  if (Test-Path $rcedit) {
    $ico = Join-Path $out "FreeOwl.ico"
    foreach ($exe in (Join-Path $out "FreeOwl.exe"), (Join-Path $app "librewolf.exe"), (Join-Path $app "private_browsing.exe")) {
      & $rcedit $exe --set-icon $ico --set-version-string FileDescription $BrandName --set-version-string ProductName $BrandName
      if ($LASTEXITCODE -ne 0) { throw "rcedit non riuscito su $exe" }
    }
  } else {
    Write-Host "    (manca tools\rcedit-x64.exe: i .exe restano con l'icona di LibreWolf)" -ForegroundColor Yellow
  }
} else {
  Write-Host "    (nessun assets\logo.png: resta il logo di LibreWolf per ora)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 5. impostazioni
Step "Aggiungo le impostazioni Free Owl a librewolf.cfg"
$cfg = Join-Path $app "librewolf.cfg"
$extra = [IO.File]::ReadAllText((Join-Path $Config "freeowl.cfg"), $Utf8)
[IO.File]::AppendAllText($cfg, "`n" + $extra, $Utf8)
Step "Includo l'estensione Free Owl"
$extDir = Join-Path $app "distribution\extensions"
New-Item -ItemType Directory -Force $extDir | Out-Null
$xpi = Join-Path $extDir "freeowl@freeowl.local.xpi"
$xpiZip = [IO.Compression.ZipFile]::Open($xpi, [IO.Compression.ZipArchiveMode]::Create)
try {
  $extSrc = Join-Path $Root "extension"
  Get-ChildItem $extSrc -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($extSrc.Length + 1).Replace("\", "/")
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($xpiZip, $_.FullName, $rel) | Out-Null
  }
} finally {
  $xpiZip.Dispose()
}

Step "Unisco le policy"
function Merge-Object($base, $over) {
  foreach ($p in $over.PSObject.Properties) {
    $b = $base.PSObject.Properties[$p.Name]
    if ($b -and $b.Value -is [pscustomobject] -and $p.Value -is [pscustomobject]) {
      Merge-Object $b.Value $p.Value
    } else {
      $base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    }
  }
}
$polPath = Join-Path $app "distribution\policies.json"
$pol = [IO.File]::ReadAllText($polPath, $Utf8) | ConvertFrom-Json
$mine = [IO.File]::ReadAllText((Join-Path $Config "policies.json"), $Utf8) | ConvertFrom-Json
Merge-Object $pol.policies $mine.policies
$pol.policies.SupportMenu.Title = "Supporto $BrandName"
[IO.File]::WriteAllText($polPath, ($pol | ConvertTo-Json -Depth 32), $Utf8)

# ---------------------------------------------------------------- 6. pacchetto finale
$final = Join-Path $Dist "FreeOwl-$Version-windows-x86_64-portable.zip"
Step "Creo $final"
if (Test-Path $final) { Remove-Item $final -Force }
[IO.Compression.ZipFile]::CreateFromDirectory($out, $final, [IO.Compression.CompressionLevel]::Optimal, $true)

if (Test-Path (Join-Path $out "FreeOwl.ico")) {
  Step "Creo il collegamento 'Free Owl' con il logo"
  $wsh = New-Object -ComObject WScript.Shell
  $lnk = $wsh.CreateShortcut((Join-Path $out "Free Owl.lnk"))
  $lnk.TargetPath = Join-Path $out "FreeOwl.exe"
  $lnk.WorkingDirectory = $out
  $lnk.IconLocation = (Join-Path $out "FreeOwl.ico") + ",0"
  $lnk.Description = $BrandName
  $lnk.Save()
}

Write-Host ""
Write-Host "Fatto! Free Owl ($Version) e' in:" -ForegroundColor Green
Write-Host "  cartella: $out"
Write-Host "  zip:      $final"
Write-Host "  avvio:    $out\FreeOwl.exe"
