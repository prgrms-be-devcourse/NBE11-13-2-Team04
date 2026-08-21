# 로컬 성능 모니터링

Prometheus에 k6와 Spring 지표를 저장하고 Grafana 대시보드에서 함께 확인한다.

## 1. 애플리케이션 실행

Prometheus 컨테이너가 Windows 호스트의 관리 포트에 접근할 수 있도록 설정한다.

```powershell
$env:PERF_MANAGEMENT_ADDRESS = "0.0.0.0"
$env:PERF_MANAGEMENT_PORT = "9091"

.\gradlew.bat bootRun
```

메트릭 노출 확인:

```powershell
curl.exe http://localhost:9091/actuator/prometheus
```

## 2. Prometheus·Grafana 실행

```powershell
docker compose -f performance/monitoring/compose.yml up -d
docker compose -f performance/monitoring/compose.yml ps
```

| 서비스 | 주소 |
|---|---|
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3000` |

Grafana의 `Iter Performance/Iter Performance Overview` 대시보드와 Prometheus 데이터 소스는 자동 등록된다. 기본 로컬 계정은 Compose 설정에서 확인하며 실제 서비스 비밀번호를 사용하지 않는다.

Prometheus의 `Status > Target health`에서 `prometheus`, `iter-spring`이 모두 `UP`이어야 한다.

## 3. k6 지표 전송

```powershell
$env:K6_PROMETHEUS_RW_SERVER_URL = "http://localhost:9090/api/v1/write"
$env:K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM = "true"

$runId = "smoke-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

k6 run `
  -o experimental-prometheus-rw `
  --tag testid=$runId `
  performance/scenarios/smoke.js
```

Grafana 상단 `Test ID`에서 `$runId`를 선택하면 해당 실행의 k6 RPS와 응답시간을 확인할 수 있다. Spring/JVM/Hikari 지표는 같은 시간 범위로 비교한다.

## 4. 핵심 관측 항목

- k6 실제 RPS, p95·p99, 오류율, Dropped iteration, VU
- API별 RPS와 응답시간
- Java·시스템 CPU, Heap, GC pause
- Hikari active·idle·pending

## 5. 종료와 데이터 보존

```powershell
docker compose -f performance/monitoring/compose.yml down
```

대시보드와 Prometheus 데이터는 Docker volume에 유지된다. 데이터를 완전히 삭제할 때만 `down -v`를 사용한다.
