-- 대여 및 증빙 seed의 수량·관계·고정 fixture를 확인합니다.
SELECT 'rental' AS table_name,
       COUNT(*) AS actual_count,
       @seed_rental_count AS expected_count
FROM iter_perf.rental;

SELECT status,
       COUNT(*) AS actual_count,
       CASE status
           WHEN 'PENDING' THEN 8000
           WHEN 'CANCELED' THEN 2000
           WHEN 'REQUESTED' THEN 1000
           WHEN 'APPROVED' THEN 999
           WHEN 'REJECTED' THEN 999
           WHEN 'SHIPPING' THEN 999
           WHEN 'RECEIVED' THEN 999
           WHEN 'RENTING' THEN 1001
           WHEN 'RETURN_REQUESTED' THEN 1000
           WHEN 'RETURNING' THEN 1001
           WHEN 'RETURNED' THEN 1001
           WHEN 'DISPUTED' THEN 500
           WHEN 'COMPLETED' THEN 501
       END AS expected_count
FROM iter_perf.rental
GROUP BY status
ORDER BY status;

SELECT 'receipt' AS table_name,
       (SELECT COUNT(*) FROM iter_perf.receipt) AS actual_count,
       COUNT(*) AS expected_count
FROM iter_perf.rental
WHERE status IN (
    'RECEIVED', 'RENTING', 'RETURN_REQUESTED', 'RETURNING',
    'RETURNED', 'DISPUTED', 'COMPLETED'
);

SELECT 'return_receipt' AS table_name,
       (SELECT COUNT(*) FROM iter_perf.return_receipt) AS actual_count,
       COUNT(*) AS expected_count
FROM iter_perf.rental
WHERE status IN (
    'RETURN_REQUESTED', 'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
);

SELECT 'receipt_image' AS table_name,
       (SELECT COUNT(*) FROM iter_perf.receipt_image) AS actual_count,
       (SELECT COUNT(*) FROM iter_perf.receipt) AS expected_count
UNION ALL
SELECT 'return_receipt_image',
       (SELECT COUNT(*) FROM iter_perf.return_receipt_image),
       (SELECT COUNT(*) FROM iter_perf.return_receipt);

SELECT 'dispute' AS table_name,
       (SELECT COUNT(*) FROM iter_perf.dispute) AS actual_count,
       (SELECT COUNT(*) FROM iter_perf.rental WHERE status = 'DISPUTED') AS expected_count
UNION ALL
SELECT 'dispute_image',
       (SELECT COUNT(*) FROM iter_perf.dispute_image),
       (SELECT COUNT(*) FROM iter_perf.dispute);

SELECT 'shipping' AS table_name,
       COUNT(*) AS actual_count,
       (
           SELECT COUNT(*)
           FROM iter_perf.rental
           WHERE status IN (
               'APPROVED', 'SHIPPING', 'RECEIVED', 'RENTING', 'RETURN_REQUESTED',
               'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
           )
       ) + (
           SELECT COUNT(*)
           FROM iter_perf.rental
           WHERE status IN (
               'RETURN_REQUESTED', 'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
           )
       ) AS expected_count
FROM iter_perf.shipping;

SELECT
    SUM(CASE WHEN status NOT IN ('PENDING', 'CANCELED') THEN 1 ELSE 0 END)
        AS payment_seed_target_count,
    @seed_payment_count AS expected_payment_seed_target_count,
    SUM(CASE
            WHEN status = 'PENDING'
             AND created_at < DATE_SUB(@seed_now, INTERVAL 30 MINUTE)
            THEN 1
            ELSE 0
        END) AS already_expired_pending_count
FROM iter_perf.rental;

-- 값 참조형 Rental 구조에서도 모든 대여가 실제 회원과 장비를 가리키는지 확인합니다.
SELECT
    SUM(CASE WHEN users.id IS NULL THEN 1 ELSE 0 END) AS missing_renter_count,
    SUM(CASE WHEN equipment.id IS NULL THEN 1 ELSE 0 END) AS missing_equipment_count,
    SUM(CASE
            WHEN rental.renter_id = equipment.owner_id THEN 1
            ELSE 0
        END) AS self_rental_count,
    SUM(CASE
            WHEN rental.product_name_snapshot <> equipment.name
              OR rental.category_snapshot <> equipment.category
              OR rental.daily_price_snapshot <> equipment.daily_price
            THEN 1
            ELSE 0
        END) AS snapshot_mismatch_count
FROM iter_perf.rental AS rental
LEFT JOIN iter_perf.users AS users
  ON users.id = rental.renter_id
LEFT JOIN iter_perf.equipment AS equipment
  ON equipment.id = rental.equipment_id;

SELECT
    SUM(CASE WHEN start_date > end_date THEN 1 ELSE 0 END) AS invalid_date_count,
    SUM(CASE WHEN rental_days <> DATEDIFF(end_date, start_date) + 1 THEN 1 ELSE 0 END)
        AS invalid_rental_days_count,
    SUM(CASE WHEN total_price <> daily_price_snapshot * rental_days THEN 1 ELSE 0 END)
        AS invalid_total_price_count,
    SUM(CASE WHEN version <> 0 THEN 1 ELSE 0 END) AS invalid_version_count
FROM iter_perf.rental;

SELECT
    SUM(CASE
            WHEN created_at > CAST(start_date AS DATETIME) THEN 1
            ELSE 0
        END) AS created_after_start_count,
    SUM(CASE
            WHEN approved_at IS NOT NULL
             AND approved_at > CAST(start_date AS DATETIME) THEN 1
            ELSE 0
        END) AS approved_after_start_count,
    SUM(CASE
            WHEN updated_at < created_at THEN 1
            ELSE 0
        END) AS updated_before_created_count
