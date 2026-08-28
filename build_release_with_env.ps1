$envFile = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path $envFile)) {
  throw 'Create .env from .env.example first.'
}

$values = @{}
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)\s*$') {
    $values[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'")
  }
}

if (-not $values['SUPABASE_URL'] -or -not $values['SUPABASE_ANON_KEY']) {
  throw 'SUPABASE_URL and SUPABASE_ANON_KEY are required in .env.'
}

flutter build apk --release `
  --dart-define="SUPABASE_URL=$($values['SUPABASE_URL'])" `
  --dart-define="SUPABASE_ANON_KEY=$($values['SUPABASE_ANON_KEY'])"
