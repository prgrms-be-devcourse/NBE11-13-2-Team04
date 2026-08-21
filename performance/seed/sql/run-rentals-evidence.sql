-- 회원·장비 seed 실행이 성공한 뒤 같은 프로젝트 루트에서 호출합니다.
-- 대여 하위 데이터 초기화 → 공통 숫자 → 대여·배송·증빙 생성 → 검증 순서입니다.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE iter_perf;

SOURCE performance/seed/sql/01-reset-rentals.sql;
SOURCE performance/seed/sql/05-seed-context.sql;
SOURCE performance/seed/sql/20-rentals-evidence.sql;
SOURCE performance/seed/sql/25-verify-rentals-evidence.sql;
