-- 회원·장비·대여·증빙 데이터는 유지하고 결제·신고·관리자 이력·알림만 초기화합니다.
-- iter_perf 이외의 데이터베이스에는 영향을 주지 않도록 fully-qualified name을 사용합니다.
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE iter_perf.notification;
TRUNCATE TABLE iter_perf.payment;
TRUNCATE TABLE iter_perf.report;
TRUNCATE TABLE iter_perf.admin_action;

SET FOREIGN_KEY_CHECKS = 1;
