# 성능 테스트 데이터 준비

모든 부하테스트는 격리된 MySQL DB `iter_perf`와 같은 기준 데이터에서 시작한다. 운영 DB나 팀 공유 개발 DB에는 실행하지 않는다.

## 1. 데이터 규모

| 회원 | 장비 | 대여 | 결제 | 신고 | 관리자 이력 | 알림 |
|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | 5,000 | 20,000 | 10,000 | 5,000 | 5,000 | 5,000 |

상태, 날짜, 검색어, 증빙, 썸네일을 분산하고 생성 후 검증 SQL로 행 수와 참조 무결성을 확인한다.

## 2. 최초 준비

`application-perf.yml`은 `ddl-auto=validate`이므로 현재 커밋 기준 스키마가 먼저 필요하다. 기존 성능 DB에 최신 변경만 반영할 때 서버를 중지하고 다음 SQL을 한 번 실행한다.

```sql
SOURCE performance/seed/sql/04-upgrade-latest-dev-schema.sql;
```

테스트 계정의 원문 비밀번호는 `PerfTest123!`이다. 로컬 성능 테스트에만 사용하며 실제 서비스 계정에는 재사용하지 않는다.

저장소의 예제 해시 파일을 Git에서 제외되는 로컬 경로로 복사한다.

```powershell
New-Item -ItemType Directory -Force performance/seed/local
Copy-Item performance/seed/credentials.example.sql performance/seed/local/credentials.sql
```

runner가 읽는 파일은 다음 경로다.

```text
performance/seed/local/credentials.sql
```

실제 서비스 비밀번호나 개인정보는 사용하지 않는다.

## 3. 전체 seed 실행

애플리케이션을 중지하고 MySQL에서 프로젝트 루트 기준으로 실행한다.

```sql
USE iter_perf;
SOURCE performance/seed/sql/run-users-equipment.sql;
SOURCE performance/seed/sql/run-rentals-evidence.sql;
SOURCE performance/seed/sql/run-payments-reports-actions.sql;
```

각 runner는 필요한 reset, 공통 변수 설정, 생성, 검증을 순서대로 실행한다. 출력의 `actual_count`와 `expected_count`가 일치하고 무결성 오류 수가 0이어야 한다.

## 4. 주요 fixture

| 대상 | 용도 |
|---|---|
| User 1 | ACTIVE 관리자 |
| User 2 | 일반 조회·대여·신고 상세 사용자 |
| User 3 | Equipment 1~5 등록자 |
| User 4 | 신고 중복 동시성 사용자 |
| User 5 | 관리자 회원 상태 변경 대상 |
| Equipment 1 | Rental 1 거래 상세·증빙 비교 |
| Equipment 2 | Rental 2 반납 최종 확인 |
| Equipment 3 | Rental 3 대여 승인 |
| Equipment 4 | 동일 기간 대여 생성·관리자 상태 변경 |
| Equipment 5 | SUSPENDED 장비 |
| Rental 1 | COMPLETED, 사용자 2가 당사자 |
| Rental 2 | RETURNED, 양쪽 증빙 존재 |
| Rental 3 | REQUESTED, 승인 동시성 대상 |
| Rental 6 | PENDING, 결제 대기 fixture |
| Report 1 | 사용자 2의 RECEIVED 신고 |

상태 변경 시나리오는 fixture를 소비하므로 매 실행 전에 snapshot을 복원하거나 해당 seed를 다시 실행한다.

## 5. 부분 초기화

| 파일 | 대상 |
|---|---|
| `01-reset-rentals.sql` | 대여·배송·증빙·분쟁 |
| `02-reset-payments-reports-actions.sql` | 결제·신고·관리자 이력·알림 |
| `03-reset-auth-session.sql` | Refresh Token |

`00-reset.sql`은 전체 성능 데이터를 초기화한다.

## 6. Snapshot

전체 seed 검증 후 기준 snapshot을 생성한다.

```powershell
mysqldump --single-transaction --no-tablespaces --databases iter_perf --result-file="performance/seed/snapshots/iter_perf_baseline.sql"
```

복원 전 대상 DB가 `iter_perf`인지 반드시 확인한다. Snapshot과 schema dump는 Git에 포함하지 않는다.
