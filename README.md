# CinemaDB - 영화관 좌석 예약 시스템

PostgreSQL을 활용한 영화관 좌석 예약 웹 서비스입니다.

## 기술 스택

| 계층 | 기술 |
|------|------|
| Frontend | HTML / CSS / Vanilla JS |
| Backend | Python 3 + Flask |
| Database | PostgreSQL 18 |
| DB Driver | psycopg2 |

## 데이터베이스 설계

### 테이블 관계 (ERD 요약)

```
movies ──< screenings >── theaters
                │
                ▼
          reservations >── seats
```

### 핵심 테이블

| 테이블 | 역할 |
|--------|------|
| `movies` | 영화 정보 |
| `theaters` | 상영관 정보 (행 × 열 = 좌석 수) |
| `screenings` | 특정 영화 × 상영관 × 시간의 상영 회차 |
| `seats` | 상영관에 속한 물리 좌석 (A1, B3 등) |
| `reservations` | 예약 레코드 (UNIQUE: screening_id + seat_id) |

### 주요 DB 개념 활용

1. **Relations (관계)** — FK로 모든 테이블 연결, `UNIQUE(screening_id, seat_id)`로 중복 예약 방지
2. **Queries (쿼리)** — `JOIN`, 집계 함수(`COUNT FILTER`), 서브쿼리로 잔여 좌석 계산
3. **Transactions (트랜잭션)** — `SELECT ... FOR UPDATE`로 좌석 행 잠금 후 INSERT, 충돌 시 ROLLBACK

## 실행 방법

### 1. PostgreSQL 시작

```bash
brew services start postgresql@18
```

### 2. 데이터베이스 생성 및 초기화

```bash
psql -U $(whoami) -d postgres -c "CREATE DATABASE cinema;"
psql -U $(whoami) -d cinema -f database/schema.sql
psql -U $(whoami) -d cinema -f database/seed.sql
```

### 3. 백엔드 서버 실행

```bash
pip3 install -r backend/requirements.txt
python3 backend/app.py
```

### 4. 브라우저에서 접속

```
http://localhost:8080
```

## 주요 API

| Method | URL | 설명 |
|--------|-----|------|
| GET | `/api/movies` | 상영 중인 영화 목록 |
| GET | `/api/movies/:id/screenings` | 영화별 상영 스케줄 + 잔여 좌석 |
| GET | `/api/screenings/:id/seats` | 회차별 좌석 현황 |
| POST | `/api/reservations` | 좌석 예약 (트랜잭션) |
| POST | `/api/reservations/lookup` | 예약 조회 |
| POST | `/api/reservations/:id/cancel` | 예약 취소 |

## 프로젝트 구조

```
project/
├── backend/
│   ├── app.py           # Flask 라우터 및 API
│   ├── db.py            # PostgreSQL 연결 헬퍼
│   └── requirements.txt
├── database/
│   ├── schema.sql       # 테이블 정의 (DDL)
│   └── seed.sql         # 샘플 데이터
└── frontend/
    ├── index.html       # 단일 페이지 앱
    ├── style.css        # 스타일
    └── app.js           # API 호출 및 UI 로직
```
