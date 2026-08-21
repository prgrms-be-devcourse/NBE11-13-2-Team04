-- 대여 이력·연체·반납 확인·증빙 비교 부하 테스트용 대여 20,000건을 생성합니다.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

INSERT INTO iter_perf.rental (
    id,
    created_at,
    updated_at,
    address,
    category_snapshot,
    daily_price_snapshot,
    detail_address,
    end_date,
    equipment_id,
    product_name_snapshot,
    receiver_name,
    receiver_phone,
    rental_days,
    renter_id,
    request_message,
    start_date,
    status,
    total_price,
    version,
    zipcode,
    approved_at,
    reject_reason
)
WITH rental_status_source AS (
    SELECT numbers.n,
           equipment.id AS equipment_id,
           equipment.name AS product_name_snapshot,
           equipment.category AS category_snapshot,
           equipment.daily_price AS daily_price_snapshot,
           CASE
               -- k6 고정 fixture
               WHEN numbers.n = 1 THEN 'COMPLETED'
               WHEN numbers.n = 2 THEN 'RETURNED'
               WHEN numbers.n = 3 THEN 'REQUESTED'
               WHEN numbers.n = 4 THEN 'RENTING'
               WHEN numbers.n = 5 THEN 'RETURNING'

               -- 1~5번을 진행 상태로 바꾼 만큼 전체 결제 대상 수를 10,000건으로 유지합니다.
               WHEN numbers.n BETWEEN 10 AND 14 THEN 'PENDING'

               WHEN MOD(numbers.n, 20) BETWEEN 0 AND 7 THEN 'PENDING'
               WHEN MOD(numbers.n, 20) BETWEEN 8 AND 9 THEN 'CANCELED'
               WHEN MOD(numbers.n, 20) = 10 THEN 'REQUESTED'
               WHEN MOD(numbers.n, 20) = 11 THEN 'APPROVED'
               WHEN MOD(numbers.n, 20) = 12 THEN 'REJECTED'
               WHEN MOD(numbers.n, 20) = 13 THEN 'SHIPPING'
               WHEN MOD(numbers.n, 20) = 14 THEN 'RECEIVED'
               WHEN MOD(numbers.n, 20) = 15 THEN 'RENTING'
               WHEN MOD(numbers.n, 20) = 16 THEN 'RETURN_REQUESTED'
               WHEN MOD(numbers.n, 20) = 17 THEN 'RETURNING'
               WHEN MOD(numbers.n, 20) = 18 THEN 'RETURNED'
               WHEN MOD(FLOOR(numbers.n / 20), 2) = 0 THEN 'DISPUTED'
               ELSE 'COMPLETED'
           END AS rental_status,
           CASE
               WHEN numbers.n <= 6 THEN 2
               ELSE 2 + MOD(equipment.id + 10, 99)
           END AS renter_id,
           CASE
               WHEN numbers.n <= 6 THEN 0
               ELSE FLOOR((numbers.n - 6) / 4900)
           END AS rental_round
    FROM seed_numbers AS numbers
    JOIN iter_perf.equipment AS equipment
      ON equipment.id = CASE
           WHEN numbers.n BETWEEN 1 AND 3 THEN numbers.n
           WHEN numbers.n = 4 THEN 7
           WHEN numbers.n = 5 THEN 8
           WHEN numbers.n = 6 THEN 6
           -- 회차마다 37칸 이동해 장비 상태와 RentalStatus의 MOD 주기 상관을 끊습니다.
           ELSE 101 + MOD(
               (numbers.n - 6) + FLOOR((numbers.n - 6) / 4900) * 37,
               4900
           )
         END
    WHERE numbers.n <= @seed_rental_count
),
rental_date_source AS (
    SELECT source.*,
           CASE
               WHEN source.n = 1 THEN DATE_SUB(@seed_today, INTERVAL 60 DAY)
               WHEN source.n = 2 THEN DATE_SUB(@seed_today, INTERVAL 20 DAY)
               WHEN source.n = 3 THEN DATE_ADD(@seed_today, INTERVAL 30 DAY)
               WHEN source.n = 4 THEN DATE_SUB(@seed_today, INTERVAL 10 DAY)
               WHEN source.n = 5 THEN DATE_SUB(@seed_today, INTERVAL 12 DAY)
               WHEN source.n = 6 THEN DATE_ADD(@seed_today, INTERVAL 15 DAY)
               WHEN source.rental_status IN ('PENDING', 'CANCELED', 'REQUESTED', 'APPROVED', 'REJECTED')
                   THEN DATE_ADD(
                       @seed_today,
                       INTERVAL (30 + MOD(source.n, 15) + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'SHIPPING'
                   THEN DATE_ADD(
                       @seed_today,
                       INTERVAL (1 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RECEIVED' AND source.rental_round > 0
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (7 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RECEIVED'
                   THEN DATE_SUB(@seed_today, INTERVAL 1 DAY)
               WHEN source.rental_status = 'RENTING'
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (10 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RETURN_REQUESTED'
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (12 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RETURNING'
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (14 + source.rental_round * 60) DAY
                   )
               ELSE DATE_SUB(
                   @seed_today,
                   INTERVAL (30 + source.rental_round * 60) DAY
               )
           END AS start_date,
           CASE
               WHEN source.n = 1 THEN DATE_SUB(@seed_today, INTERVAL 53 DAY)
               WHEN source.n = 2 THEN DATE_SUB(@seed_today, INTERVAL 13 DAY)
               WHEN source.n = 3 THEN DATE_ADD(@seed_today, INTERVAL 33 DAY)
               WHEN source.n = 4 THEN DATE_SUB(@seed_today, INTERVAL 5 DAY)
               WHEN source.n = 5 THEN DATE_SUB(@seed_today, INTERVAL 7 DAY)
               WHEN source.n = 6 THEN DATE_ADD(@seed_today, INTERVAL 18 DAY)
               WHEN source.rental_status IN ('PENDING', 'CANCELED', 'REQUESTED', 'APPROVED', 'REJECTED')
                   THEN DATE_ADD(
                       @seed_today,
                       INTERVAL (33 + MOD(source.n, 15) + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'SHIPPING'
                   THEN DATE_ADD(
                       @seed_today,
                       INTERVAL (5 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RECEIVED' AND source.rental_round > 0
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (2 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RECEIVED'
                   THEN DATE_ADD(@seed_today, INTERVAL 3 DAY)
               WHEN source.rental_status = 'RENTING'
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (3 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RETURN_REQUESTED'
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (5 + source.rental_round * 60) DAY
                   )
               WHEN source.rental_status = 'RETURNING'
                   THEN DATE_SUB(
                       @seed_today,
                       INTERVAL (7 + source.rental_round * 60) DAY
                   )
               ELSE DATE_SUB(
                   @seed_today,
                   INTERVAL (23 + source.rental_round * 60) DAY
               )
           END AS end_date
    FROM rental_status_source AS source
)
SELECT rental.n,
       LEAST(
           @seed_now,
           DATE_SUB(CAST(rental.start_date AS DATETIME), INTERVAL 10 DAY)
       ),
       LEAST(
           @seed_now,
           DATE_ADD(CAST(rental.end_date AS DATETIME), INTERVAL 2 DAY)
       ),
       '서울특별시 강남구 테헤란로',
       rental.category_snapshot,
       rental.daily_price_snapshot,
       CONCAT('성능 테스트 배송지 ', rental.n),
       rental.end_date,
       rental.equipment_id,
       rental.product_name_snapshot,
       CONCAT('수령인', LPAD(rental.renter_id, 4, '0')),
       CONCAT('010', LPAD(rental.renter_id, 4, '0'), LPAD(MOD(rental.n, 10000), 4, '0')),
       DATEDIFF(rental.end_date, rental.start_date) + 1,
       rental.renter_id,
       CONCAT('부하 테스트 대여 요청 ', rental.n),
       rental.start_date,
       rental.rental_status,
       rental.daily_price_snapshot * (DATEDIFF(rental.end_date, rental.start_date) + 1),
       0,
       '06236',
       CASE
           WHEN rental.rental_status IN (
               'APPROVED', 'SHIPPING', 'RECEIVED', 'RENTING', 'RETURN_REQUESTED',
               'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
           ) THEN LEAST(
               @seed_now,
               DATE_SUB(CAST(rental.start_date AS DATETIME), INTERVAL 3 DAY)
           )
           ELSE NULL
       END,
       CASE
           WHEN rental.rental_status = 'REJECTED' THEN '장비 대여 일정 조정으로 거절되었습니다.'
           ELSE NULL
       END
FROM rental_date_source AS rental;

-- 출고가 시작된 거래에 OUTBOUND 배송 정보를 한 건씩 생성합니다.
INSERT INTO iter_perf.shipping (
    id,
    created_at,
    updated_at,
    carrier,
    delivered_at,
    rental_id,
    shipped_at,
    status,
    tracking_number,
    type
)
SELECT rental.id,
       DATE_ADD(rental.created_at, INTERVAL 1 DAY),
       rental.updated_at,
       '성능택배',
       CASE
           WHEN rental.status IN (
               'RECEIVED', 'RENTING', 'RETURN_REQUESTED', 'RETURNING',
               'RETURNED', 'DISPUTED', 'COMPLETED'
           ) THEN DATE_ADD(CAST(rental.start_date AS DATETIME), INTERVAL 12 HOUR)
           ELSE NULL
       END,
       rental.id,
       CASE
           WHEN rental.status = 'APPROVED' THEN NULL
           ELSE DATE_SUB(CAST(rental.start_date AS DATETIME), INTERVAL 2 DAY)
       END,
       CASE
           WHEN rental.status = 'APPROVED' THEN 'READY'
           WHEN rental.status = 'SHIPPING' THEN 'IN_TRANSIT'
           ELSE 'DELIVERED'
       END,
       CASE
           WHEN rental.status = 'APPROVED' THEN NULL
           ELSE CONCAT('OUT', LPAD(rental.id, 12, '0'))
       END,
       'OUTBOUND'
FROM iter_perf.rental AS rental
WHERE rental.status IN (
    'APPROVED', 'SHIPPING', 'RECEIVED', 'RENTING', 'RETURN_REQUESTED',
    'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
);

-- 수령 확인이 끝난 거래에 수령 당시 상태와 사진을 생성합니다.
INSERT INTO iter_perf.receipt (
    id,
    created_at,
    condition_detail,
    product_condition,
    received_at,
    rental_id
)
SELECT rental.id,
       DATE_ADD(CAST(rental.start_date AS DATETIME), INTERVAL 12 HOUR),
       CASE
           WHEN MOD(rental.id, 50) = 0 THEN '수령 당시 경미한 사용감이 확인됩니다.'
           ELSE '수령 당시 외관과 구성품이 정상입니다.'
       END,
       CASE WHEN MOD(rental.id, 50) = 0 THEN 'DIRTY' ELSE 'NORMAL' END,
       DATE_ADD(CAST(rental.start_date AS DATETIME), INTERVAL 12 HOUR),
       rental.id
FROM iter_perf.rental AS rental
WHERE rental.status IN (
    'RECEIVED', 'RENTING', 'RETURN_REQUESTED', 'RETURNING',
    'RETURNED', 'DISPUTED', 'COMPLETED'
);

INSERT INTO iter_perf.receipt_image (
    id,
    created_at,
    image_url,
    sort_order,
    receipt_id
)
SELECT receipt.id,
       receipt.created_at,
       CONCAT('https://cdn.example.test/receipt/', receipt.id, '/condition.jpg'),
       0,
       receipt.id
FROM iter_perf.receipt AS receipt;

-- 반납 신청 이후 거래에 반납 당시 상태와 사진을 생성합니다.
INSERT INTO iter_perf.return_receipt (
    id,
    created_at,
    condition_detail,
    product_condition,
    return_date,
    rental_id
)
SELECT rental.id,
       DATE_ADD(CAST(rental.end_date AS DATETIME), INTERVAL 10 HOUR),
       CASE
           WHEN rental.id = 2 OR rental.status = 'DISPUTED'
               THEN '반납 당시 모서리 파손이 확인됩니다.'
           WHEN MOD(rental.id, 10) = 0
               THEN '반납 당시 가벼운 오염이 확인됩니다.'
           ELSE '반납 당시 외관과 구성품이 정상입니다.'
       END,
       CASE
           WHEN rental.id = 2 OR rental.status = 'DISPUTED' THEN 'DAMAGED'
           WHEN MOD(rental.id, 10) = 0 THEN 'DIRTY'
           ELSE 'NORMAL'
       END,
       rental.end_date,
       rental.id
FROM iter_perf.rental AS rental
WHERE rental.status IN (
    'RETURN_REQUESTED', 'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
);

INSERT INTO iter_perf.return_receipt_image (
    id,
    created_at,
    image_url,
    sort_order,
    return_receipt_id
)
SELECT return_receipt.id,
       return_receipt.created_at,
       CONCAT('https://cdn.example.test/return-receipt/', return_receipt.id, '/condition.jpg'),
       0,
       return_receipt.id
FROM iter_perf.return_receipt AS return_receipt;

-- DISPUTED 거래는 반납 이상 확인과 함께 최소 분쟁이 생성된 상태로 맞춥니다.
INSERT INTO iter_perf.dispute (
    id,
    created_at,
    updated_at,
    admin_memo,
    description,
    fault_party,
    reason,
    rental_id,
    reporter_id,
    resolved_at,
    respondent_id,
    status
)
SELECT rental.id,
       return_receipt.created_at,
       return_receipt.created_at,
       NULL,
       '반납 장비에서 파손이 확인되어 분쟁을 접수했습니다.',
       NULL,
       '반납 장비 파손',
       rental.id,
       equipment.owner_id,
       NULL,
       rental.renter_id,
       'REPORTED'
FROM iter_perf.rental AS rental
JOIN iter_perf.equipment AS equipment
  ON equipment.id = rental.equipment_id
JOIN iter_perf.return_receipt AS return_receipt
  ON return_receipt.rental_id = rental.id
WHERE rental.status = 'DISPUTED';

INSERT INTO iter_perf.dispute_image (
    id,
    created_at,
    image_url,
    sort_order,
    dispute_id
)
SELECT dispute.id,
       dispute.created_at,
       CONCAT('https://cdn.example.test/dispute/', dispute.id, '/evidence.jpg'),
       0,
       dispute.id
FROM iter_perf.dispute AS dispute;

-- 반납 배송 단계에 들어간 거래에 RETURN 배송 정보를 한 건씩 생성합니다.
INSERT INTO iter_perf.shipping (
    id,
    created_at,
    updated_at,
    carrier,
    delivered_at,
    rental_id,
    shipped_at,
    status,
    tracking_number,
    type
)
SELECT 100000 + rental.id,
       return_receipt.created_at,
       rental.updated_at,
       '성능택배',
       CASE
           WHEN rental.status IN ('RETURNED', 'DISPUTED', 'COMPLETED')
               THEN DATE_ADD(CAST(rental.end_date AS DATETIME), INTERVAL 1 DAY)
           ELSE NULL
       END,
       rental.id,
       CASE
           WHEN rental.status = 'RETURN_REQUESTED' THEN NULL
           ELSE DATE_ADD(CAST(rental.end_date AS DATETIME), INTERVAL 12 HOUR)
       END,
       CASE
           WHEN rental.status = 'RETURN_REQUESTED' THEN 'READY'
           WHEN rental.status = 'RETURNING' THEN 'IN_TRANSIT'
           ELSE 'DELIVERED'
       END,
       CASE
           WHEN rental.status = 'RETURN_REQUESTED' THEN NULL
           ELSE CONCAT('RET', LPAD(rental.id, 12, '0'))
       END,
       'RETURN'
FROM iter_perf.rental AS rental
JOIN iter_perf.return_receipt AS return_receipt
  ON return_receipt.rental_id = rental.id;
