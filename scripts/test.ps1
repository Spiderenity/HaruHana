param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path $project -Parent
$validation = Join-Path $workspace ('work/validation/suite-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $validation -Force | Out-Null
$originalAppData = $env:APPDATA
$fixture = [IO.Path]::GetFullPath((Join-Path $project 'characters/patch_regression_fixture'))
$characters = [IO.Path]::GetFullPath((Join-Path $project 'characters'))
$fixtureBackup = [IO.Path]::GetFullPath((Join-Path $characters '.patch_regression_fixture.previous'))
if (Test-Path -LiteralPath $fixture) { throw 'Test fixture already exists; move it aside before running tests.' }
if (Test-Path -LiteralPath $fixtureBackup) { throw 'Test fixture backup already exists; move it aside before running tests.' }
try {
    foreach ($name in @('regression', 'creator_speech', 'bubble_menu', 'progression_points', 'touch_reactions', 'dropdown_scroll', 'desktop_features', 'patch_reports')) {
        $env:APPDATA = Join-Path $validation $name
        New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
        $out = Join-Path $validation ($name + '.log')
        $err = Join-Path $validation ($name + '-error.log')
        $arguments = @('--path', ('"' + $project + '"'), '--script', ('res://system/tests/' + $name + '.gd'))
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $null = $process.Handle  # 없으면 Windows PowerShell 5.1에서 ExitCode가 비어 통과한 테스트도 실패로 보인다
        if (!$process.WaitForExit(45000)) {
            $process.Kill()
            throw "Test timed out: $name. Logs: $validation"
        }
        $errors = Get-Content -LiteralPath $err -Raw
        if ($process.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|Parse Error|Compile Error') {
            throw "Test failed: $name. Logs: $validation"
        }
        Write-Output "PASS $name"
    }
    Write-Output "All tests passed. Logs: $validation"
} finally {
    $env:APPDATA = $originalAppData
    if ((Split-Path $fixture -Parent) -ne $characters) { throw 'Unexpected test fixture path' }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    if ((Split-Path $fixtureBackup -Parent) -ne $characters) { throw 'Unexpected test backup path' }
    if (Test-Path -LiteralPath $fixtureBackup) { Remove-Item -LiteralPath $fixtureBackup -Recurse -Force }
}
