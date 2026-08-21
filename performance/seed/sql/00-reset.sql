-- 성능 테스트 전용 iter_perf 데이터만 초기화합니다.
-- 기존 개발 DB인 iter에는 영향을 주지 않도록 모든 테이블을 fully-qualified name으로 지정합니다.
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE iter_perf.notification;
TRUNCATE TABLE iter_perf.dispute_image;
TRUNCATE TABLE iter_perf.dispute_response;
TRUNCATE TABLE iter_perf.receipt_image;
TRUNCATE TABLE iter_perf.return_receipt_image;
TRUNCATE TABLE iter_perf.review;
TRUNCATE TABLE iter_perf.shipping;
TRUNCATE TABLE iter_perf.payment;
TRUNCATE TABLE iter_perf.receipt;
TRUNCATE TABLE iter_perf.return_receipt;
TRUNCATE TABLE iter_perf.dispute;
TRUNCATE TABLE iter_perf.report;
TRUNCATE TABLE iter_perf.admin_action;
TRUNCATE TABLE iter_perf.oauth_account;
TRUNCATE TABLE iter_perf.oauth_pending_token;
TRUNCATE TABLE iter_perf.refresh_token;
TRUNCATE TABLE iter_perf.user_address;
TRUNCATE TABLE iter_perf.rental;
TRUNCATE TABLE iter_perf.equipment_image_upload;
TRUNCATE TABLE iter_perf.equipment_image;
TRUNCATE TABLE iter_perf.equipment;
TRUNCATE TABLE iter_perf.users;

SET FOREIGN_KEY_CHECKS = 1;
