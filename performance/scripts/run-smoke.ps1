$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$localEnvironmentFile = Join-Path $repositoryRoot "performance\config\perf-env.local.ps1"

if (-not (Test-Path $localEnvironmentFile)) {
    throw "performance/config/perf-env.example.ps1을 perf-env.local.ps1로 복사한 뒤 DB 계정을 입력하세요."
}

. $localEnvironmentFile
& (Join-Path $PSScriptRoot "check-environment.ps1")

try {
    Invoke-WebRequest -Uri "$($env:BASE_URL.TrimEnd('/'))/v3/api-docs" -UseBasicParsing | Out-Null
}
catch {
    throw "백엔드 서버에 연결할 수 없습니다. perf 프로필 서버를 먼저 실행하세요: $($_.Exception.Message)"
}

Push-Location $repositoryRoot
try {
    & k6 run performance/scenarios/smoke.js
    if ($LASTEXITCODE -ne 0) {
        throw "Smoke 테스트가 실패했습니다. k6 종료 코드: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
