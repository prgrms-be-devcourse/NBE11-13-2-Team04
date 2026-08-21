-- 대여·증빙 seed 실행이 성공한 뒤 같은 프로젝트 루트에서 호출합니다.
-- 결제·신고·관리자 처리 이력·알림만 초기화 → 공통 숫자 → 데이터 생성 → 검증 순서입니다.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE iter_perf;

SOURCE performance/seed/sql/02-reset-payments-reports-actions.sql;
SOURCE performance/seed/sql/05-seed-context.sql;
SOURCE performance/seed/sql/30-payments-reports-actions.sql;
SOURCE performance/seed/sql/35-verify-payments-reports-actions.sql;
