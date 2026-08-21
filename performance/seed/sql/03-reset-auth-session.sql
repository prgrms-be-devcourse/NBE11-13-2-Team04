-- 인증 세션 부하테스트를 같은 초기 상태에서 다시 실행할 때만 사용합니다.
-- 반드시 격리된 성능 테스트 DB iter_perf인지 확인하고 애플리케이션을 중지한 뒤 실행합니다.
TRUNCATE TABLE iter_perf.refresh_token;
