-- 결제·신고·관리자 처리 이력·알림 seed의 수량과 참조 무결성을 확인합니다.
SELECT 'payment' AS table_name,
       COUNT(*) AS actual_count,
       @seed_payment_count AS expected_count
FROM iter_perf.payment;

SELECT payment.status,
       COUNT(*) AS actual_count,
       CASE payment.status
           WHEN 'PAID' THEN 9001
           WHEN 'REFUNDED' THEN 999
           ELSE 0
       END AS expected_count
FROM iter_perf.payment AS payment
GROUP BY payment.status
ORDER BY payment.status;

SELECT SUM(CASE WHEN rental.id IS NULL THEN 1 ELSE 0 END) AS missing_rental_count,
       SUM(CASE WHEN renter.id IS NULL THEN 1 ELSE 0 END) AS missing_renter_count,
       SUM(CASE WHEN payment.amount <> rental.total_price THEN 1 ELSE 0 END) AS amount_mismatch_count,
       SUM(CASE
               WHEN rental.status = 'REJECTED' AND payment.status <> 'REFUNDED' THEN 1
               WHEN rental.status <> 'REJECTED' AND payment.status <> 'PAID' THEN 1
               ELSE 0
           END) AS payment_status_mismatch_count,
       SUM(CASE
               WHEN payment.order_id IS NULL
                 OR payment.idempotency_key IS NULL
                 OR payment.payment_key IS NULL
                 OR payment.paid_at IS NULL THEN 1
               ELSE 0
           END)
           AS missing_payment_key_data_count,
       SUM(CASE
               WHEN payment.updated_at < payment.created_at THEN 1
               WHEN payment.paid_at < payment.created_at THEN 1
               WHEN payment.refunded_at IS NOT NULL
                AND payment.refunded_at < payment.paid_at THEN 1
               ELSE 0
           END) AS invalid_payment_timestamp_count
FROM iter_perf.payment AS payment
LEFT JOIN iter_perf.rental AS rental
  ON rental.id = payment.rental_id
LEFT JOIN iter_perf.users AS renter
  ON renter.id = rental.renter_id;

SELECT payment.id,
       payment.rental_id,
       rental.renter_id,
       payment.status AS payment_status,
       rental.status AS rental_status,
       payment.amount
FROM iter_perf.payment AS payment
JOIN iter_perf.rental AS rental
  ON rental.id = payment.rental_id
WHERE payment.id = 1;

SELECT COUNT(*) AS payment_ready_fixture_payment_count,
       0 AS expected_count
FROM iter_perf.payment
WHERE rental_id = 6;

SELECT 'report' AS table_name,
       COUNT(*) AS actual_count,
       @seed_report_count AS expected_count
FROM iter_perf.report;

SELECT report.status,
       COUNT(*) AS actual_count,
       CASE report.status
           WHEN 'RECEIVED' THEN 1251
           WHEN 'UNDER_REVIEW' THEN 1249
           WHEN 'RESOLVED' THEN 1250
           WHEN 'REJECTED' THEN 1250
       END AS expected_count
FROM iter_perf.report AS report
GROUP BY report.status
ORDER BY report.status;

SELECT report.target_type,
       COUNT(*) AS report_count
FROM iter_perf.report AS report
GROUP BY report.target_type
ORDER BY report.target_type;

