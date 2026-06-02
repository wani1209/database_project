const API = "http://localhost:8080/api";

// ── 상태 ──────────────────────────────────────────────────────────────
let state = {
  currentMovieId:    null,
  currentScreening:  null,  // { screening_id, price, theater_name, show_time }
  selectedSeats:     [],    // [{ seat_id, seat_label }]
};

// ── 페이지 라우팅 ─────────────────────────────────────────────────────
function showPage(name) {
  document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
  document.querySelectorAll(".nav-btn").forEach(b => b.classList.remove("active"));
  document.getElementById(`page-${name}`).classList.add("active");
  const navBtn = document.getElementById(`nav-${name}`);
  if (navBtn) navBtn.classList.add("active");
}

// ── 영화 목록 ─────────────────────────────────────────────────────────
const GENRE_EMOJI = {
  "SF/드라마": "🚀", "액션/SF": "💥", "드라마/스릴러": "🎭",
  "액션/드라마": "✈️", "액션": "👊",
};

async function loadMovies() {
  const res  = await fetch(`${API}/movies`);
  const data = await res.json();
  const el   = document.getElementById("movie-list");

  if (!data.length) {
    el.innerHTML = '<div class="empty">현재 상영 중인 영화가 없습니다.</div>';
    return;
  }

  el.innerHTML = data.map(m => `
    <div class="movie-card" onclick="selectMovie(${m.movie_id}, '${escHtml(m.title)}')">
      <div class="movie-poster">${GENRE_EMOJI[m.genre] || "🎬"}</div>
      <div class="movie-info">
        <div class="movie-title">${escHtml(m.title)}</div>
        <div class="movie-meta">
          ${escHtml(m.genre)}<br>
          ${m.duration}분
          <span class="badge">${escHtml(m.rating)}</span>
        </div>
      </div>
    </div>
  `).join("");
}

// ── 상영 시간 선택 ────────────────────────────────────────────────────
async function selectMovie(movieId, title) {
  state.currentMovieId = movieId;
  showPage("screenings");

  document.getElementById("movie-detail").innerHTML = `
    <div class="card" style="margin-bottom:0">
      <div style="font-size:1.5rem;font-weight:700">${escHtml(title)}</div>
    </div>`;

  const res  = await fetch(`${API}/movies/${movieId}/screenings`);
  const data = await res.json();
  const el   = document.getElementById("screening-list");

  if (!data.length) {
    el.innerHTML = '<div class="empty">예약 가능한 상영 일정이 없습니다.</div>';
    return;
  }

  el.innerHTML = `<div class="screening-grid">${data.map(s => {
    const dt    = new Date(s.show_time);
    const dateStr = `${dt.getMonth()+1}/${dt.getDate()} (${["일","월","화","수","목","금","토"][dt.getDay()]})`;
    const timeStr = `${String(dt.getHours()).padStart(2,"0")}:${String(dt.getMinutes()).padStart(2,"0")}`;
    const avail = s.available_seats;
    const badgeCls = avail === 0 ? "seats-no" : avail <= 5 ? "seats-few" : "seats-ok";
    const badgeTxt = avail === 0 ? "매진" : `잔여 ${avail}석`;
    return `
      <div class="screening-card ${avail === 0 ? 'disabled' : ''}"
           onclick="${avail > 0 ? `selectScreening(${s.screening_id}, ${s.price}, '${escHtml(s.theater_name)}', '${dt.toISOString()}')` : "alert('매진된 회차입니다.')"}">
        <div class="screening-time">${dateStr} ${timeStr}</div>
        <div class="screening-info">
          ${escHtml(s.theater_name)}<br>
          ${Number(s.price).toLocaleString()}원
        </div>
        <span class="seats-badge ${badgeCls}">${badgeTxt}</span>
      </div>`;
  }).join("")}</div>`;
}

// ── 좌석 선택 ─────────────────────────────────────────────────────────
async function selectScreening(screeningId, price, theaterName, showTimeIso) {
  state.currentScreening = { screening_id: screeningId, price, theater_name: theaterName, show_time: showTimeIso };
  state.selectedSeats    = [];
  showPage("seats");

  document.getElementById("back-to-screenings").onclick = () => selectMovie(state.currentMovieId, "");

  const dt  = new Date(showTimeIso);
  document.getElementById("seat-info-bar").innerHTML = `
    <strong>${theaterName}</strong> &nbsp;|&nbsp;
    ${dt.getMonth()+1}/${dt.getDate()} &nbsp;
    ${String(dt.getHours()).padStart(2,"0")}:${String(dt.getMinutes()).padStart(2,"0")}
    &nbsp;|&nbsp; <strong>${Number(price).toLocaleString()}원 / 석</strong>`;

  const res  = await fetch(`${API}/screenings/${screeningId}/seats`);
  const seats = await res.json();
  renderSeatMap(seats);
  updateBookingPanel();
}

function renderSeatMap(seats) {
  const byRow = {};
  seats.forEach(s => {
    if (!byRow[s.row_num]) byRow[s.row_num] = [];
    byRow[s.row_num].push(s);
  });

  const map = document.getElementById("seat-map");
  map.innerHTML = "";

  Object.keys(byRow).sort((a, b) => a - b).forEach(rowNum => {
    const rowEl = document.createElement("div");
    rowEl.className = "seat-row";

    const label = document.createElement("div");
    label.className = "row-label";
    label.textContent = String.fromCharCode(64 + Number(rowNum));
    rowEl.appendChild(label);

    byRow[rowNum].sort((a, b) => a.col_num - b.col_num).forEach(s => {
      const btn = document.createElement("button");
      btn.className = s.is_reserved ? "seat reserved" : "seat available";
      btn.textContent = s.col_num;
      btn.title = s.seat_label;
      btn.dataset.seatId    = s.seat_id;
      btn.dataset.seatLabel = s.seat_label;
      if (!s.is_reserved) btn.onclick = () => toggleSeat(btn, s);
      rowEl.appendChild(btn);
    });
    map.appendChild(rowEl);
  });
}

