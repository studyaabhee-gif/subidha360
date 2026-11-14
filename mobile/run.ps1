# Runs the app in your browser at http://localhost:5050.
# `flutter run -d edge` fails with Edge 157 (Flutter misreads Edge's launcher
# exiting as a failed start), so this serves the app and opens the page itself.
# Start the backend first: ..\backend\run.ps1
$port = 5050
$url = "http://localhost:$port"
Set-Location $PSScriptRoot

# Open the page once the server answers. The first build can take a minute.
Start-Job -ArgumentList $url -ScriptBlock {
    param($url)
    for ($i = 0; $i -lt 180; $i++) {
        Start-Sleep -Seconds 2
        try { Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 2 | Out-Null; Start-Process $url; return } catch {}
    }
} | Out-Null

Write-Host "Starting the app. Your browser opens at $url when it's ready (first time: up to a minute)."
Write-Host "Press r here to reload after code changes. The page reloads by itself; don't refresh it too."
Write-Host "Keep the app open in ONE tab only. Extra tabs or manual refreshes make the debugger print"
Write-Host "'Cannot find context with specified id' errors. They are harmless; the reload still worked."
Write-Host "Press q to stop."
flutter run -d web-server --web-port=$port --web-hostname=localhost @args
