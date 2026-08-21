-- 회원·장비 seed는 유지하고 대여 및 그 하위 데이터만 다시 만들기 위한 초기화입니다.
-- 이후 단계의 결제·신고 데이터가 이미 있다면 함께 초기화되므로 rental seed 전용 단계에서만 실행합니다.
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
TRUNCATE TABLE iter_perf.rental;

SET FOREIGN_KEY_CHECKS = 1;
