-- 프로젝트 루트에서 mysql 클라이언트를 실행한 뒤 SOURCE로 이 파일을 호출합니다.
-- 로컬 비밀번호 해시 → 초기화 → 공통 숫자 → 회원·장비 → 확인 조회 순서입니다.
-- 한글 seed가 Windows 기본 코드 페이지의 영향을 받지 않도록 연결 문자셋을 고정합니다.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- 기본 DB를 명시하여 잘못된 DB에 임시 테이블을 만들거나 초기화 후 중단되는 일을 방지합니다.
USE iter_perf;

SOURCE performance/seed/local/credentials.sql;
SOURCE performance/seed/sql/00-reset.sql;
SOURCE performance/seed/sql/05-seed-context.sql;
SOURCE performance/seed/sql/10-users-equipment.sql;
SOURCE performance/seed/sql/15-verify-users-equipment.sql;