SELECT SUM(CASE WHEN reporter.id IS NULL THEN 1 ELSE 0 END) AS missing_reporter_count,
       SUM(CASE WHEN reporter.status <> 'ACTIVE' THEN 1 ELSE 0 END) AS inactive_reporter_count,
       SUM(CASE
               WHEN report.target_type = 'USER'
                AND (target_user.id IS NULL OR target_user.status = 'DELETED') THEN 1
               WHEN report.target_type = 'EQUIPMENT'
                AND (target_equipment.id IS NULL OR target_equipment.status = 'DELETED') THEN 1
               WHEN report.target_type = 'RENTAL'
                AND (target_rental.id IS NULL OR rental_equipment.id IS NULL) THEN 1
               ELSE 0
           END) AS missing_or_deleted_target_count,
       SUM(CASE
               WHEN report.target_type = 'USER'
                AND report.reporter_id = report.target_id THEN 1
               WHEN report.target_type = 'EQUIPMENT'
                AND report.reporter_id = target_equipment.owner_id THEN 1
               ELSE 0
           END) AS self_report_count,
       SUM(CASE
               WHEN report.target_type = 'RENTAL'
                AND report.reporter_id <> target_rental.renter_id
                AND report.reporter_id <> rental_equipment.owner_id THEN 1
               ELSE 0
           END) AS rental_non_party_report_count,
       SUM(CASE
               WHEN report.target_type = 'USER'
                AND report.created_at < target_user.created_at THEN 1
               WHEN report.target_type = 'EQUIPMENT'
                AND report.created_at < target_equipment.created_at THEN 1
               WHEN report.target_type = 'RENTAL'
                AND report.created_at < target_rental.created_at THEN 1
               ELSE 0
           END) AS report_before_target_count,
       SUM(CASE
               WHEN report.updated_at < report.created_at THEN 1
               WHEN report.resolved_at IS NOT NULL
                AND report.resolved_at < report.created_at THEN 1
               ELSE 0
           END) AS invalid_report_timestamp_count,
       SUM(CASE
               WHEN report.status IN ('RESOLVED', 'REJECTED')
                AND report.resolved_at IS NULL THEN 1
               WHEN report.status IN ('RECEIVED', 'UNDER_REVIEW')
                AND report.resolved_at IS NOT NULL THEN 1
               ELSE 0
           END) AS invalid_report_resolution_count
FROM iter_perf.report AS report
LEFT JOIN iter_perf.users AS reporter
  ON reporter.id = report.reporter_id
LEFT JOIN iter_perf.users AS target_user
  ON report.target_type = 'USER'
 AND target_user.id = report.target_id
LEFT JOIN iter_perf.equipment AS target_equipment
  ON report.target_type = 'EQUIPMENT'
 AND target_equipment.id = report.target_id
LEFT JOIN iter_perf.rental AS target_rental
  ON report.target_type = 'RENTAL'
 AND target_rental.id = report.target_id
LEFT JOIN iter_perf.equipment AS rental_equipment
  ON rental_equipment.id = target_rental.equipment_id;

SELECT COUNT(*) AS duplicate_active_report_group_count
FROM (
    SELECT reporter_id,
           target_type,
           target_id
    FROM iter_perf.report
    WHERE status IN ('RECEIVED', 'UNDER_REVIEW')
    GROUP BY reporter_id, target_type, target_id
    HAVING COUNT(*) > 1
) AS duplicated_report;

SELECT id,
       reporter_id,
       target_type,
       target_id,
       status
FROM iter_perf.report
WHERE id = 1;

SELECT CASE
           WHEN EXISTS (
               SELECT 1
               FROM iter_perf.report
               WHERE id = 1
                 AND reporter_id = 2
                 AND target_type = 'EQUIPMENT'
                 AND target_id = 3
                 AND status = 'RECEIVED'
           ) THEN 0
           ELSE 1
       END AS invalid_fixed_report_count;

SELECT COUNT(*) AS existing_duplicate_concurrency_report_count,
       0 AS expected_count
FROM iter_perf.report
WHERE reporter_id = 4
  AND target_type = 'EQUIPMENT'
  AND target_id = 3
  AND status IN ('RECEIVED', 'UNDER_REVIEW');

SELECT 'admin_action' AS table_name,
       COUNT(*) AS actual_count,
       @seed_admin_action_count AS expected_count
FROM iter_perf.admin_action;

SELECT action.target_type,
       action.action,
       COUNT(*) AS action_count
FROM iter_perf.admin_action AS action
GROUP BY action.target_type, action.action
ORDER BY action.target_type, action.action;

