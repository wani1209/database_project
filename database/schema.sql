-- ================================================================
-- 영화관 좌석 예약 시스템 스키마
-- PostgreSQL 활용 예시: Relations, Queries, Transactions
-- ================================================================

-- 영화 테이블
CREATE TABLE movies (
    movie_id   SERIAL PRIMARY KEY,
    title      VARCHAR(200) NOT NULL,
    genre      VARCHAR(50)  NOT NULL,
    duration   INT          NOT NULL,  -- 분 단위
    rating     VARCHAR(10)  NOT NULL,  -- 12세, 15세, 청불, 전체관람가
    description TEXT
);

-- 상영관 테이블
CREATE TABLE theaters (
    theater_id  SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    rows        INT NOT NULL,  -- 행 수
    cols        INT NOT NULL   -- 열 수 (rows * cols = 총 좌석 수)
);

-- 상영 스케줄 테이블 (movies + theaters 를 연결하는 관계)
CREATE TABLE screenings (
    screening_id SERIAL PRIMARY KEY,
    movie_id     INT  NOT NULL REFERENCES movies(movie_id) ON DELETE CASCADE,
    theater_id   INT  NOT NULL REFERENCES theaters(theater_id) ON DELETE CASCADE,
    show_time    TIMESTAMP NOT NULL,
    price        INT NOT NULL  -- 원 단위
);

-- 좌석 테이블 (각 상영관의 고정 좌석)
CREATE TABLE seats (
    seat_id    SERIAL PRIMARY KEY,
    theater_id INT NOT NULL REFERENCES theaters(theater_id) ON DELETE CASCADE,
    row_num    INT NOT NULL,   -- 1부터 시작
    col_num    INT NOT NULL,   -- 1부터 시작
    seat_label VARCHAR(10) NOT NULL,  -- 예: A1, B3
    UNIQUE (theater_id, row_num, col_num)
);

-- 예약 테이블 (핵심 트랜잭션 대상)
CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    screening_id   INT         NOT NULL REFERENCES screenings(screening_id) ON DELETE CASCADE,
    seat_id        INT         NOT NULL REFERENCES seats(seat_id) ON DELETE CASCADE,
    booker_name    VARCHAR(100) NOT NULL,
    booker_phone   VARCHAR(20)  NOT NULL,
    reserved_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    status         VARCHAR(20)  NOT NULL DEFAULT 'confirmed',  -- confirmed / cancelled
    UNIQUE (screening_id, seat_id)  -- 같은 상영 같은 좌석 중복 예약 방지
);

-- 인덱스: 상영 스케줄 조회 성능 향상
CREATE INDEX idx_screenings_movie ON screenings(movie_id);
CREATE INDEX idx_screenings_time  ON screenings(show_time);
CREATE INDEX idx_reservations_screening ON reservations(screening_id);
