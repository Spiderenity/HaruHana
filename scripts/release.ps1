param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$WindowsTemplate
)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path $project -Parent
$version = [regex]::Match((Get-Content (Join-Path $project 'project.godot') -Raw), 'config/version="([^"]+)"').Groups[1].Value
if (!$version) { throw 'Missing project version' }
if (!((& $Godot --version | Out-String).Trim().StartsWith('4.6.3.stable'))) { throw 'Godot 4.6.3 is required' }
if (Test-Path (Join-Path $project 'characters/patch_regression_fixture')) { throw 'Remove the test fixture before export' }
$output = Join-Path $workspace ('releases/' + $version)
if (Test-Path -LiteralPath $output) { throw "Release already exists: $output" }
$stage = Join-Path $output 'HaruHana-Windows-x86_64'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$originalAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $workspace ('work/validation/export-' + [guid]::NewGuid().ToString('N'))
    $templates = Join-Path $env:APPDATA 'Godot/export_templates/4.6.3.stable'
    New-Item -ItemType Directory -Path $templates -Force | Out-Null
    Copy-Item -LiteralPath $WindowsTemplate -Destination (Join-Path $templates 'windows_release_x86_64.exe')
    $exports = @(@('Windows Desktop', '하루하나.exe'), @('Character Creator', '캐릭터 크리에이터.exe'), @('Bubble Creator', '말풍선 크리에이터.exe'))
    foreach ($export in $exports) {
        $log = Join-Path $output ('export-' + $export[0].Replace(' ', '-') + '.log')
        & $Godot --headless --path $project --export-release $export[0] (Join-Path $stage $export[1]) *> $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Export failed' -Quiet)) { throw "Export failed: $log" }
        Write-Output "Exported $($export[1])"
    }
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    & $compiler /nologo /optimize+ /target:winexe "/out:$(Join-Path $stage 'HaruHanaUpdater.exe')" /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll (Join-Path $project 'system/services/update/native/HaruHanaUpdater.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Updater compilation failed' }
    Copy-Item -LiteralPath (Join-Path $project 'system/addons/windows_mouse_passthrough/bin/mouse_passthrough.windows.template_release.x86_64.dll') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $project 'manual/사용 설명서.html') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $project 'docs/PATCH-0.1.12.txt') -Destination (Join-Path $stage '패치 안내.txt')
    New-Item -ItemType Directory -Path (Join-Path $stage 'bubbles/default'), (Join-Path $stage 'fonts') -Force | Out-Null
    Get-ChildItem (Join-Path $project 'assets/bubbles/default') -File | Where-Object {$_.Extension -ne '.import'} | Copy-Item -Destination (Join-Path $stage 'bubbles/default')
    Get-ChildItem (Join-Path $project 'fonts') -Filter *.ttf | Copy-Item -Destination (Join-Path $stage 'fonts')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $releaseZip = Join-Path $output 'HaruHana-Windows-x86_64.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $releaseZip)
    $sourceZip = Join-Path $output ('HaruHana-source-' + $version + '.zip')
    $zip = [IO.Compression.ZipFile]::Open($sourceZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $project -Recurse -File -Force) {
            $relative = $file.FullName.Substring($project.Length + 1).Replace('\', '/')
            if ($relative -match '(^|/)(\.[^/]+|__pycache__)/|\.(import|log|tmp|bak|pyc)$|export_credentials\.cfg$') { continue }
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, ('HaruHana/' + $relative)) | Out-Null
        }
    } finally { $zip.Dispose() }
    Get-FileHash -LiteralPath $releaseZip,$sourceZip -Algorithm SHA256 | ForEach-Object { "$($_.Hash.ToLower())  $(Split-Path $_.Path -Leaf)" } | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt')
    Write-Output "Release ready: $output"
} finally { $env:APPDATA = $originalAppData }
