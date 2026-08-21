-- 대여 상태와 일관된 결제 10,000건을 생성합니다.
-- 결제가 완료된 진행 거래는 PAID, 등록자가 거절해 환불된 거래는 REFUNDED로 구성합니다.
INSERT INTO iter_perf.payment (
    id,
    created_at,
    updated_at,
    amount,
    paid_at,
    refunded_at,
    rental_id,
    status,
    cancel_idempotency_key,
    idempotency_key,
    order_id,
    payment_key
)
WITH payment_source AS (
    SELECT ROW_NUMBER() OVER (ORDER BY rental.id) AS payment_id,
           rental.*
    FROM iter_perf.rental AS rental
    WHERE rental.status NOT IN ('PENDING', 'CANCELED')
)
SELECT payment.payment_id,
       payment.created_at,
       CASE
           WHEN payment.status = 'REJECTED'
               THEN GREATEST(payment.created_at, payment.updated_at)
           ELSE LEAST(
               @seed_now,
               DATE_ADD(payment.created_at, INTERVAL 1 HOUR)
           )
       END,
       payment.total_price,
       CASE
           WHEN payment.status = 'REJECTED' THEN payment.created_at
           ELSE LEAST(
               @seed_now,
               DATE_ADD(payment.created_at, INTERVAL 1 HOUR)
           )
       END,
       CASE
           WHEN payment.status = 'REJECTED'
               THEN GREATEST(payment.created_at, payment.updated_at)
           ELSE NULL
       END,
       payment.id,
       CASE
           WHEN payment.status = 'REJECTED' THEN 'REFUNDED'
           ELSE 'PAID'
       END,
       CASE
           WHEN payment.status = 'REJECTED'
               THEN CONCAT('perf-cancel-', LPAD(payment.payment_id, 5, '0'))
           ELSE NULL
       END,
       CONCAT('perf-confirm-', LPAD(payment.payment_id, 5, '0')),
       CONCAT('PERF-ORDER-', LPAD(payment.payment_id, 5, '0')),
       CONCAT('perf-payment-key-', LPAD(payment.payment_id, 5, '0'))
FROM payment_source AS payment
WHERE payment.payment_id <= @seed_payment_count;

