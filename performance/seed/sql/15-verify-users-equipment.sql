-- 회원·장비 seed가 의도한 수량과 고정 fixture를 만들었는지 사람이 확인하기 위한 조회입니다.
SELECT 'seed_numbers' AS table_name,
       COUNT(*) AS actual_count,
       @seed_rental_count AS expected_count
FROM seed_numbers;

SELECT 'users' AS table_name,
       COUNT(*) AS actual_count,
       @seed_user_count AS expected_count
FROM iter_perf.users;

SELECT role,
       status,
       COUNT(*) AS user_count
FROM iter_perf.users
GROUP BY role, status
ORDER BY role, status;

SELECT 'equipment' AS table_name,
       COUNT(*) AS actual_count,
       @seed_equipment_count AS expected_count
FROM iter_perf.equipment;

SELECT status,
       COUNT(*) AS equipment_count
FROM iter_perf.equipment
GROUP BY status
ORDER BY status;

SELECT COUNT(*) AS thumbnail_count
FROM iter_perf.equipment_image
WHERE is_thumbnail = b'1';

SELECT 'equipment_image' AS table_name,
       COUNT(*) AS actual_count,
       @seed_equipment_count + FLOOR(@seed_equipment_count / 5) AS expected_count
FROM iter_perf.equipment_image;

SELECT id,
       email,
       role,
       status
FROM iter_perf.users
WHERE id BETWEEN 1 AND 5
ORDER BY id;

SELECT id,
       owner_id,
       name,
       status
FROM iter_perf.equipment
WHERE id BETWEEN 1 AND 5
ORDER BY id;

-- %, _, +, 괄호를 포함한 장비명이 ACTIVE 상태로 생성되었는지 확인합니다.
-- 이후 검색 API에서 이 문자를 와일드카드가 아닌 일반 검색어로 검증할 수 있습니다.
SELECT CASE
           WHEN name LIKE '%100!%%' ESCAPE '!' THEN 'percent'
           WHEN name LIKE '%!_%' ESCAPE '!' THEN 'underscore'
           WHEN name LIKE '%+%' THEN 'plus'
       END AS special_name_type,
       COUNT(*) AS active_equipment_count
FROM iter_perf.equipment
WHERE status = 'ACTIVE'
  AND (
        name LIKE '%100!%%' ESCAPE '!'
        OR name LIKE '%!_%' ESCAPE '!'
        OR name LIKE '%+%'
      )
GROUP BY special_name_type
ORDER BY special_name_type;
