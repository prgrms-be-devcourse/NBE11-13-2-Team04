-- 이전 성능 DB 스키마를 최신 dev 엔티티와 맞추는 1회성 스크립트입니다.
-- 반드시 iter_perf에서만 실행하고, 실행 후 전체 seed를 다시 생성합니다.
USE iter_perf;

ALTER TABLE iter_perf.equipment_image
    ADD COLUMN object_key VARCHAR(500) NULL AFTER image_url;

ALTER TABLE iter_perf.users
    ADD COLUMN deleted_at DATETIME(6) NULL AFTER updated_at;

CREATE TABLE iter_perf.equipment_image_upload (
    id BIGINT NOT NULL AUTO_INCREMENT,
    created_at DATETIME(6) NULL,
    user_id BIGINT NOT NULL,
    object_key VARCHAR(500) NOT NULL,
    expected_content_type VARCHAR(50) NOT NULL,
    expected_size BIGINT NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    used_at DATETIME(6) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_equipment_image_upload_object_key (object_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE iter_perf.notification (
    id BIGINT NOT NULL AUTO_INCREMENT,
    created_at DATETIME(6) NULL,
    receiver_id BIGINT NOT NULL,
    type ENUM(
        'PAYMENT_COMPLETED_OWNER',
        'PAYMENT_COMPLETED_RENTER',
        'RENTAL_REQUESTED',
        'RENTAL_APPROVED',
        'RENTAL_REJECTED',
        'RENTAL_CANCELED'
    ) NOT NULL,
    title VARCHAR(100) NOT NULL,
    message VARCHAR(500) NOT NULL,
    rental_id BIGINT NOT NULL,
    is_read BIT(1) NOT NULL,
    read_at DATETIME(6) NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'iter_perf'
  AND table_name = 'equipment_image'
  AND column_name = 'object_key';

SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'iter_perf'
  AND table_name = 'users'
  AND column_name = 'deleted_at';

SHOW TABLES FROM iter_perf LIKE 'equipment_image_upload';
SHOW TABLES FROM iter_perf LIKE 'notification';