-- 일반 회원과 관리자가 조회할 신고 5,000건을 생성합니다.
-- 1번 신고는 user 2가 작성한 RECEIVED 신고로 유지해 사용자 상세과 관리자 상태 변경 경합에 함께 사용합니다.
INSERT INTO iter_perf.report (
    id,
    created_at,
    updated_at,
    admin_memo,
    description,
    reason,
    reporter_id,
    resolved_at,
    status,
    target_id,
    target_type
)
WITH report_number_source AS (
    SELECT numbers.n,
           CASE
               WHEN numbers.n = 1 THEN 'EQUIPMENT'
               WHEN MOD(numbers.n, 3) = 0 THEN 'USER'
               WHEN MOD(numbers.n, 3) = 1 THEN 'EQUIPMENT'
               ELSE 'RENTAL'
           END AS target_type,
           CASE
               WHEN numbers.n = 1 THEN 0
               ELSE FLOOR((numbers.n - 2) / 3)
           END AS target_sequence
    FROM seed_numbers AS numbers
    WHERE numbers.n <= @seed_report_count
),
report_target_source AS (
    SELECT source.n,
           source.target_type,
           source.target_sequence,
           CASE
               WHEN source.n = 1 THEN 3
               WHEN source.target_type = 'USER'
                   THEN 2 + MOD(source.target_sequence, 99)
               WHEN source.target_type = 'EQUIPMENT'
                   THEN 104 + 20 * MOD(source.target_sequence, 245)
               ELSE 1 + source.target_sequence
           END AS target_id
    FROM report_number_source AS source
),
report_party_source AS (
    SELECT target.n,
           target.target_type,
           target.target_sequence,
           target.target_id,
           CASE target.target_type
               WHEN 'USER' THEN target_user.created_at
               WHEN 'EQUIPMENT' THEN equipment.created_at
               ELSE rental.created_at
           END AS target_created_at,
           CASE
               WHEN target.n = 1 THEN 2
               WHEN target.target_type = 'USER'
                   THEN 2 + MOD(
                       MOD(target.target_sequence, 99)
                       + FLOOR(target.target_sequence / 99)
                       + 1,
                       99
                   )
               WHEN target.target_type = 'EQUIPMENT'
                   THEN 2 + MOD(
                       (equipment.owner_id - 2)
                       + FLOOR(target.target_sequence / 245)
                       + 1,
                       99
                   )
               WHEN MOD(target.n, 2) = 0 THEN rental.renter_id
               ELSE rental_equipment.owner_id
           END AS reporter_id
    FROM report_target_source AS target
    LEFT JOIN iter_perf.users AS target_user
      ON target.target_type = 'USER'
     AND target_user.id = target.target_id
    LEFT JOIN iter_perf.equipment AS equipment
      ON target.target_type = 'EQUIPMENT'
     AND equipment.id = target.target_id
    LEFT JOIN iter_perf.rental AS rental
      ON target.target_type = 'RENTAL'
     AND rental.id = target.target_id
    LEFT JOIN iter_perf.equipment AS rental_equipment
      ON rental_equipment.id = rental.equipment_id
),
report_status_source AS (
    SELECT party.*,
           CASE
               WHEN party.n = 1 THEN 'RECEIVED'
               WHEN MOD(party.n, 4) = 0 THEN 'RECEIVED'
               WHEN MOD(party.n, 4) = 1 THEN 'UNDER_REVIEW'
               WHEN MOD(party.n, 4) = 2 THEN 'RESOLVED'
               ELSE 'REJECTED'
           END AS report_status
    FROM report_party_source AS party
),
report_time_source AS (
    SELECT report.*,
           GREATEST(
               COALESCE(report.target_created_at, @seed_now),
               DATE_SUB(@seed_now, INTERVAL (1 + MOD(report.n, 365)) DAY)
           ) AS report_created_at
    FROM report_status_source AS report
)
SELECT report.n,
       report.report_created_at,
       GREATEST(
           report.report_created_at,
           DATE_SUB(@seed_now, INTERVAL MOD(report.n, 3600) SECOND)
       ),
       CASE
           WHEN report.report_status = 'UNDER_REVIEW' THEN '관리자 검토 중입니다.'
           WHEN report.report_status = 'RESOLVED' THEN '신고 처리를 완료했습니다.'
           WHEN report.report_status = 'REJECTED' THEN '검토 결과 신고를 기각했습니다.'
           ELSE NULL
       END,
       CONCAT('성능 테스트 신고 상세 설명 ', report.n),
       CASE report.target_type
           WHEN 'USER' THEN '회원 이용 정책 위반 신고'
           WHEN 'EQUIPMENT' THEN '장비 정보 이상 신고'
           ELSE '거래 과정 문제 신고'
       END,
       report.reporter_id,
       CASE
           WHEN report.report_status IN ('RESOLVED', 'REJECTED')
               THEN GREATEST(
                   report.report_created_at,
                   DATE_SUB(@seed_now, INTERVAL MOD(report.n, 3600) SECOND)
               )
           ELSE NULL
       END,
       report.report_status,
       report.target_id,
       report.target_type
FROM report_time_source AS report;