FROM iter_perf.rental;

SELECT COUNT(*) AS active_period_overlap_pair_count
FROM iter_perf.rental AS first_rental
JOIN iter_perf.rental AS second_rental
  ON first_rental.equipment_id = second_rental.equipment_id
 AND first_rental.id < second_rental.id
 AND first_rental.start_date <= second_rental.end_date
 AND first_rental.end_date >= second_rental.start_date
WHERE first_rental.status NOT IN ('REJECTED', 'CANCELED')
  AND second_rental.status NOT IN ('REJECTED', 'CANCELED');

SELECT
    SUM(CASE
            WHEN rental.status IN (
                'RECEIVED', 'RENTING', 'RETURN_REQUESTED', 'RETURNING',
                'RETURNED', 'DISPUTED', 'COMPLETED'
            ) AND receipt.id IS NULL THEN 1
            ELSE 0
        END) AS missing_receipt_count,
    SUM(CASE
            WHEN rental.status IN (
                'RETURN_REQUESTED', 'RETURNING', 'RETURNED', 'DISPUTED', 'COMPLETED'
            ) AND return_receipt.id IS NULL THEN 1
            ELSE 0
        END) AS missing_return_receipt_count
FROM iter_perf.rental AS rental
LEFT JOIN iter_perf.receipt AS receipt
  ON receipt.rental_id = rental.id
LEFT JOIN iter_perf.return_receipt AS return_receipt
  ON return_receipt.rental_id = rental.id;

-- 고정 fixture 1~6: 상세, 반납 확인, 승인, 연체, 결제 준비 시나리오입니다.
SELECT rental.id,
       rental.equipment_id,
       equipment.owner_id,
       rental.renter_id,
       rental.status,
       rental.start_date,
       rental.end_date,
       receipt.id AS receipt_id,
       return_receipt.id AS return_receipt_id
FROM iter_perf.rental AS rental
JOIN iter_perf.equipment AS equipment
  ON equipment.id = rental.equipment_id
LEFT JOIN iter_perf.receipt AS receipt
  ON receipt.rental_id = rental.id
LEFT JOIN iter_perf.return_receipt AS return_receipt
  ON return_receipt.rental_id = rental.id
WHERE rental.id BETWEEN 1 AND 6
ORDER BY rental.id;

SELECT
    SUM(CASE
            WHEN rental.id = 1
             AND rental.equipment_id = 1
             AND rental.renter_id = 2
             AND rental.status = 'COMPLETED'
             AND receipt.id IS NOT NULL
             AND return_receipt.id IS NOT NULL THEN 0
            WHEN rental.id = 2
             AND rental.equipment_id = 2
             AND equipment.owner_id = 3
             AND rental.renter_id = 2
             AND rental.status = 'RETURNED'
             AND receipt.id IS NOT NULL
             AND return_receipt.id IS NOT NULL THEN 0
            WHEN rental.id = 3
             AND rental.equipment_id = 3
             AND equipment.owner_id = 3
             AND rental.renter_id = 2
             AND rental.status = 'REQUESTED' THEN 0
            WHEN rental.id = 4
             AND rental.equipment_id = 7
             AND rental.renter_id = 2
             AND rental.status = 'RENTING'
             AND rental.end_date < @seed_today THEN 0
            WHEN rental.id = 5
             AND rental.equipment_id = 8
             AND rental.renter_id = 2
             AND rental.status = 'RETURNING'
             AND rental.end_date < @seed_today THEN 0
            WHEN rental.id = 6
             AND rental.equipment_id = 6
             AND rental.renter_id = 2
             AND rental.status = 'PENDING'
             AND rental.created_at >= DATE_SUB(@seed_now, INTERVAL 30 MINUTE) THEN 0
            ELSE 1
        END) AS invalid_fixed_fixture_count
FROM iter_perf.rental AS rental
JOIN iter_perf.equipment AS equipment
  ON equipment.id = rental.equipment_id
LEFT JOIN iter_perf.receipt AS receipt
  ON receipt.rental_id = rental.id
LEFT JOIN iter_perf.return_receipt AS return_receipt
  ON return_receipt.rental_id = rental.id
WHERE rental.id BETWEEN 1 AND 6;

SELECT equipment_id,
       COUNT(*) AS fixed_equipment_rental_count
FROM iter_perf.rental
WHERE id BETWEEN 1 AND 6
GROUP BY equipment_id
ORDER BY equipment_id;

-- 기본 성능 사용자 2번의 이력과 연체 목록이 비어 있지 않은지 확인합니다.
SELECT
    SUM(CASE WHEN rental.renter_id = 2 THEN 1 ELSE 0 END) AS borrowed_count,
    SUM(CASE WHEN equipment.owner_id = 2 THEN 1 ELSE 0 END) AS lent_count,
    SUM(CASE
            WHEN rental.renter_id = 2
             AND rental.end_date < @seed_today
             AND rental.status IN ('RECEIVED', 'RENTING', 'RETURN_REQUESTED', 'RETURNING')
            THEN 1
            ELSE 0
        END) AS borrowed_overdue_count,
    SUM(CASE
            WHEN equipment.owner_id = 2
             AND rental.end_date < @seed_today
             AND rental.status IN ('RECEIVED', 'RENTING', 'RETURN_REQUESTED', 'RETURNING')
            THEN 1
            ELSE 0
        END) AS lent_overdue_count
FROM iter_perf.rental AS rental
JOIN iter_perf.equipment AS equipment
  ON equipment.id = rental.equipment_id;
