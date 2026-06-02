-- ================================================================
-- 샘플 데이터 삽입
-- ================================================================

-- 영화 데이터
INSERT INTO movies (title, genre, duration, rating, description) VALUES
('인터스텔라',   'SF/드라마',  169, '12세', '블랙홀 너머 인류의 새로운 고향을 찾아 떠나는 우주 탐험 이야기'),
('어벤져스: 엔드게임', '액션/SF', 181, '12세', '타노스에 맞서 우주를 구하기 위한 어벤져스의 최후 결전'),
('기생충',       '드라마/스릴러', 132, '15세', '빈부 격차를 날카롭게 파헤친 봉준호 감독의 칸 황금종려상 수상작'),
('탑건: 매버릭', '액션/드라마',  130, '12세', '30년 만에 돌아온 매버릭의 전설적인 비행 스토리'),
('범죄도시 4',   '액션',       109, '15세', '마동석 주연 범죄 액션 시리즈 네 번째 이야기');

-- 상영관 데이터
INSERT INTO theaters (name, rows, cols) VALUES
('1관 (일반)',   8, 10),  -- 80석
('2관 (IMAX)',  10, 12),  -- 120석
('3관 (소극장)',  5,  8);  -- 40석

-- 좌석 데이터 생성 (각 상영관의 rows × cols 좌석 자동 생성)
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
                label := chr(64 + r) || c::TEXT;  -- A1, A2, ... H10 형식
                INSERT INTO seats (theater_id, row_num, col_num, seat_label)
                VALUES (t.theater_id, r, c, label);
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- 상영 스케줄 데이터 (오늘부터 3일간)
INSERT INTO screenings (movie_id, theater_id, show_time, price) VALUES
-- 인터스텔라 (1관)
(1, 1, NOW() + INTERVAL '2 hours',  13000),
(1, 1, NOW() + INTERVAL '6 hours',  13000),
(1, 2, NOW() + INTERVAL '1 day' + INTERVAL '10 hours', 18000),
-- 어벤져스 (2관 IMAX)
(2, 2, NOW() + INTERVAL '3 hours',  18000),
(2, 2, NOW() + INTERVAL '1 day' + INTERVAL '14 hours', 18000),
-- 기생충 (3관 소극장)
(3, 3, NOW() + INTERVAL '4 hours',  11000),
(3, 3, NOW() + INTERVAL '1 day' + INTERVAL '18 hours', 11000),
-- 탑건 (1관)
(4, 1, NOW() + INTERVAL '5 hours',  13000),
(4, 2, NOW() + INTERVAL '2 days' + INTERVAL '12 hours', 18000),
-- 범죄도시4 (1관)
(5, 1, NOW() + INTERVAL '8 hours',  13000),
(5, 3, NOW() + INTERVAL '2 days' + INTERVAL '15 hours', 11000);