-- 관리자 조회 성능과 필터 조합을 확인할 처리 이력 5,000건을 생성합니다.
-- 1번 신고는 상태 변경 경합 fixture이므로 기존 처리 이력이 연결되지 않도록 REPORT 대상은 2번부터 사용합니다.
INSERT INTO iter_perf.admin_action (
    id,
    created_at,
    action,
    admin_id,
    reason,
    target_id,
    target_type
)
WITH dispute_target_source AS (
    SELECT dispute.id,
           ROW_NUMBER() OVER (ORDER BY dispute.id) AS dispute_sequence
    FROM iter_perf.dispute AS dispute
),
action_source AS (
    SELECT numbers.n,
           CASE MOD(numbers.n - 1, 8)
               WHEN 0 THEN 'SUSPEND_USER'
               WHEN 1 THEN 'RESTORE_USER'
               WHEN 2 THEN 'SUSPEND_EQUIPMENT'
               WHEN 3 THEN 'RESTORE_EQUIPMENT'
               WHEN 4 THEN 'REVIEW_REPORT'
               WHEN 5 THEN 'RESOLVE_REPORT'
               WHEN 6 THEN 'REJECT_REPORT'
               ELSE 'RESOLVE_DISPUTE'
           END AS action,
           CASE MOD(numbers.n - 1, 8)
               WHEN 0 THEN 'USER'
               WHEN 1 THEN 'USER'
               WHEN 2 THEN 'EQUIPMENT'
               WHEN 3 THEN 'EQUIPMENT'
               WHEN 4 THEN 'REPORT'
               WHEN 5 THEN 'REPORT'
               WHEN 6 THEN 'REPORT'
               ELSE 'DISPUTE'
           END AS target_type,
           CASE MOD(numbers.n - 1, 8)
               WHEN 0 THEN 101 + MOD(numbers.n, 900)
               WHEN 1 THEN 101 + MOD(numbers.n, 900)
               WHEN 2 THEN 101 + MOD(numbers.n, 4900)
               WHEN 3 THEN 101 + MOD(numbers.n, 4900)
               WHEN 4 THEN 2 + MOD(numbers.n - 1, 4999)
               WHEN 5 THEN 2 + MOD(numbers.n - 1, 4999)
               WHEN 6 THEN 2 + MOD(numbers.n - 1, 4999)
               ELSE dispute_target.id
           END AS target_id
    FROM seed_numbers AS numbers
    LEFT JOIN dispute_target_source AS dispute_target
      ON MOD(numbers.n - 1, 8) = 7
     AND dispute_target.dispute_sequence = 1 + MOD(FLOOR((numbers.n - 1) / 8), 500)
    WHERE numbers.n <= @seed_admin_action_count
),
action_target_source AS (
    SELECT action.*,
           CASE action.target_type
               WHEN 'USER' THEN target_user.created_at
               WHEN 'EQUIPMENT' THEN target_equipment.created_at
               WHEN 'REPORT' THEN target_report.created_at
               ELSE target_dispute.created_at
           END AS target_created_at
    FROM action_source AS action
    LEFT JOIN iter_perf.users AS target_user
      ON action.target_type = 'USER'
     AND target_user.id = action.target_id
    LEFT JOIN iter_perf.equipment AS target_equipment
      ON action.target_type = 'EQUIPMENT'
     AND target_equipment.id = action.target_id
    LEFT JOIN iter_perf.report AS target_report
      ON action.target_type = 'REPORT'
     AND target_report.id = action.target_id
    LEFT JOIN iter_perf.dispute AS target_dispute
      ON action.target_type = 'DISPUTE'
     AND target_dispute.id = action.target_id
)
SELECT action.n,
       GREATEST(
           DATE_SUB(@seed_now, INTERVAL MOD(action.n, 3600) SECOND),
           action.target_created_at
       ),
       action.action,
       1,
       CONCAT('성능 테스트 관리자 처리 사유 ', action.n),
       action.target_id,
       action.target_type
FROM action_target_source AS action;

-- 최신 dev의 알림 목록·미읽음 집계 API를 측정할 알림 5,000건을 생성합니다.
-- 알림 유형에 따라 실제 수신자(대여자 또는 장비 등록자)를 선택합니다.
INSERT INTO iter_perf.notification (
    id,
    created_at,
    receiver_id,
    type,
    title,
    message,
    rental_id,
    is_read,
    read_at
)
WITH notification_source AS (
    SELECT numbers.n,
           rental.id AS rental_id,
           rental.renter_id,
           rental.created_at AS rental_created_at,
           equipment.owner_id,
           CASE MOD(numbers.n - 1, 6)
               WHEN 0 THEN 'PAYMENT_COMPLETED_RENTER'
               WHEN 1 THEN 'PAYMENT_COMPLETED_OWNER'
               WHEN 2 THEN 'RENTAL_REQUESTED'
               WHEN 3 THEN 'RENTAL_APPROVED'
               WHEN 4 THEN 'RENTAL_REJECTED'
               ELSE 'RENTAL_CANCELED'
           END AS notification_type
    FROM seed_numbers AS numbers
    JOIN iter_perf.rental AS rental
      ON rental.id = 1 + MOD(numbers.n - 1, @seed_rental_count)
    JOIN iter_perf.equipment AS equipment
      ON equipment.id = rental.equipment_id
    WHERE numbers.n <= @seed_notification_count
),
notification_receiver_source AS (
    SELECT source.*,
           CASE source.notification_type
               WHEN 'PAYMENT_COMPLETED_RENTER' THEN source.renter_id
               WHEN 'RENTAL_APPROVED' THEN source.renter_id
               WHEN 'RENTAL_REJECTED' THEN source.renter_id
               ELSE source.owner_id
           END AS receiver_id,
           GREATEST(
               source.rental_created_at,
               DATE_SUB(@seed_now, INTERVAL MOD(source.n, 86400) SECOND)
           ) AS notification_created_at
    FROM notification_source AS source
)
SELECT source.n,
       source.notification_created_at,
       source.receiver_id,
       source.notification_type,
       CONCAT('성능 테스트 알림 ', source.n),
       CONCAT('대여 ', source.rental_id, '번 알림 메시지입니다.'),
       source.rental_id,
       CASE WHEN MOD(source.n, 3) = 1 THEN 0 ELSE 1 END,
       CASE
           WHEN MOD(source.n, 3) = 1 THEN NULL
           ELSE LEAST(
               @seed_now,
               DATE_ADD(source.notification_created_at, INTERVAL 1 MINUTE)
           )
       END
FROM notification_receiver_source AS source;
