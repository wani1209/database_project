-- ================================================================
-- pgbench 워크로드: 2PL (Two-Phase Locking)
-- 메커니즘: READ COMMITTED + SELECT ... FOR UPDATE (명시적 행 잠금)
-- 사전 준비: run_benchmark.sh 가 pgbench_slots 테이블을 생성하고
--            -D slot_count=N 으로 슬롯 수를 전달함
-- ================================================================

\set slot_id  random(1, :slot_count)
\set uid      random(10000, 99999)

-- 트랜잭션 외부: 유효한 (screening_id, seat_id) 쌍 조회
SELECT screening_id, seat_id FROM pgbench_slots WHERE slot_id = :slot_id \gset

BEGIN;

-- Phase 1 (Growing): FOR UPDATE 로 행 잠금 획득
SELECT r.reservation_id
FROM   reservations r
WHERE  r.screening_id = :screening_id
  AND  r.seat_id      = :seat_id
  AND  r.status       = 'confirmed'
FOR UPDATE;

-- 잠금 보유 중 삽입 (이미 예약된 경우 DO NOTHING)
INSERT INTO reservations (screening_id, seat_id, booker_name, booker_phone)
VALUES (:screening_id, :seat_id,
        'pgbench_2pl_' || :uid,
        '010-' || :uid || '-0000')
ON CONFLICT (screening_id, seat_id) DO NOTHING;

-- Phase 2 (Shrinking): COMMIT 시 잠금 전체 해제
COMMIT;