SELECT SUM(CASE WHEN admin.id IS NULL OR admin.role <> 'ADMIN' THEN 1 ELSE 0 END)
           AS invalid_admin_count,
       SUM(CASE
               WHEN action.target_type = 'USER' AND target_user.id IS NULL THEN 1
               WHEN action.target_type = 'EQUIPMENT' AND target_equipment.id IS NULL THEN 1
               WHEN action.target_type = 'REPORT' AND target_report.id IS NULL THEN 1
               WHEN action.target_type = 'DISPUTE' AND target_dispute.id IS NULL THEN 1
               ELSE 0
           END) AS missing_action_target_count,
       SUM(CASE
               WHEN action.target_type = 'USER'
                AND action.action NOT IN ('SUSPEND_USER', 'RESTORE_USER') THEN 1
               WHEN action.target_type = 'EQUIPMENT'
                AND action.action NOT IN ('SUSPEND_EQUIPMENT', 'RESTORE_EQUIPMENT') THEN 1
               WHEN action.target_type = 'REPORT'
                AND action.action NOT IN ('REVIEW_REPORT', 'RESOLVE_REPORT', 'REJECT_REPORT') THEN 1
               WHEN action.target_type = 'DISPUTE'
                AND action.action <> 'RESOLVE_DISPUTE' THEN 1
               ELSE 0
           END) AS action_target_type_mismatch_count,
       SUM(CASE
               WHEN action.target_type = 'USER'
                AND action.created_at < target_user.created_at THEN 1
               WHEN action.target_type = 'EQUIPMENT'
                AND action.created_at < target_equipment.created_at THEN 1
               WHEN action.target_type = 'REPORT'
                AND action.created_at < target_report.created_at THEN 1
               WHEN action.target_type = 'DISPUTE'
                AND action.created_at < target_dispute.created_at THEN 1
               ELSE 0
           END) AS action_before_target_count
FROM iter_perf.admin_action AS action
LEFT JOIN iter_perf.users AS admin
  ON admin.id = action.admin_id
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
 AND target_dispute.id = action.target_id;

SELECT COUNT(*) AS fixed_report_existing_action_count,
       0 AS expected_count
FROM iter_perf.admin_action
WHERE target_type = 'REPORT'
  AND target_id = 1;

SELECT 'notification' AS table_name,
       COUNT(*) AS actual_count,
       @seed_notification_count AS expected_count
FROM iter_perf.notification;

SELECT notification.type,
       COUNT(*) AS notification_count
FROM iter_perf.notification AS notification
GROUP BY notification.type
ORDER BY notification.type;

SELECT SUM(CASE WHEN receiver.id IS NULL THEN 1 ELSE 0 END) AS missing_receiver_count,
       SUM(CASE WHEN rental.id IS NULL THEN 1 ELSE 0 END) AS missing_rental_count,
       SUM(CASE
               WHEN notification.is_read = 0 AND notification.read_at IS NOT NULL THEN 1
               WHEN notification.is_read = 1 AND notification.read_at IS NULL THEN 1
               ELSE 0
           END) AS invalid_read_state_count,
       SUM(CASE
               WHEN notification.read_at IS NOT NULL
                AND notification.read_at < notification.created_at THEN 1
               ELSE 0
           END) AS invalid_read_timestamp_count
FROM iter_perf.notification AS notification
LEFT JOIN iter_perf.users AS receiver
  ON receiver.id = notification.receiver_id
LEFT JOIN iter_perf.rental AS rental
  ON rental.id = notification.rental_id;

SELECT id,
       receiver_id,
       type,
       rental_id,
       is_read
FROM iter_perf.notification
WHERE id = 1;

SELECT CASE
           WHEN EXISTS (
               SELECT 1
               FROM iter_perf.notification
               WHERE id = 1
                 AND receiver_id = 2
                 AND type = 'PAYMENT_COMPLETED_RENTER'
                 AND rental_id = 1
                 AND is_read = 0
           ) THEN 0
           ELSE 1
       END AS invalid_fixed_notification_count;
