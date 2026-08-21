$ErrorActionPreference = "Stop"

$requiredCommands = @("java", "mysql", "k6", "docker")
$missingCommands = @()

foreach ($command in $requiredCommands) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        $missingCommands += $command
    }
}

if ($missingCommands.Count -gt 0) {
    throw "필수 명령을 찾을 수 없습니다: $($missingCommands -join ', ')"
}

$requiredEnvironmentVariables = @(
    "PERF_DB_URL",
    "PERF_DB_USERNAME",
    "PERF_DB_PASSWORD",
    "JWT_SECRET_KEY",
    "BASE_URL",
    "USER_EMAIL",
    "USER_PASSWORD",
    "ADMIN_EMAIL",
    "ADMIN_PASSWORD"
)
$missingEnvironmentVariables = @()

foreach ($variableName in $requiredEnvironmentVariables) {
    $value = [Environment]::GetEnvironmentVariable($variableName)
    if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith("<")) {
        $missingEnvironmentVariables += $variableName
    }
}

if ($missingEnvironmentVariables.Count -gt 0) {
    throw "필수 환경변수를 설정하세요: $($missingEnvironmentVariables -join ', ')"
}

Write-Host "성능 테스트 실행 환경 확인 완료"
