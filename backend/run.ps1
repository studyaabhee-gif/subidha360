# Starts the API with the settings saved in your Windows user account, so it
# works in terminals opened before those settings were saved.
# No secrets are stored in this file.
$names = 'APP_ENV', 'MONGO_URI', 'MONGO_DB', 'REDIS_URL', 'JWT_SECRET',
    'FCM_PROJECT_ID', 'FCM_CREDENTIALS_FILE', 'SPARROW_TOKEN', 'SPARROW_FROM'

foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    if ($value) { Set-Item "env:$name" $value }
}

Set-Location $PSScriptRoot
go run ./cmd/api
