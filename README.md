# CinemaDB - 영화관 좌석 예약 시스템

PostgreSQL을 활용한 영화관 좌석 예약 웹 서비스입니다.

## 기술 스택

| 계층 | 기술 |
|------|------|
| Frontend | HTML / CSS / Vanilla JS |
| Backend | Python 3 + Flask |
| Database | PostgreSQL 16 (Docker) |
| DB Driver | psycopg2 |
| 컨테이너 | Docker / Docker Compose |

## 데이터베이스 설계

### 테이블 관계 (ERD 요약)

```
movies ──< screenings >── theaters ──< seats
                │                         │
                └──── reservations ───────┘
```

### 핵심 테이블

| 테이블 | 역할 |
|--------|------|
| `movies` | 영화 정보 |
| `theaters` | 상영관 정보 (행 × 열 = 좌석 수) |
| `screenings` | 영화 × 상영관 × 시간의 상영 회차 |
| `seats` | 상영관에 속한 물리 좌석 (A1, B3 등) |
| `reservations` | 예약 레코드 — `UNIQUE(screening_id, seat_id)`로 중복 예약 방지 |

### 동시성 제어 메커니즘

| 메커니즘 | 격리 수준 | 방식 | 충돌 처리 |
|----------|----------|------|----------|
| **2PL** | READ COMMITTED | `SELECT FOR UPDATE` (명시적 행 잠금) | 잠금 대기 후 차단 |
| **SSI** | SERIALIZABLE | 잠금 없이 낙관적 진행, 커밋 시 의존성 검사 | 직렬화 오류(40001) → 재시도 |
| **RR** | REPEATABLE READ | MVCC 스냅샷, 명시적 잠금 없음 | UNIQUE 위반 → 재시도 |

웹 서비스는 **2PL** 방식을 사용합니다 (`backend/app.py`).

## 실행 방법

### Docker (권장)

```bash
docker compose up --build
```

브라우저에서 접속: [http://localhost:8080](http://localhost:8080)

- PostgreSQL: `localhost:5433` (유저: `wani`, 비밀번호: `1234`, DB: `cinema`)
- 스키마 및 더미 데이터는 컨테이너 최초 실행 시 자동 적용됩니다.

### 로컬 실행 (PostgreSQL 직접 사용)

```bash
# 1. DB 생성 및 초기화
psql -U wani -d postgres -c "CREATE DATABASE cinema;"
psql -U wani -d cinema -f database/schema.sql
psql -U wani -d cinema -f database/insert_data.sql

# 2. 백엔드 실행
pip install -r backend/requirements.txt
DB_PASSWORD=1234 python backend/app.py
```

## 주요 API

| Method | URL | 설명 |
|--------|-----|------|
| GET | `/api/movies` | 상영 중인 영화 목록 |
| GET | `/api/movies/:id/screenings` | 영화별 상영 스케줄 + 잔여 좌석 |
| GET | `/api/screenings/:id/seats` | 회차별 좌석 현황 |
| POST | `/api/reservations` | 좌석 예약 (2PL 트랜잭션) |
| POST | `/api/reservations/lookup` | 예약 조회 |
| POST | `/api/reservations/:id/cancel` | 예약 취소 |

## 벤치마크

pgbench를 사용해 2PL과 SSI의 성능을 클라이언트 수별로 비교합니다.

```bash
PGPASSWORD=1234 bash run_benchmark.sh
```

기본 설정: `c10j4` / `c50j8` / `c100j16` × 2PL, SSI — 각 60초, 총 6회 실행

### 벤치마크 결과 예시

| 시나리오 | TPS | 평균 지연 | 오류 |
|----------|-----|----------|------|
| 2PL c10j4 | 6,189 | 1.62 ms | 0 |
| SSI c10j4 | 6,196 | 1.61 ms | 0 |
| 2PL c50j8 | 9,387 | 5.33 ms | 0 |
| SSI c50j8 | 8,757 | 5.71 ms | 15 |
| 2PL c100j16 | 9,473 | 10.56 ms | 0 |
| SSI c100j16 | 7,967 | 12.55 ms | 59 |

- 저동시성(c10): 2PL/SSI 성능 차이 없음
- 고동시성(c50↑): 2PL이 TPS 높고 오류 없음. SSI는 직렬화 오류 발생 → TPS 저하

## 프로젝트 구조

```
project/
├── Dockerfile
├── docker-compose.yml
├── run_benchmark.sh        # pgbench 벤치마크 실행 스크립트
├── backend/
│   ├── app.py              # Flask API (2PL 예약 트랜잭션)
│   ├── db.py               # PostgreSQL 연결 헬퍼
│   └── requirements.txt
├── database/
│   ├── schema.sql          # 테이블 정의 (DDL)
│   └── insert_data.sql     # 더미 데이터 (영화 10편, 상영 38개, 예약 ~200건)
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── benchmark/
    ├── workload_2pl.sql    # pgbench 스크립트 — 2PL
    ├── workload_ssi.sql    # pgbench 스크립트 — SSI
    └── results/            # 벤치마크 결과 저장
```