function toggleSeat(btn, seat) {
  const idx = state.selectedSeats.findIndex(s => s.seat_id === seat.seat_id);
  if (idx === -1) {
    state.selectedSeats.push({ seat_id: seat.seat_id, seat_label: seat.seat_label });
    btn.classList.replace("available", "selected");
  } else {
    state.selectedSeats.splice(idx, 1);
    btn.classList.replace("selected", "available");
  }
  updateBookingPanel();
}

function updateBookingPanel() {
  const panel = document.getElementById("booking-panel");
  const count = state.selectedSeats.length;
  if (count === 0) { panel.classList.add("hidden"); return; }
  panel.classList.remove("hidden");
  document.getElementById("selected-count").textContent = `${count}석 선택`;
  document.getElementById("total-price").textContent =
    `${(count * state.currentScreening.price).toLocaleString()}원`;
}

// ── 예약 확정 (POST /api/reservations) ───────────────────────────────
async function confirmReservation() {
  const name  = document.getElementById("booker-name").value.trim();
  const phone = document.getElementById("booker-phone").value.trim();

  if (!name)  { alert("예약자 이름을 입력해주세요."); return; }
  if (!phone) { alert("전화번호를 입력해주세요."); return; }
  if (state.selectedSeats.length === 0) { alert("좌석을 선택해주세요."); return; }

  const btn = document.getElementById("confirm-btn");
  btn.disabled = true; btn.textContent = "처리 중...";

  const res = await fetch(`${API}/reservations`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      screening_id: state.currentScreening.screening_id,
      seat_ids:     state.selectedSeats.map(s => s.seat_id),
      booker_name:  name,
      booker_phone: phone,
    }),
  });
  const data = await res.json();
  btn.disabled = false; btn.textContent = "예약 확정";

  if (!res.ok) { alert(data.error || "예약에 실패했습니다."); return; }

  const seats = state.selectedSeats.map(s => s.seat_label).join(", ");
  showModal("예약 완료!", `${seats} 좌석이 예약되었습니다.\n'내 예약 조회'에서 확인하세요.`);

  // 좌석 상태 새로고침
  state.selectedSeats = [];
  updateBookingPanel();
  const seatsRes = await fetch(`${API}/screenings/${state.currentScreening.screening_id}/seats`);
  renderSeatMap(await seatsRes.json());
}

// ── 예약 조회 ─────────────────────────────────────────────────────────
async function lookupReservations() {
  const name  = document.getElementById("lookup-name").value.trim();
  const phone = document.getElementById("lookup-phone").value.trim();
  if (!name || !phone) { alert("이름과 전화번호를 모두 입력해주세요."); return; }

  const res  = await fetch(`${API}/reservations/lookup`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ booker_name: name, booker_phone: phone }),
  });
  const data = await res.json();
  const el   = document.getElementById("reservation-list");

  if (!data.length) {
    el.innerHTML = '<div class="empty">예약 내역이 없습니다.</div>';
    return;
  }

  el.innerHTML = data.map(r => {
    const dt  = new Date(r.show_time);
    const statusCls = r.status === "confirmed" ? "status-confirmed" : "status-cancelled";
    const statusTxt = r.status === "confirmed" ? "예약완료" : "취소됨";
    return `
      <div class="reservation-card ${r.status === 'cancelled' ? 'cancelled' : ''}">
        <div class="res-info">
          <div class="res-title">${escHtml(r.title)}</div>
          <div class="res-meta">
            ${escHtml(r.theater_name)} &nbsp;|&nbsp;
            ${dt.getMonth()+1}/${dt.getDate()} ${String(dt.getHours()).padStart(2,"0")}:${String(dt.getMinutes()).padStart(2,"0")}<br>
            좌석: <strong>${escHtml(r.seat_label)}</strong> &nbsp;|&nbsp;
            ${Number(r.price).toLocaleString()}원
          </div>
        </div>
        <div style="display:flex;flex-direction:column;align-items:flex-end;gap:10px">
          <span class="status-badge ${statusCls}">${statusTxt}</span>
          ${r.status === "confirmed"
            ? `<button class="btn-cancel" onclick="cancelReservation(${r.reservation_id}, this)">취소하기</button>`
            : ""}
        </div>
      </div>`;
  }).join("");
}

async function cancelReservation(reservationId, btn) {
  if (!confirm("예약을 취소하시겠습니까?")) return;
  btn.disabled = true;
  const res = await fetch(`${API}/reservations/${reservationId}/cancel`, { method: "POST" });
  if (res.ok) {
    showModal("취소 완료", "예약이 취소되었습니다.");
    lookupReservations();
  } else {
    const data = await res.json();
    alert(data.error || "취소에 실패했습니다.");
    btn.disabled = false;
  }
}

// ── 모달 ──────────────────────────────────────────────────────────────
function showModal(title, body) {
  document.getElementById("modal-title").textContent = title;
  document.getElementById("modal-body").textContent  = body;
  document.getElementById("modal-overlay").classList.remove("hidden");
}
function closeModal() {
  document.getElementById("modal-overlay").classList.add("hidden");
}

// ── 유틸 ──────────────────────────────────────────────────────────────
function escHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// ── 초기화 ────────────────────────────────────────────────────────────
loadMovies();
