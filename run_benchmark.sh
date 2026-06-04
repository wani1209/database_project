#!/usr/bin/env bash
# ================================================================
# Cinema DB pgbench 벤치마크
# 사용: PGPASSWORD=1234 bash run_benchmark.sh
#
# 고정 설정:
#   (c=10, j=4) | (c=50, j=8) | (c=100, j=16)  × 2PL, SSI
#   T=60s 고정 → 총 6회 실행
#
# 옵션:
#   -h HOST    DB 호스트  (기본: localhost)
#   -p PORT    DB 포트    (기본: 5433)
#   -U USER    DB 사용자  (기본: wani)
#   -d DB      DB 이름    (기본: cinema)
# ================================================================

DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5433}"
DB_USER="${PGUSER:-wani}"
DB_NAME="${PGDATABASE:-cinema}"
DURATION=60
RESULTS_DIR="benchmark/results"

while getopts "h:p:U:d:" opt; do
    case $opt in
        h) DB_HOST="$OPTARG" ;;
        p) DB_PORT="$OPTARG" ;;
        U) DB_USER="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        *) echo "알 수 없는 옵션: -$OPTARG" && exit 1 ;;
    esac
done

export PGPASSWORD="${PGPASSWORD:-1234}"
PGCONN="-h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

# 실행 설정: (clients, threads) 쌍
CONFIGS=("10:4" "50:8" "100:16")

mkdir -p "$RESULTS_DIR"

# ── 유틸 함수 ─────────────────────────────────────────────────────
psql_exec() { psql $PGCONN -t -A -c "$1" 2>/dev/null; }

extract_tps() {
    grep -E "^tps\s*=" "$1" 2>/dev/null | tail -1 \
        | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "N/A"
}

extract_latency() {
    grep "latency average" "$1" 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "N/A"
}

extract_errors() {
    grep -E "number of failed" "$1" 2>/dev/null \
        | grep -oE '[0-9]+' | head -1 || echo "0"
}

# ── 시작 ──────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              Cinema DB pgbench 벤치마크 (6회)                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "  설정: [c10j4] [c50j8] [c100j16]  ×  [2PL] [SSI]  T=${DURATION}s"
echo "  대상: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""

# ── DB 연결 확인 ─────────────────────────────────────────────────
echo "DB 연결 확인..."
for i in $(seq 1 15); do
    if psql_exec "SELECT 1" > /dev/null 2>&1; then
        echo "  연결 성공"; break
    fi
    [ "$i" -eq 15 ] && echo "오류: DB 연결 실패" && exit 1
    sleep 2
done

SCREENING_COUNT=$(psql_exec "SELECT COUNT(*) FROM screenings WHERE show_time > NOW()")
[ "${SCREENING_COUNT:-0}" -eq 0 ] && echo "오류: 활성 상영 없음" && exit 1
echo "  활성 상영: ${SCREENING_COUNT}개"

# ── pgbench_slots 테이블 생성 ────────────────────────────────────
echo ""
echo "pgbench_slots 생성 중..."
psql_exec "
DROP TABLE IF EXISTS pgbench_slots;
CREATE TABLE pgbench_slots AS
SELECT ROW_NUMBER() OVER(ORDER BY s.screening_id, se.seat_id)::INT AS slot_id,
       s.screening_id, se.seat_id
FROM   screenings s
JOIN   theaters t  USING (theater_id)
JOIN   seats    se ON se.theater_id = t.theater_id
WHERE  s.show_time > NOW();
CREATE INDEX ON pgbench_slots(slot_id);
" > /dev/null

SLOT_COUNT=$(psql_exec "SELECT COUNT(*) FROM pgbench_slots")
echo "  슬롯: ${SLOT_COUNT}개"

# ================================================================
# 6회 벤치마크 실행
# ================================================================
declare -a ROWS   # "label|tps|lat|err" per run

total=0
for cfg in "${CONFIGS[@]}"; do
    clients="${cfg%%:*}"
    threads="${cfg##*:}"

    for scenario in "2PL" "SSI"; do
        total=$((total + 1))
        label="${scenario} c${clients}j${threads}"
        scenario_lc="$(echo "$scenario" | tr '[:upper:]' '[:lower:]')"
        outfile="$RESULTS_DIR/${scenario_lc}_c${clients}.txt"

        printf '%.0s─' {1..66}; echo
        printf "  [%d/6] %s\n" "$total" "$label"
        printf '%.0s─' {1..66}; echo
        printf "  running..."

        # 이전 벤치 데이터 정리
        psql_exec "DELETE FROM reservations WHERE booker_name LIKE 'pgbench_%'" > /dev/null

        if [ "$scenario" = "2PL" ]; then
            pgbench $PGCONN \
                -f benchmark/workload_2pl.sql \
                -D slot_count="$SLOT_COUNT" \
                -c "$clients" -j "$threads" -T "$DURATION" -n \
                > "$outfile" 2>&1 || true
        else
            pgbench $PGCONN \
                -f benchmark/workload_ssi.sql \
                -D slot_count="$SLOT_COUNT" \
                --max-tries=5 \
                -c "$clients" -j "$threads" -T "$DURATION" -n \
                > "$outfile" 2>&1 || true
        fi

        TPS=$(extract_tps "$outfile")
        LAT=$(extract_latency "$outfile")
        ERR=$(extract_errors "$outfile")
        printf " 완료\n"
        echo "  TPS: $TPS  |  평균 지연: ${LAT} ms  |  오류: $ERR"

        ROWS+=("$label|$TPS|$LAT|$ERR")
    done
done

# ================================================================
# 최종 요약 테이블
# ================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                        벤치마크 결과 요약                       ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  %-22s │ %10s TPS │ %10s ms │ %7s 오류 ║\n" \
    "시나리오" "처리량" "평균지연" "오류수"
echo "╠══════════════════════════════════════════════════════════════════╣"
for row in "${ROWS[@]}"; do
    IFS='|' read -r lbl tps lat err <<< "$row"
    printf "║  %-22s │ %14s │ %12s │ %11s ║\n" "$lbl" "$tps" "$lat" "$err"
done
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "  · 2PL: FOR UPDATE 잠금 — 충돌 차단, 교착 시 재시도"
echo "  · SSI: SERIALIZABLE — 낙관적 진행, 커밋 시 직렬화 오류 감지"
echo "  상세 로그: $RESULTS_DIR/"
echo ""

# ── 정리 ─────────────────────────────────────────────────────────
psql_exec "DROP TABLE IF EXISTS pgbench_slots" > /dev/null
