$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSCommandPath
$runDirectory = Join-Path $projectRoot '.local-run'
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
Set-Content -LiteralPath (Join-Path $runDirectory '.gitignore') -Value '*'

function Test-LocalPort([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $pending = $client.ConnectAsync('127.0.0.1', $Port)
        return ($pending.Wait(1000) -and $client.Connected)
    } catch { return $false } finally { $client.Dispose() }
}

function Wait-Http([string]$Url, [int]$Seconds = 90) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) { return }
        } catch { }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "Startup did not become healthy: $Url. See $runDirectory for logs."
}

if (-not (Test-LocalPort 5432)) {
    throw 'Configured PostgreSQL port 5432 is not reachable. Start the configured database before launching the application.'
}

$state = [ordered]@{ startedAt = (Get-Date).ToString('o') }
$previousStatePath = Join-Path $runDirectory 'services.json'
$previousState = if (Test-Path -LiteralPath $previousStatePath) { Get-Content -LiteralPath $previousStatePath -Raw | ConvertFrom-Json } else { $null }
# Use the already-installed local AI runtime and cached model; never download models here.
$ollamaCommand = Get-Command ollama.exe -ErrorAction SilentlyContinue
if ($ollamaCommand -and -not (Test-LocalPort 11434)) {
    $previousOllamaHost = $env:OLLAMA_HOST
    try {
        $env:OLLAMA_HOST = '127.0.0.1:11434'
        $ollama = Start-Process -FilePath $ollamaCommand.Source -ArgumentList 'serve' -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $runDirectory 'ollama.stdout.log') `
            -RedirectStandardError (Join-Path $runDirectory 'ollama.stderr.log')
        $state.ollamaPid = $ollama.Id
        Write-Output "Installed Ollama runtime started: process $($ollama.Id)"
    } finally { $env:OLLAMA_HOST = $previousOllamaHost }
} elseif ($ollamaCommand) {
    $state.ollama = 'Existing local AI runtime reused'
    if ($previousState.ollamaPid) { $state.ollamaPid = $previousState.ollamaPid }
}
$backendDirectory = Join-Path $projectRoot 'backend'
if (Test-LocalPort 8080) {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/health' -TimeoutSec 5
    if ($health.service -ne 'bank-finance-backend') { throw 'Port 8080 belongs to another service.' }
    $state.backend = 'Existing healthy backend reused'
    if ($previousState.backendPid) { $state.backendPid = $previousState.backendPid }
} else {
    $javaPath = (Get-Command java.exe -ErrorAction Stop).Source
    $jarPath = Join-Path $backendDirectory 'target/backend-0.0.1-SNAPSHOT.jar'
    if (-not (Test-Path -LiteralPath $jarPath)) { throw 'Build the backend package before running start-local.ps1.' }
    $backend = Start-Process -FilePath $javaPath -WindowStyle Hidden -WorkingDirectory $backendDirectory -PassThru `
        -ArgumentList @('-Dspring.devtools.restart.enabled=false', '-jar', ('"{0}"' -f $jarPath), '--server.address=127.0.0.1', '--spring.jpa.hibernate.ddl-auto=validate') `
        -RedirectStandardOutput (Join-Path $runDirectory 'backend.stdout.log') `
        -RedirectStandardError (Join-Path $runDirectory 'backend.stderr.log')
    $state.backendPid = $backend.Id
    Write-Output "Backend started: process $($backend.Id)"
}

if (Test-LocalPort 5173) {
    $page = Invoke-WebRequest -Uri 'http://127.0.0.1:5173/' -UseBasicParsing -TimeoutSec 5
    if ($page.Content -notmatch '/src/main.tsx|/assets/index-') { throw 'Port 5173 belongs to another application.' }
    $state.frontend = 'Existing frontend reused'
    if ($previousState.frontendPid) { $state.frontendPid = $previousState.frontendPid }
} else {
    $nodePath = (Get-Command node.exe -ErrorAction Stop).Source
    $frontendDirectory = Join-Path $projectRoot 'frontend'
    $vitePath = Join-Path $frontendDirectory 'node_modules/vite/bin/vite.js'
    if (-not (Test-Path -LiteralPath $vitePath)) { throw 'Frontend dependencies are missing.' }
    $frontend = Start-Process -FilePath $nodePath -WindowStyle Hidden -WorkingDirectory $frontendDirectory -PassThru `
        -ArgumentList @(('"{0}"' -f $vitePath), '--host', '127.0.0.1', '--port', '5173', '--strictPort') `
        -RedirectStandardOutput (Join-Path $runDirectory 'frontend.stdout.log') `
        -RedirectStandardError (Join-Path $runDirectory 'frontend.stderr.log')
    $state.frontendPid = $frontend.Id
    Write-Output "Frontend started: process $($frontend.Id)"
}

$state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'services.json')
Wait-Http 'http://127.0.0.1:8080/api/health'
Wait-Http 'http://127.0.0.1:5173/'
Wait-Http 'http://127.0.0.1:5173/api/health'
Write-Output 'Backend healthy: http://localhost:8080'
Write-Output 'Frontend healthy: http://localhost:5173'
Write-Output 'Frontend-to-backend proxy healthy: http://localhost:5173/api/health'
