param([ValidateSet('Test','Seed')][string]$Mode = 'Test')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
$names = 'SUPABASE_HOME','SUPABASE_LOCAL_API_URL','SUPABASE_LOCAL_PUBLIC_KEY','SUPABASE_LOCAL_SECRET_KEY','SUPABASE_LOCAL_DB_URL'
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
try {
    # Capture status privately; never print its JSON because it contains local keys.
    if (-not $env:SUPABASE_HOME) { $env:SUPABASE_HOME = Join-Path $repo 'config/local/cli-home' }
    $cli = Join-Path $repo 'supabase/tests/node_modules/.bin/supabase.cmd'
    if (-not (Test-Path -LiteralPath $cli)) { throw 'Run npm.cmd --prefix supabase/tests ci first.' }
    $raw = & $cli status --workdir $repo --output json
    if ($LASTEXITCODE -ne 0) { throw 'Start the local Supabase runtime first.' }
    $status = $raw | ConvertFrom-Json
    $env:SUPABASE_LOCAL_API_URL = $status.API_URL
    $env:SUPABASE_LOCAL_PUBLIC_KEY = if ($status.PUBLISHABLE_KEY) { $status.PUBLISHABLE_KEY } else { $status.ANON_KEY }
    $env:SUPABASE_LOCAL_SECRET_KEY = if ($status.SERVICE_ROLE_KEY) { $status.SERVICE_ROLE_KEY } else { $status.SECRET_KEY }
    $env:SUPABASE_LOCAL_DB_URL = $status.DB_URL
    # Node runner independently rejects non-loopback hosts and unexpected ports BEFORE any API/SQL call.
    $script = if ($Mode -eq 'Seed') { 'supabase/tests/seed-local.mjs' } else { 'supabase/tests/services.test.mjs' }
    & node $script
    if ($LASTEXITCODE -ne 0) { throw 'Local service validation/seed did not complete. See the safe error above.' }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
    Pop-Location
}
