-- 로그인 가능한 테스트 회원 1,000명을 생성합니다.
-- @perf_password_hash는 Git에서 제외된 seed/local/credentials.sql에서 주입합니다.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

INSERT INTO iter_perf.users (
    id,
    created_at,
    updated_at,
    email,
    name,
    nick_name,
    password,
    phone,
    role,
    status,
    point_balance
)
SELECT n,
       DATE_SUB(@seed_now, INTERVAL MOD(n, 365) DAY),
       DATE_SUB(@seed_now, INTERVAL MOD(n, 30) DAY),
       CASE
           WHEN n = 1 THEN 'perf-admin@example.com'
           ELSE CONCAT('perf-user-', LPAD(n, 4, '0'), '@example.com')
       END,
       CASE
           WHEN n = 1 THEN '성능관리자'
           ELSE CONCAT('성능회원', LPAD(n, 4, '0'))
       END,
       CASE
           WHEN n = 1 THEN 'perf-admin'
           ELSE CONCAT('perf-user-', LPAD(n, 4, '0'))
       END,
       @perf_password_hash,
       CONCAT('010', LPAD(MOD(n, 10000), 4, '0'), LPAD(MOD(n * 37, 10000), 4, '0')),
       CASE WHEN n = 1 THEN 'ADMIN' ELSE 'USER' END,
       CASE
           WHEN n <= 100 THEN 'ACTIVE'
           WHEN MOD(n, 40) = 0 THEN 'SUSPENDED'
           WHEN MOD(n, 40) = 1 THEN 'DELETED'
           ELSE 'ACTIVE'
       END,
       10000000
FROM seed_numbers
WHERE n <= @seed_user_count;

-- 공개 조회와 상태별 검색을 확인할 수 있는 장비 5,000개를 생성합니다.
-- 1~5번은 k6 고정 fixture로 사용하고, 나머지는 상태를 80:5:5:5:5 비율로 분산합니다.
INSERT INTO iter_perf.equipment (
    id,
    created_at,
    updated_at,
    available_from,
    available_to,
    category,
    condition_detail,
    daily_price,
    description,
    name,
    owner_id,
    product_condition,
    status
)
SELECT n,
       DATE_SUB(@seed_now, INTERVAL MOD(n, 365) DAY),
       DATE_SUB(@seed_now, INTERVAL MOD(n, 30) DAY),
       DATE_SUB(DATE(@seed_now), INTERVAL 30 DAY),
       DATE_ADD(DATE(@seed_now), INTERVAL 365 DAY),
       CASE MOD(n, 9)
           WHEN 0 THEN 'LAPTOP'
           WHEN 1 THEN 'TABLET'
           WHEN 2 THEN 'CAMERA'
           WHEN 3 THEN 'LENS'
           WHEN 4 THEN 'MONITOR'
           WHEN 5 THEN 'VR'
           WHEN 6 THEN 'GAME_CONSOLE'
           WHEN 7 THEN 'PROJECTOR'
           ELSE 'OTHER'
       END,
       CASE
           WHEN MOD(n, 20) = 0 THEN '성능 테스트용 외관 사용감이 있습니다.'
           ELSE '성능 테스트용 정상 장비입니다.'
       END,
       10000 + MOD(n, 100) * 1000,
       CONCAT('부하 테스트용 장비 설명 ', n),
       CASE
           -- 10, 11, 12는 아래 상태 분배에서 ACTIVE가 되므로 공개 검색으로도 검증할 수 있습니다.
           WHEN MOD(n, 200) = 10 THEN CONCAT('카메라 100% ', n)
           WHEN MOD(n, 200) = 11 THEN CONCAT('렌즈_', n)
           WHEN MOD(n, 200) = 12 THEN CONCAT('MacBook Pro (M3)+ ', n)
           ELSE CONCAT('성능장비-', LPAD(n, 5, '0'))
       END,
       CASE
           WHEN n <= 5 THEN 3
           ELSE 2 + MOD(n - 1, 99)
       END,
       CASE
           WHEN MOD(n, 20) = 0 THEN 'DAMAGED'
           WHEN MOD(n, 20) = 1 THEN 'DIRTY'
           WHEN MOD(n, 20) = 2 THEN 'MISSING_PART'
           WHEN MOD(n, 20) = 3 THEN 'OTHER'
           ELSE 'NORMAL'
       END,
       CASE
           WHEN n <= 4 THEN 'ACTIVE'
           WHEN n = 5 THEN 'SUSPENDED'
           WHEN MOD(n, 20) = 0 THEN 'INACTIVE'
           WHEN MOD(n, 20) = 1 THEN 'MAINTENANCE'
           WHEN MOD(n, 20) = 2 THEN 'SUSPENDED'
           WHEN MOD(n, 20) = 3 THEN 'DELETED'
           ELSE 'ACTIVE'
       END
FROM seed_numbers
WHERE n <= @seed_equipment_count;

-- 모든 장비에 썸네일 한 장을 생성합니다.
INSERT INTO iter_perf.equipment_image (
    id,
    created_at,
    image_url,
    sort_order,
    is_thumbnail,
    equipment_id
)
SELECT n,
       @seed_now,
       CONCAT('https://cdn.example.test/equipment/', n, '/thumbnail.jpg'),
       0,
       b'1',
       n
FROM seed_numbers
WHERE n <= @seed_equipment_count;

-- 장비 다섯 개 중 한 개에는 상세 조회 부하를 위한 추가 이미지를 생성합니다.
INSERT INTO iter_perf.equipment_image (
    id,
    created_at,
    image_url,
    sort_order,
    is_thumbnail,
    equipment_id
)
SELECT 100000 + n,
       @seed_now,
       CONCAT('https://cdn.example.test/equipment/', n, '/detail.jpg'),
       1,
       b'0',
       n
FROM seed_numbers
WHERE n <= @seed_equipment_count
  AND MOD(n, 5) = 0;
