import psycopg2
import psycopg2.extras
import os

DB_CONFIG = {
    "dbname":   os.getenv("DB_NAME",     "cinema"),
    "user":     os.getenv("DB_USER",     "wani"),
    "password": os.getenv("DB_PASSWORD", "1234"),
    "host":     os.getenv("DB_HOST",     "localhost"),
    "port":     os.getenv("DB_PORT",     "5432"),
}

def get_conn():
    return psycopg2.connect(**DB_CONFIG)

def query(sql, params=None, fetchall=True):
    """읽기 전용 쿼리 실행"""
    with get_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            return cur.fetchall() if fetchall else cur.fetchone()

def execute(sql, params=None):
    """단일 INSERT/UPDATE/DELETE 실행"""
    with get_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            try:
                row = cur.fetchone()
            except Exception:
                row = None
        conn.commit()
    return row
