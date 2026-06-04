-- ================================================================
-- pgbench 워크로드: SSI (Serializable Snapshot Isolation)
-- 메커니즘: SERIALIZABLE 격리 수준, FOR UPDATE 없음
--           PostgreSQL 이 읽기/쓰기 의존성 추적 → 커밋 시 충돌 감지
-- 사전 준비: run_benchmark.sh 가 pgbench_slots 테이블을 생성하고
--            -D slot_count=N 으로 슬롯 수를 전달함
-- ================================================================

\set slot_id  random(1, :slot_count)
\set uid      random(10000, 99999)

-- 트랜잭션 외부: 유효한 (screening_id, seat_id) 쌍 조회
SELECT screening_id, seat_id FROM pgbench_slots WHERE slot_id = :slot_id \gset

BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- 낙관적 읽기 (잠금 없음) — PostgreSQL 이 read set 추적
SELECT r.reservation_id
FROM   reservations r
WHERE  r.screening_id = :screening_id
  AND  r.seat_id      = :seat_id
  AND  r.status       = 'confirmed';

-- 삽입 시도
INSERT INTO reservations (screening_id, seat_id, booker_name, booker_phone)
VALUES (:screening_id, :seat_id,
        'pgbench_ssi_' || :uid,
        '010-' || :uid || '-1111')
ON CONFLICT (screening_id, seat_id) DO NOTHING;

-- COMMIT: SSI 의존성 사이클 최종 검사
-- 충돌 시 → ERROR 40001 (serialization_failure) → pgbench 가 재시도 통계에 기록
COMMIT;
