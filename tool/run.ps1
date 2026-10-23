param(
    [ValidateSet('preview', 'test', 'analyze', 'web', 'android')]
    [string]$Task = 'preview',
    [int]$Port = 8800,
    [string]$JavaHome
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) { $flutterCommand.Source } else {
    Join-Path $env:USERPROFILE '.codex\tools\flutter\bin\flutter.bat'
}
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Install Flutter 3.47 or newer and add flutter/bin to PATH.'
}
if ($Task -eq 'android') {
    $javaCandidates = @($JavaHome, $env:JAVA_HOME, (Join-Path $env:ProgramFiles 'Java\jdk-17'))
    $selectedJava = $javaCandidates | Where-Object {
        $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\javac.exe'))
    } | Select-Object -First 1
    if (-not $selectedJava) { throw 'Install JDK 17+ and pass -JavaHome <path>.' }
    # Process-local override; keep the machine's Java settings unchanged.
    $env:JAVA_HOME = $selectedJava
    $env:PATH = "$(Join-Path $selectedJava 'bin');$env:PATH"
}
# Flutter 3.47's analysis server has a Windows Unicode-path framing issue.
# A junction uses the same files; no copy or relocation is performed.
$buildPath = $projectRoot
if ($projectRoot -match '[^\x00-\x7F]') {
    $aliasRoot = Join-Path $env:LOCALAPPDATA 'BloomDevelopment'
    New-Item -ItemType Directory -Force -Path $aliasRoot | Out-Null
    $buildPath = Join-Path $aliasRoot 'bloom'
    if (Test-Path -LiteralPath $buildPath) {
        $link = Get-Item -LiteralPath $buildPath
        if ($link.Target -ne $projectRoot) { throw "The build alias already points to another folder: $buildPath" }
    } else {
        New-Item -ItemType Junction -Path $buildPath -Target $projectRoot | Out-Null
    }
}
Push-Location -LiteralPath $buildPath
try {
    & $flutterExecutable pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    switch ($Task) {
        preview { & $flutterExecutable run -d web-server --web-hostname 127.0.0.1 --web-port $Port }
        test { & $flutterExecutable test }
        analyze { & $flutterExecutable analyze }
        web { & $flutterExecutable build web --release --no-web-resources-cdn }
        android { & $flutterExecutable build apk --release }
    }
    exit $LASTEXITCODE
} finally { Pop-Location }
