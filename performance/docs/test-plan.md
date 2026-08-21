# Iter 부하·동시성 테스트 계획

## 1. 목적

- 성능 개선 전후의 RPS와 p95·p99 비교
- 지속·순간·장시간 부하의 안정성과 회복 확인
- HikariCP, JVM, MySQL의 최초 포화 지점 확인
- 신고·반납·대여·관리자 상태 변경의 동시성 정합성 검증

## 2. 원칙

- 전용 DB `iter_perf`와 동일한 기준 snapshot을 사용한다.
- 비교 실행은 동일 커밋, 데이터, JVM, HikariCP, MySQL 설정을 유지한다.
- 인덱스·쿼리·풀 크기 등 개선 항목은 한 번에 하나만 변경한다.
- 읽기 부하는 `ramping-arrival-rate`로 요청률을 고정해 지연 증가로 요청 수가 줄어드는 현상을 피한다.
- 동시성 테스트 전에는 fixture를 초기 상태로 복원한다.
- 예상한 409와 예상 밖 4xx·5xx를 별도 지표로 기록한다.
- S3, 카카오 OAuth, 프론트엔드 성능은 제외한다.

## 3. 데이터와 인증

| 데이터 | 건수 |
|---|---:|
| 회원 | 1,000 |
| 장비 | 5,000 |
| 대여 | 20,000 |
| 결제 | 10,000 |
| 신고 | 5,000 |
| 관리자 처리 이력 | 5,000 |
| 알림 | 5,000 |

- 일반 혼합 부하는 사용자별 계정과 소유권이 맞는 `RENTAL_IDS`, `REPORT_IDS`를 사용한다.
- 로그인 성능은 Argon2 비용이 포함되므로 인증 세션과 혼합 부하에서 별도로 관찰한다.
- Stress와 Soak는 계정 정보로 Access Token을 재발급한다.
- 인증 세션은 로그인 → CSRF 발급 → Refresh Token 회전 → 로그아웃을 검증한다.

## 4. 시나리오

| 시나리오 | 기본 목적 |
|---|---|
| Smoke | 인증, fixture, 주요 응답 계약 확인 |
| Endpoint baseline | 단일 API의 독립 응답시간 측정 |
| Mixed | 사용자·관리자 API를 가중치로 혼합 |
| Stress | RPS를 단계적으로 높여 포화점 확인 |
| Spike | 순간 부하 처리와 종료 후 회복 확인 |
| Soak | 장시간 Heap·GC·커넥션 누적 확인 |
| Auth session | Cookie·CSRF·토큰 회전 확인 |
| Concurrency | 동일 자원의 상태 전이와 중복 방지 검증 |

현재 대표 부하 구성:

| 측정 | 구성 |
|---|---|
| Mixed | 5→20 RPS, 20 RPS 유지 |
| Stress | 20→40→80→120 RPS |
| Spike | 20→200 RPS→20 RPS |
| Soak | 20 RPS, 30분 |
| 한계 정밀 측정 | 220→240→260→280 RPS |
| 동시성 | 동일 자원 50요청 |

## 5. 동시성 기대 결과

| 시나리오 | 기대 결과 |
|---|---|
| 동일 대상 신고 | 생성 1건, 409 49건, DB 신고 1건 |
| 반납 최종 확인 | 성공 1건, 409 49건, 최종 상태 변경 1회 |
| 대여 승인 | 성공 1건, 409 49건, 500 0건 |
| 동일 기간 대여 생성 | 생성 1건, 409 49건, 중복 기간 0건 |
| 관리자 회원 상태 변경 | 성공 1건, 409 49건, 처리 이력 1건 |
| 관리자 장비 상태 변경 | 성공 1건, 409 49건, 처리 이력 1건 |
| 관리자 신고 상태 변경 | 성공 1건, 409 49건, 처리 이력 1건 |

## 6. 수집 지표

### k6

- 목표·실제 RPS, VU, Dropped iteration
- p50, p90, p95, p99, 최대 응답시간
- HTTP 실패, Check, 예상된 충돌, 예상 밖 응답

### Spring·JVM

- API별 요청량과 응답시간
- Java CPU, Heap, GC pause, Thread

### HikariCP·MySQL

- active, idle, pending, connection acquire time
- MySQL CPU, QPS, slow query, rows examined
- row lock wait와 deadlock
- 주요 쿼리 `EXPLAIN ANALYZE`

최종 측정값과 발견 사항은 `final-report.md`, 실제 명령은 상위 `README.md`에서 확인한다.
