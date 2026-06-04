-- ================================================================
-- 더미 데이터 (벤치마크 및 시연용)
-- ================================================================

-- ── 영화 (10편) ──────────────────────────────────────────────
INSERT INTO movies (title, genre, duration, rating, description) VALUES
('인터스텔라',              'SF/드라마',      169, '12세',    '블랙홀 너머 인류의 새로운 고향을 찾아 떠나는 우주 탐험 이야기'),
('어벤져스: 엔드게임',      '액션/SF',        181, '12세',    '타노스에 맞서 우주를 구하기 위한 어벤져스의 최후 결전'),
('기생충',                  '드라마/스릴러',  132, '15세',    '빈부 격차를 날카롭게 파헤친 봉준호 감독의 칸 황금종려상 수상작'),
('탑건: 매버릭',            '액션/드라마',    130, '12세',    '30년 만에 돌아온 매버릭의 전설적인 비행 스토리'),
('범죄도시 4',              '액션',           109, '15세',    '마동석 주연 범죄 액션 시리즈 네 번째 이야기'),
('오펜하이머',              '드라마/역사',    180, '15세',    '원자폭탄 개발 프로젝트를 이끈 물리학자 오펜하이머의 이야기'),
('바비',                    '코미디/판타지',  114, '12세',    '완벽한 바비랜드를 벗어나 현실 세계로 떠나는 바비의 모험'),
('엘리멘탈',               'SF/애니메이션', 101, '전체관람가','불·물·땅·바람 원소들이 공존하는 도시에서 펼쳐지는 사랑 이야기'),
('스파이더맨: 노 웨이 홈', '액션/SF',        148, '12세',    '멀티버스의 빌런들과 맞서는 피터 파커의 스파이더맨 이야기'),
('미션 임파서블: 데드 레코닝', '액션/스릴러', 163, '12세', '이단 헌트와 IMF 팀이 맞서는 인류 최후의 임무');

-- ── 상영관 (5개) ──────────────────────────────────────────────
INSERT INTO theaters (name, rows, cols) VALUES
('1관 (일반)',    8, 10),   -- 80석
('2관 (IMAX)',   10, 12),   -- 120석
('3관 (소극장)',  5,  8),   -- 40석
('4관 (4DX)',    6, 10),   -- 60석
('5관 (프리미엄)',4,  8);   -- 32석

-- ── 좌석 자동 생성 ────────────────────────────────────────────
DO $$
DECLARE
    t     RECORD;
    r     INT;
    c     INT;
    label TEXT;
BEGIN
    FOR t IN SELECT theater_id, rows, cols FROM theaters LOOP
        FOR r IN 1..t.rows LOOP
            FOR c IN 1..t.cols LOOP
                label := chr(64 + r) || c::TEXT;
                INSERT INTO seats (theater_id, row_num, col_num, seat_label)
                VALUES (t.theater_id, r, c, label)
                ON CONFLICT DO NOTHING;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- ── 상영 스케줄 (향후 2주, 40개) ─────────────────────────────
INSERT INTO screenings (movie_id, theater_id, show_time, price) VALUES
-- 인터스텔라 (1관/2관)
(1, 1, NOW() + INTERVAL '2 hours',                          13000),
(1, 1, NOW() + INTERVAL '1 day 10 hours',                   13000),
(1, 2, NOW() + INTERVAL '3 days 14 hours',                  18000),
(1, 2, NOW() + INTERVAL '7 days 10 hours',                  18000),
-- 어벤져스: 엔드게임 (2관/4관)
(2, 2, NOW() + INTERVAL '4 hours',                          18000),
(2, 2, NOW() + INTERVAL '2 days 13 hours',                  18000),
(2, 4, NOW() + INTERVAL '1 day 18 hours',                   16000),
(2, 4, NOW() + INTERVAL '5 days 20 hours',                  16000),
-- 기생충 (3관)
(3, 3, NOW() + INTERVAL '5 hours',                          11000),
(3, 3, NOW() + INTERVAL '1 day 15 hours',                   11000),
(3, 3, NOW() + INTERVAL '4 days 19 hours',                  11000),
-- 탑건: 매버릭 (1관/4관)
(4, 1, NOW() + INTERVAL '6 hours',                          13000),
(4, 1, NOW() + INTERVAL '2 days 16 hours',                  13000),
(4, 4, NOW() + INTERVAL '3 days 11 hours',                  16000),
(4, 4, NOW() + INTERVAL '8 days 14 hours',                  16000),
-- 범죄도시 4 (1관/3관)
(5, 1, NOW() + INTERVAL '8 hours',                          13000),
(5, 3, NOW() + INTERVAL '1 day 20 hours',                   11000),
(5, 1, NOW() + INTERVAL '6 days 17 hours',                  13000),
-- 오펜하이머 (2관/5관)
(6, 2, NOW() + INTERVAL '10 hours',                         18000),
(6, 5, NOW() + INTERVAL '2 days 11 hours',                  20000),
(6, 2, NOW() + INTERVAL '5 days 15 hours',                  18000),
(6, 5, NOW() + INTERVAL '9 days 10 hours',                  20000),
-- 바비 (3관/1관)
(7, 3, NOW() + INTERVAL '12 hours',                         11000),
(7, 1, NOW() + INTERVAL '3 days 13 hours',                  13000),
(7, 3, NOW() + INTERVAL '7 days 18 hours',                  11000),
-- 엘리멘탈 (3관/5관)
(8, 3, NOW() + INTERVAL '14 hours',                         11000),
(8, 5, NOW() + INTERVAL '1 day 12 hours',                   20000),
(8, 3, NOW() + INTERVAL '4 days 10 hours',                  11000),
-- 스파이더맨: 노 웨이 홈 (4관/2관)
(9, 4, NOW() + INTERVAL '3 hours',                          16000),
(9, 2, NOW() + INTERVAL '2 days 18 hours',                  18000),
(9, 4, NOW() + INTERVAL '6 days 13 hours',                  16000),
(9, 2, NOW() + INTERVAL '10 days 11 hours',                 18000),
-- 미션 임파서블 (1관/4관/5관)
(10, 1, NOW() + INTERVAL '7 hours',                         13000),
(10, 4, NOW() + INTERVAL '1 day 14 hours',                  16000),
(10, 5, NOW() + INTERVAL '3 days 19 hours',                 20000),
(10, 1, NOW() + INTERVAL '8 days 16 hours',                 13000),
(10, 4, NOW() + INTERVAL '11 days 12 hours',                16000),
(10, 5, NOW() + INTERVAL '13 days 10 hours',                20000);

