-- 같은 MySQL 세션에서 뒤따르는 seed 파일들이 함께 사용하는 기준값입니다.
SET @seed_now = CURRENT_TIMESTAMP(6);
SET @seed_today = DATE(@seed_now);
SET @seed_user_count = 1000;
SET @seed_equipment_count = 5000;
SET @seed_rental_count = 20000;
SET @seed_payment_count = 10000;
SET @seed_report_count = 5000;
SET @seed_admin_action_count = 5000;
SET @seed_notification_count = 5000;

-- 1부터 20,000까지의 연속된 숫자를 set-based INSERT에 사용합니다.
-- MySQL은 같은 TEMPORARY TABLE을 한 쿼리에서 여러 alias로 다시 열 수 없으므로
-- 숫자 테이블을 CROSS JOIN하지 않고 재귀 CTE로 채웁니다.
DROP TEMPORARY TABLE IF EXISTS seed_numbers;

CREATE TEMPORARY TABLE seed_numbers (
    n INT NOT NULL PRIMARY KEY
);

SET SESSION cte_max_recursion_depth = 20000;

INSERT INTO seed_numbers (n)
WITH RECURSIVE number_sequence (n) AS (
    SELECT 1

    UNION ALL

    SELECT n + 1
    FROM number_sequence
    WHERE n < @seed_rental_count
)
SELECT n
FROM number_sequence;
