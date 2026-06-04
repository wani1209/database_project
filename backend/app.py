from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import psycopg2
import psycopg2.extras
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from db import get_conn, query, execute


def wait_for_db(max_retries=30, delay=2):
    for i in range(max_retries):
        try:
            conn = get_conn()
            conn.close()
            print("Database connection established.", flush=True)
            return
        except Exception:
            print(f"Waiting for database... ({i+1}/{max_retries})", flush=True)
            time.sleep(delay)
    raise RuntimeError("Could not connect to database")

FRONTEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend"))

app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path="")
CORS(app)

# ──────────────────────────────────────────────
# 프론트엔드 서빙
# ──────────────────────────────────────────────
@app.route("/")
def index():
    return send_from_directory(FRONTEND_DIR, "index.html")

# ──────────────────────────────────────────────
# 영화 목록 & 상세
# ──────────────────────────────────────────────
@app.route("/api/movies")
def get_movies():
    """상영 중인 영화 목록 (스크리닝이 1개 이상인 영화만)"""
    rows = query("""
        SELECT DISTINCT ON (m.movie_id)
               m.movie_id, m.title, m.genre, m.duration, m.rating, m.description
        FROM   movies m
        JOIN   screenings s USING (movie_id)
        WHERE  s.show_time > NOW()
        ORDER  BY m.movie_id
    """)
    return jsonify([dict(r) for r in rows])

@app.route("/api/movies/<int:movie_id>/screenings")
def get_screenings(movie_id):
    """특정 영화의 상영 스케줄 + 잔여 좌석 수"""
    rows = query("""
        SELECT s.screening_id,
               s.show_time,
               s.price,
               t.name  AS theater_name,
               t.rows  AS theater_rows,
               t.cols  AS theater_cols,
               (t.rows * t.cols) AS total_seats,
               (t.rows * t.cols)
                 - COUNT(r.reservation_id) FILTER (WHERE r.status = 'confirmed')
                 AS available_seats
        FROM   screenings s
        JOIN   theaters t USING (theater_id)
        LEFT JOIN reservations r USING (screening_id)
        WHERE  s.movie_id = %s
          AND  s.show_time > NOW()
        GROUP  BY s.screening_id, t.theater_id
        ORDER  BY s.show_time
    """, (movie_id,))
    return jsonify([dict(r) for r in rows])

# ──────────────────────────────────────────────
# 좌석 현황
# ──────────────────────────────────────────────
@app.route("/api/screenings/<int:screening_id>/seats")
def get_seats(screening_id):
    """상영 회차의 전체 좌석 + 예약 상태"""
    rows = query("""
        SELECT se.seat_id,
               se.row_num,
               se.col_num,
               se.seat_label,
               CASE WHEN r.reservation_id IS NOT NULL THEN true ELSE false END AS is_reserved
        FROM   screenings sc
        JOIN   theaters t  USING (theater_id)
        JOIN   seats    se ON se.theater_id = t.theater_id
        LEFT JOIN reservations r
               ON r.screening_id = sc.screening_id
              AND r.seat_id      = se.seat_id
              AND r.status       = 'confirmed'
        WHERE  sc.screening_id = %s
        ORDER  BY se.row_num, se.col_num
    """, (screening_id,))
    return jsonify([dict(r) for r in rows])

# ──────────────────────────────────────────────
# 예약 (핵심 트랜잭션)
# ──────────────────────────────────────────────
@app.route("/api/reservations", methods=["POST"])
def create_reservation():
    """
    좌석 예약 — 트랜잭션 사용
    - SELECT ... FOR UPDATE 로 해당 좌석 행을 잠금
    - 이미 예약된 경우 ROLLBACK 후 409 반환
    - 정상이면 INSERT 후 COMMIT
    """
    data = request.get_json()
    screening_id = data.get("screening_id")
    seat_ids     = data.get("seat_ids", [])
    booker_name  = data.get("booker_name", "").strip()
    booker_phone = data.get("booker_phone", "").strip()

    if not (screening_id and seat_ids and booker_name and booker_phone):
        return jsonify({"error": "필수 정보가 누락되었습니다."}), 400

    reserved = []
    with get_conn() as conn:
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                for seat_id in seat_ids:
                    # 중복 예약 방지: FOR UPDATE 로 행 잠금
                    cur.execute("""
                        SELECT r.reservation_id
                        FROM   reservations r
                        WHERE  r.screening_id = %s
                          AND  r.seat_id      = %s
                          AND  r.status       = 'confirmed'
                        FOR UPDATE
                    """, (screening_id, seat_id))

                    if cur.fetchone():
                        conn.rollback()
                        return jsonify({"error": f"seat_id={seat_id} 는 이미 예약된 좌석입니다."}), 409

                    cur.execute("""
                        INSERT INTO reservations (screening_id, seat_id, booker_name, booker_phone)
                        VALUES (%s, %s, %s, %s)
                        RETURNING reservation_id, reserved_at
                    """, (screening_id, seat_id, booker_name, booker_phone))
                    reserved.append(dict(cur.fetchone()))

            conn.commit()
        except Exception as e:
            conn.rollback()
            return jsonify({"error": str(e)}), 500

    return jsonify({"message": "예약 완료", "reservations": reserved}), 201

# ──────────────────────────────────────────────
# 예약 조회 & 취소
# ──────────────────────────────────────────────
@app.route("/api/reservations/lookup", methods=["POST"])
def lookup_reservations():
    """이름 + 전화번호로 예약 내역 조회"""
    data  = request.get_json()
    rows  = query("""
        SELECT r.reservation_id,
               r.reserved_at,
               r.status,
               se.seat_label,
               m.title,
               m.genre,
               t.name  AS theater_name,
               sc.show_time,
               sc.price
        FROM   reservations r
        JOIN   screenings sc USING (screening_id)
        JOIN   movies     m  USING (movie_id)
        JOIN   theaters   t  USING (theater_id)
        JOIN   seats      se USING (seat_id)
        WHERE  r.booker_name  = %s
          AND  r.booker_phone = %s
        ORDER  BY r.reserved_at DESC
    """, (data.get("booker_name"), data.get("booker_phone")))
    return jsonify([dict(r) for r in rows])

@app.route("/api/reservations/<int:reservation_id>/cancel", methods=["POST"])
def cancel_reservation(reservation_id):
    """예약 취소 — 상태를 cancelled 로 변경"""
    row = execute("""
        UPDATE reservations
        SET    status = 'cancelled'
        WHERE  reservation_id = %s
          AND  status = 'confirmed'
        RETURNING reservation_id
    """, (reservation_id,))

    if not row:
        return jsonify({"error": "예약을 찾을 수 없거나 이미 취소된 예약입니다."}), 404
    return jsonify({"message": "예약이 취소되었습니다."})

if __name__ == "__main__":
    wait_for_db()
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(host="0.0.0.0", debug=debug, port=8080)