-- ── 예약 더미 데이터 (약 200건) ───────────────────────────────
DO $$
DECLARE
    sc          RECORD;
    se          RECORD;
    names       TEXT[] := ARRAY[
        '김민준','이서연','박지호','최유진','정하늘',
        '강도현','윤소율','임재원','한지수','오승현',
        '신예은','배민혁','류아린','남궁철','황보름',
        '고은별','서태양','문정우','전수진','장민서',
        '권나래','백승우','추지혜','허동현','안소희',
        '노준혁','엄수빈','조현우','구나연','마준서'
    ];
    phones      TEXT[] := ARRAY[
        '010-1234-5678','010-2345-6789','010-3456-7890','010-4567-8901',
        '010-5678-9012','010-6789-0123','010-7890-1234','010-8901-2345',
        '010-9012-3456','010-0123-4567','010-1111-2222','010-2222-3333',
        '010-3333-4444','010-4444-5555','010-5555-6666','010-6666-7777',
        '010-7777-8888','010-8888-9999','010-9999-0000','010-1357-2468',
        '010-2468-1357','010-1122-3344','010-3344-5566','010-5566-7788',
        '010-7788-9900','010-9900-1122','010-1234-0000','010-0000-5678',
        '010-2580-1470','010-1470-2580'
    ];
    idx         INT := 0;
    seat_limit  INT;
    st_val      VARCHAR(20);
BEGIN
    FOR sc IN
        SELECT s.screening_id, t.rows * t.cols AS total_seats
        FROM   screenings s
        JOIN   theaters t USING (theater_id)
        ORDER  BY s.screening_id
    LOOP
        -- 각 상영에 대해 30~70% 좌석 예약
        seat_limit := GREATEST(3, (sc.total_seats * (30 + (RANDOM() * 40)::INT) / 100));

        FOR se IN
            SELECT se2.seat_id
            FROM   seats se2
            JOIN   theaters t2 ON se2.theater_id = t2.theater_id
            JOIN   screenings s2 ON s2.theater_id = t2.theater_id
            WHERE  s2.screening_id = sc.screening_id
            ORDER  BY RANDOM()
            LIMIT  seat_limit
        LOOP
            idx := idx + 1;
            -- 약 8% 확률로 cancelled 상태
            st_val := CASE WHEN RANDOM() < 0.08 THEN 'cancelled' ELSE 'confirmed' END;

            INSERT INTO reservations (screening_id, seat_id, booker_name, booker_phone, status)
            VALUES (
                sc.screening_id,
                se.seat_id,
                names[1 + (idx % array_length(names, 1))],
                phones[1 + (idx % array_length(phones, 1))],
                st_val
            )
            ON CONFLICT (screening_id, seat_id) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ── pgbench용 유효 슬롯 뷰 ────────────────────────────────────
-- run_benchmark.sh 에서 참조
CREATE OR REPLACE VIEW v_available_slots AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.screening_id, se.seat_id) AS slot_id,
    s.screening_id,
    se.seat_id
FROM   screenings s
JOIN   theaters t  USING (theater_id)
JOIN   seats    se ON se.theater_id = t.theater_id
LEFT JOIN reservations r
       ON r.screening_id = s.screening_id
      AND r.seat_id      = se.seat_id
      AND r.status       = 'confirmed'
WHERE  s.show_time > NOW()
  AND  r.reservation_id IS NULL;
