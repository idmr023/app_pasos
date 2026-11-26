// Motor de análisis de entrenamiento de resistencia (funciones puras, sin DB).
//
// - Carga por sesión: TRIMP de Banister con FC; si no hay FC, RPE × minutos × 0.4
//   (misma escala que TRIMP); si tampoco, minutos × factor por deporte.
// - Forma: CTL (fitness, EWMA 42 d), ATL (fatiga, EWMA 7 d), TSB = CTL − ATL,
//   ACWR = carga 7 d / (carga 28 d / 4).
// - Nivel: VDOT de Daniels desde los mejores esfuerzos recientes → predicciones
//   de carrera y ritmos de entrenamiento (E, M, T, I, R).
// - Recomendación semanal: volumen objetivo (+~8 %, mantener, descarga,
//   reducción o taper) y reparto 80/20 en sesiones con ritmos.
// Ver docs/TRAINING.md.

const DAY_MS = 24 * 60 * 60 * 1000;
const TZ_OFFSET_MS = -5 * 60 * 60 * 1000; // America/Lima (UTC-5 fijo), igual que ligas
const RUN_SPORTS = ['run', 'trail'];
const DEFAULT_REST_HR = 60;

const round = (n, d = 0) => {
  const f = 10 ** d;
  return Math.round(n * f) / f;
};
const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));
const isRun = (s) => RUN_SPORTS.includes(s.sport);
const paceOf = (distanceM, seconds) => (distanceM > 0 && seconds > 0 ? seconds / (distanceM / 1000) : 0);

function formatPace(secPerKm) {
  if (!secPerKm || !Number.isFinite(secPerKm)) return '--';
  const total = Math.round(secPerKm);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}/km`;
}

function formatDuration(sec) {
  const s = Math.round(sec);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}` : `${m}:${String(r).padStart(2, '0')}`;
}

// ---------------------------------------------------------------------------
// Frecuencia cardíaca

function heartRateContext(profile, sessions = []) {
  let maxHR = profile && profile.maxHeartRate ? profile.maxHeartRate : null;
  let maxSource = 'profile';
  if (!maxHR) {
    const observed = sessions.reduce((m, s) => Math.max(m, s.maxHeartRate || 0), 0);
    if (observed >= 150) {
      maxHR = observed;
      maxSource = 'observed';
    } else {
      maxSource = 'unknown';
    }
  }
  const restHR = profile && profile.restingHeartRate ? profile.restingHeartRate : DEFAULT_REST_HR;
  return { maxHR, restHR, maxSource, restSource: profile && profile.restingHeartRate ? 'profile' : 'default' };
}

// Zonas por % FC máx: Z1 < 60, Z2 60–70, Z3 70–80, Z4 80–90, Z5 ≥ 90.
function hrZone(hr, maxHR) {
  if (!hr || !maxHR) return 0;
  const pct = hr / maxHR;
  if (pct < 0.6) return 1;
  if (pct < 0.7) return 2;
  if (pct < 0.8) return 3;
  if (pct < 0.9) return 4;
  return 5;
}

function zoneDistribution(session, hr) {
  const seconds = [0, 0, 0, 0, 0];
  if (!hr.maxHR) return null;
  const splits = (session.splits || []).filter((s) => s.averageHeartRate > 0 && s.movingTime > 0);
  if (splits.length >= 2) {
    for (const s of splits) seconds[hrZone(s.averageHeartRate, hr.maxHR) - 1] += s.movingTime;
  } else if (session.averageHeartRate > 0) {
    seconds[hrZone(session.averageHeartRate, hr.maxHR) - 1] += session.movingTime || 0;
  } else {
    return null;
  }
  const total = seconds.reduce((a, b) => a + b, 0) || 1;
  return { seconds, percent: seconds.map((s) => round((s / total) * 100)) };
}

// ---------------------------------------------------------------------------
// Carga

const SPORT_LOAD_PER_MIN = { walk: 0.6, hike: 0.9, ride: 0.9, swim: 1.1 };

function computeLoad(session, hr) {
  const minutes = (session.movingTime || 0) / 60;
  if (minutes <= 0) return { load: 0, source: 'none' };
  if (session.averageHeartRate > 0 && hr.maxHR && hr.maxHR > hr.restHR) {
    const hrr = clamp((session.averageHeartRate - hr.restHR) / (hr.maxHR - hr.restHR), 0, 1);
    return { load: round(minutes * hrr * 0.64 * Math.exp(1.92 * hrr), 1), source: 'hr' };
  }
  if (session.rpe) {
    return { load: round(minutes * session.rpe * 0.4, 1), source: 'rpe' };
  }
  return { load: round(minutes * (SPORT_LOAD_PER_MIN[session.sport] || 1.2), 1), source: 'estimated' };
}

// ---------------------------------------------------------------------------
// Splits

function analyzeSplits(session) {
  const valid = (session.splits || []).filter((s) => s.distance >= 500 && s.movingTime > 0);
  if (valid.length < 3) return null;

  const paces = valid.map((s) => paceOf(s.distance, s.movingTime));
  const mean = paces.reduce((a, b) => a + b, 0) / paces.length;
  const sd = Math.sqrt(paces.reduce((a, p) => a + (p - mean) ** 2, 0) / paces.length);

  const mid = Math.floor(valid.length / 2);
  const halves = [valid.slice(0, mid), valid.slice(valid.length - mid)];
  const agg = halves.map((h) => {
    const dist = h.reduce((a, s) => a + s.distance, 0);
    const time = h.reduce((a, s) => a + s.movingTime, 0);
    const hrTime = h.filter((s) => s.averageHeartRate > 0);
    const hrT = hrTime.reduce((a, s) => a + s.movingTime, 0);
    const avgHR = hrT > 0 ? hrTime.reduce((a, s) => a + s.averageHeartRate * s.movingTime, 0) / hrT : 0;
    return { pace: paceOf(dist, time), speed: time > 0 ? dist / time : 0, avgHR };
  });

  const halfDiffPct = agg[0].pace > 0 ? (agg[1].pace - agg[0].pace) / agg[0].pace : 0;
  let splitType = 'even';
  if (halfDiffPct < -0.02) splitType = 'negative';
  else if (halfDiffPct > 0.03) splitType = 'positive';

  let decouplingPct = null;
  if (agg[0].avgHR > 0 && agg[1].avgHR > 0) {
    const ef1 = agg[0].speed / agg[0].avgHR;
    const ef2 = agg[1].speed / agg[1].avgHR;
    decouplingPct = round(((ef1 - ef2) / ef1) * 100, 1);
  }

  let fastest = 0;
  let slowest = 0;
  paces.forEach((p, i) => {
    if (p < paces[fastest]) fastest = i;
    if (p > paces[slowest]) slowest = i;
  });

  return {
    count: valid.length,
    paceCv: round(sd / mean, 3),
    firstHalfPace: round(agg[0].pace),
    secondHalfPace: round(agg[1].pace),
    halfDiffSec: round(agg[1].pace - agg[0].pace),
    splitType,
    decouplingPct,
    fastestSplit: valid[fastest].index || fastest + 1,
    slowestSplit: valid[slowest].index || slowest + 1
  };
}

function lapSpeedCv(session) {
  const laps = (session.laps || []).filter((l) => l.averageSpeed > 0 && l.movingTime > 0);
  if (laps.length < 4) return 0;
  const speeds = laps.map((l) => l.averageSpeed);
  const mean = speeds.reduce((a, b) => a + b, 0) / speeds.length;
  const sd = Math.sqrt(speeds.reduce((a, v) => a + (v - mean) ** 2, 0) / speeds.length);
  return sd / mean;
}

// ---------------------------------------------------------------------------
// Clasificación

function classifySession(session, hr, splitInfo) {
  if (session.sessionType && session.sessionType !== 'auto') return session.sessionType;
  if (!isRun(session)) return 'other';
  if (session.stravaWorkoutType === 1) return 'race';

  const minutes = (session.movingTime || 0) / 60;
  const hilly = session.distance > 0 && session.elevationGain / (session.distance / 1000) > 15;
  const hrPct = session.averageHeartRate > 0 && hr.maxHR ? session.averageHeartRate / hr.maxHR : null;

  if (lapSpeedCv(session) > 0.12 || (!hilly && splitInfo && splitInfo.paceCv > 0.12)) return 'intervals';
  if (session.stravaWorkoutType === 2 || minutes >= 80 || session.distance >= 16000) return 'long';
  if ((hrPct !== null && hrPct >= 0.84) || (session.rpe && session.rpe >= 7) || session.stravaWorkoutType === 3) {
    return 'tempo';
  }
  if ((hrPct !== null && hrPct < 0.68) || (session.rpe && session.rpe <= 2)) {
    return minutes < 40 ? 'recovery' : 'easy';
  }
  return 'easy';
}

// ---------------------------------------------------------------------------
// Sesión individual

function findComparable(session, type, history) {
  if (!session.distance) return null;
  return (history || [])
    .filter((h) => String(h._id) !== String(session._id)
      && h.sport === session.sport
      && new Date(h.startDate) < new Date(session.startDate)
      && h.distance > 0 && h.movingTime > 0
      && Math.abs(h.distance - session.distance) / session.distance <= 0.25)
    .map((h) => ({ h, type: h._classifiedType }))
    .filter((x) => !x.type || x.type === type)
    .sort((a, b) => new Date(b.h.startDate) - new Date(a.h.startDate))
    .map((x) => x.h)[0] || null;
}

/**
 * Analiza una sesión. `history` (opcional) = sesiones previas del usuario para
 * comparar con la última similar; pueden traer `_classifiedType` precalculado.
 */
function analyzeSession(session, hr, history = []) {
  const splitInfo = analyzeSplits(session);
  const type = classifySession(session, hr, splitInfo);
  const { load, source: loadSource } = computeLoad(session, hr);
  const zones = zoneDistribution(session, hr);
  const pace = paceOf(session.distance, session.movingTime);
  const efficiency = session.averageHeartRate > 0 && session.averageSpeed > 0
    ? round((session.averageSpeed * 60) / session.averageHeartRate, 3)
    : null;
  const hrPct = session.averageHeartRate > 0 && hr.maxHR ? round(session.averageHeartRate / hr.maxHR, 2) : null;

  const insights = [];
  const add = (level, text) => insights.push({ level, text });
  const easyType = ['easy', 'recovery', 'long'].includes(type);
  const minutes = (session.movingTime || 0) / 60;

  if (splitInfo) {
    if (splitInfo.splitType === 'negative') {
      add('good', `Split negativo: la segunda mitad fue ${Math.abs(splitInfo.halfDiffSec)} s/km más rápida. Excelente gestión del esfuerzo.`);
    } else if (splitInfo.splitType === 'positive' && (easyType || type === 'race')) {
      add('warn', `Saliste rápido: la segunda mitad fue ${splitInfo.halfDiffSec} s/km más lenta. Arranca 5–10 s/km más suave.`);
    } else if (splitInfo.splitType === 'even' && splitInfo.paceCv < 0.04 && type !== 'intervals') {
      add('good', 'Ritmo muy constante de principio a fin.');
    }
    if (splitInfo.decouplingPct !== null && minutes >= 40 && type !== 'intervals') {
      if (splitInfo.decouplingPct < 5) {
        add('good', `Desacople cardíaco ${splitInfo.decouplingPct}%: buena base aeróbica para ${Math.round(minutes)} min.`);
      } else if (splitInfo.decouplingPct > 10) {
        add('warn', `Desacople cardíaco ${splitInfo.decouplingPct}%: la FC subió mucho respecto al ritmo. Falta base aeróbica, o hubo calor/deshidratación.`);
      } else {
        add('info', `Desacople cardíaco ${splitInfo.decouplingPct}%: aceptable; por debajo de 5% indica base aeróbica sólida.`);
      }
    }
  }

  if (zones && easyType) {
    const hard = zones.percent[2] + zones.percent[3] + zones.percent[4];
    if (hard > 40) {
      add('warn', `Rodaje demasiado intenso: ${hard}% del tiempo en Z3 o más. Los rodajes suaves van en Z1–Z2 (< 70% FC máx).`);
    } else if (zones.percent[0] + zones.percent[1] >= 80) {
      add('good', 'Intensidad correcta: el rodaje se mantuvo en zona aeróbica (Z1–Z2).');
    }
  }
  if (zones && (type === 'tempo' || type === 'intervals')) {
    const high = zones.percent[3] + zones.percent[4];
    if (high < 25) add('info', `Solo ${high}% en Z4–Z5: si era una sesión de calidad, apretaste poco.`);
    else add('good', `Sesión de calidad bien ejecutada: ${high}% del tiempo en Z4–Z5.`);
  }
  if (easyType && session.rpe && session.rpe >= 7) {
    add('warn', `RPE ${session.rpe} en un rodaje ${type === 'long' ? 'largo' : 'suave'}: si te costó tanto, baja el ritmo o revisa sueño/fatiga.`);
  }

  if (isRun(session) && session.averageCadence > 0) {
    if (session.averageCadence < 160) {
      add('info', `Cadencia ${Math.round(session.averageCadence)} ppm: prueba pasos más cortos y subirla ~5% para reducir impacto.`);
    } else if (session.averageCadence >= 170) {
      add('good', `Cadencia ${Math.round(session.averageCadence)} ppm: eficiente.`);
    }
  }

  let comparison = null;
  const prev = findComparable(session, type, history);
  if (prev && pace > 0) {
    const prevPace = paceOf(prev.distance, prev.movingTime);
    const paceDiff = round(pace - prevPace);
    const hrDiff = session.averageHeartRate > 0 && prev.averageHeartRate > 0
      ? round(session.averageHeartRate - prev.averageHeartRate)
      : null;
    comparison = {
      sessionId: prev._id,
      title: prev.title,
      date: prev.startDate,
      paceDiffSec: paceDiff,
      hrDiff
    };
    const paceTxt = paceDiff < 0 ? `${Math.abs(paceDiff)} s/km más rápido` : paceDiff > 0 ? `${paceDiff} s/km más lento` : 'al mismo ritmo';
    if (hrDiff !== null) {
      const hrTxt = hrDiff < 0 ? `${Math.abs(hrDiff)} ppm menos` : hrDiff > 0 ? `${hrDiff} ppm más` : 'la misma FC';
      const better = (paceDiff <= 0 && hrDiff <= 0) && (paceDiff < 0 || hrDiff < 0);
      add(better ? 'good' : 'info', `Vs tu sesión similar anterior: ${paceTxt} con ${hrTxt}${better ? ' → estás mejorando tu eficiencia.' : '.'}`);
    } else {
      add(paceDiff < 0 ? 'good' : 'info', `Vs tu sesión similar anterior: ${paceTxt}.`);
    }
  }

  if (!session.averageHeartRate) {
    add('info', session.rpe
      ? 'Sin datos de FC: la carga se estimó con tu RPE.'
      : 'Sin FC ni RPE: anota tu esfuerzo percibido (RPE) para medir mejor la carga.');
  } else if (!hr.maxHR) {
    add('info', 'Configura tu FC máxima en el perfil de entrenamiento para ver zonas y carga precisa.');
  }

  return {
    type,
    load,
    loadSource,
    pace: round(pace),
    hrPercentMax: hrPct,
    efficiency,
    zones,
    splits: splitInfo,
    comparison,
    insights
  };
}

// ---------------------------------------------------------------------------
// VDOT (Jack Daniels)

function vo2AtVelocity(v) { // v en m/min
  return -4.6 + 0.182258 * v + 0.000104 * v * v;
}

function fractionOfMax(minutes) {
  return 0.8 + 0.1894393 * Math.exp(-0.012778 * minutes) + 0.2989558 * Math.exp(-0.1932605 * minutes);
}

function vdotFromPerformance(distanceM, seconds) {
  if (!distanceM || !seconds) return 0;
  const minutes = seconds / 60;
  return vo2AtVelocity(distanceM / minutes) / fractionOfMax(minutes);
}

function velocityForVo2(vo2) {
  const a = 0.000104;
  const b = 0.182258;
  const c = -(4.6 + vo2);
  return (-b + Math.sqrt(b * b - 4 * a * c)) / (2 * a);
}

function predictTime(vdot, distanceM) {
  let lo = 60;
  let hi = 60 * 60 * 10;
  for (let i = 0; i < 60; i++) {
    const midT = (lo + hi) / 2;
    if (vdotFromPerformance(distanceM, midT) > vdot) lo = midT; else hi = midT;
  }
  return Math.round((lo + hi) / 2);
}

function trainingPaces(vdot) {
  const paceAt = (frac) => 60000 / velocityForVo2(vdot * frac); // s/km
  return {
    easy: { from: round(paceAt(0.7)), to: round(paceAt(0.62)) },
    marathon: round(paceAt(0.81)),
    threshold: round(paceAt(0.88)),
    interval: round(paceAt(0.98)),
    repetition: round(paceAt(1.05))
  };
}

const PREDICTION_DISTANCES = [
  { key: '5k', label: '5K', meters: 5000 },
  { key: '10k', label: '10K', meters: 10000 },
  { key: 'half', label: 'Media maratón', meters: 21097.5 },
  { key: 'marathon', label: 'Maratón', meters: 42195 }
];

function estimateFitness(sessions, now) {
  const since = now.getTime() - 90 * DAY_MS;
  let best = null;
  for (const s of sessions) {
    if (!isRun(s) || new Date(s.startDate).getTime() < since) continue;
    const candidates = [];
    if (s.distance >= 3000 && s.movingTime >= 12 * 60) {
      candidates.push({ distance: s.distance, time: s.movingTime, label: 'actividad completa' });
    }
    for (const e of s.bestEfforts || []) {
      if (e.distance >= 3000 && e.elapsedTime > 0) {
        candidates.push({ distance: e.distance, time: e.elapsedTime, label: `mejor ${e.name}` });
      }
    }
    for (const c of candidates) {
      const v = vdotFromPerformance(c.distance, c.time);
      if (v > 20 && v < 90 && (!best || v > best.vdot)) {
        best = { vdot: v, sessionId: s._id, date: s.startDate, title: s.title, effort: c.label, distance: c.distance, time: c.time };
      }
    }
  }
  if (!best) return null;
  const vdot = round(best.vdot, 1);
  return {
    vdot,
    basedOn: { sessionId: best.sessionId, title: best.title, date: best.date, effort: best.effort, distance: Math.round(best.distance), time: Math.round(best.time) },
    predictions: PREDICTION_DISTANCES.map((d) => ({ ...d, timeSec: predictTime(vdot, d.meters) })),
    paces: trainingPaces(vdot)
  };
}

// ---------------------------------------------------------------------------
// Resumen / progresión

function localDayIndex(date) {
  return Math.floor((new Date(date).getTime() + TZ_OFFSET_MS) / DAY_MS);
}

// Lunes de la semana (índice de día local). 1970-01-01 fue jueves → +3.
function weekStartIndex(dayIndex) {
  return dayIndex - ((dayIndex + 3) % 7);
}

function dayIndexToIso(dayIndex) {
  return new Date(dayIndex * DAY_MS).toISOString().slice(0, 10);
}

function buildWeeks(analyzed, todayIdx, count = 12) {
  const currentWeek = weekStartIndex(todayIdx);
  const weeks = [];
  for (let i = count - 1; i >= 0; i--) {
    const start = currentWeek - i * 7;
    weeks.push({ start, weekStart: dayIndexToIso(start), distanceKm: 0, durationMin: 0, load: 0, sessions: 0, runs: 0, longestRunKm: 0, current: i === 0 });
  }
  for (const { s, a, day } of analyzed) {
    const w = weeks.find((x) => day >= x.start && day < x.start + 7);
    if (!w) continue;
    w.sessions += 1;
    w.durationMin += (s.movingTime || 0) / 60;
    w.load += a.load;
    if (isRun(s)) {
      w.runs += 1;
      w.distanceKm += (s.distance || 0) / 1000;
      w.longestRunKm = Math.max(w.longestRunKm, (s.distance || 0) / 1000);
    }
  }
  return weeks.map(({ start, ...w }) => ({
    ...w,
    distanceKm: round(w.distanceKm, 1),
    durationMin: Math.round(w.durationMin),
    load: Math.round(w.load),
    longestRunKm: round(w.longestRunKm, 1)
  }));
}

function computeLoadMetrics(analyzed, todayIdx) {
  const daily = new Map();
  for (const { a, day } of analyzed) daily.set(day, (daily.get(day) || 0) + a.load);
  const firstDay = analyzed.length ? Math.min(...analyzed.map((x) => x.day)) : todayIdx;

  let ctl = 0;
  let atl = 0;
  const history = [];
  for (let d = Math.max(firstDay, todayIdx - 180); d <= todayIdx; d++) {
    const load = daily.get(d) || 0;
    ctl += (load - ctl) / 42;
    atl += (load - atl) / 7;
    if (todayIdx - d < 42) history.push({ date: dayIndexToIso(d), ctl: round(ctl, 1), atl: round(atl, 1), tsb: round(ctl - atl, 1) });
  }

  let acute = 0;
  let chronic = 0;
  for (const [d, load] of daily) {
    if (todayIdx - d < 7) acute += load;
    if (todayIdx - d < 28) chronic += load;
  }
  const chronicWeekly = chronic / 4;
  const dataDays = todayIdx - firstDay + 1;
  const acwr = chronicWeekly > 0 ? round(acute / chronicWeekly, 2) : null;

  let status = 'optimal';
  if (dataDays < 21 || acwr === null) status = 'building';
  else if (acwr > 1.5) status = 'danger';
  else if (acwr > 1.3) status = 'caution';
  else if (acwr < 0.8) status = 'detraining';

  const tsb = round(ctl - atl, 1);
  let form = 'neutral';
  if (tsb > 15) form = 'fresh';
  else if (tsb < -30) form = 'overreached';
  else if (tsb < -10) form = 'productive';

  return {
    ctl: round(ctl, 1),
    atl: round(atl, 1),
    tsb,
    form,
    acuteLoad: Math.round(acute),
    chronicWeeklyLoad: Math.round(chronicWeekly),
    acwr,
    status,
    dataDays,
    history
  };
}

function intensityDistribution(analyzed, todayIdx) {
  const secs = [0, 0, 0, 0, 0];
  for (const { a, day } of analyzed) {
    if (todayIdx - day >= 28 || !a.zones) continue;
    a.zones.seconds.forEach((v, i) => { secs[i] += v; });
  }
  const total = secs.reduce((x, y) => x + y, 0);
  if (total < 60 * 60) return null; // < 1 h con FC: poco significativo
  return {
    low: round(((secs[0] + secs[1]) / total) * 100),
    moderate: round((secs[2] / total) * 100),
    high: round(((secs[3] + secs[4]) / total) * 100),
    hours: round(total / 3600, 1)
  };
}

function efficiencyTrend(analyzed, todayIdx) {
  const easy = analyzed.filter(({ s, a }) => isRun(s) && a.efficiency && ['easy', 'long', 'recovery'].includes(a.type));
  const recent = easy.filter(({ day }) => todayIdx - day < 21).map(({ a }) => a.efficiency);
  const prior = easy.filter(({ day }) => todayIdx - day >= 21 && todayIdx - day < 63).map(({ a }) => a.efficiency);
  if (recent.length < 2 || prior.length < 2) return null;
  const avg = (arr) => arr.reduce((x, y) => x + y, 0) / arr.length;
  const changePct = round(((avg(recent) - avg(prior)) / avg(prior)) * 100, 1);
  return { recent: round(avg(recent), 3), prior: round(avg(prior), 3), changePct };
}

function goalStatus(profile, fitness, now) {
  const g = profile && profile.goal;
  if (!g || !g.distanceKm) return null;
  const meters = g.distanceKm * 1000;
  const weeksLeft = g.date ? round((new Date(g.date).getTime() - now.getTime()) / (7 * DAY_MS), 1) : null;

  let phase = null;
  if (weeksLeft !== null) {
    if (weeksLeft < 0) phase = 'done';
    else if (weeksLeft <= 2) phase = 'taper';
    else if (weeksLeft <= 6) phase = 'peak';
    else if (weeksLeft <= 12) phase = 'build';
    else phase = 'base';
  }

  const result = { name: g.name || `${g.distanceKm} km`, distanceKm: g.distanceKm, targetTimeSec: g.targetTimeSec || null, date: g.date || null, weeksLeft, phase };
  if (!fitness) return { ...result, status: 'no_data' };

  result.predictedTimeSec = predictTime(fitness.vdot, meters);
  if (!g.targetTimeSec) return { ...result, status: 'no_target' };

  const requiredVdot = round(vdotFromPerformance(meters, g.targetTimeSec), 1);
  const gap = round(requiredVdot - fitness.vdot, 1);
  result.requiredVdot = requiredVdot;
  result.vdotGap = gap;
  if (gap <= 0) result.status = 'on_track';
  else if (weeksLeft === null || weeksLeft <= 0) result.status = 'behind';
  else {
    const perWeek = gap / weeksLeft;
    result.vdotPerWeekNeeded = round(perWeek, 2);
    result.status = perWeek <= 0.3 ? 'achievable' : perWeek <= 0.6 ? 'ambitious' : 'unrealistic';
  }
  return result;
}

const roundHalf = (n) => Math.round(n * 2) / 2;

function sessionPlan(targetKm, sessionsPerWeek, mode, fitness) {
  const n = clamp(sessionsPerWeek || 4, 2, 7);
  const p = fitness && fitness.paces;
  const easyPace = p ? `${formatPace(p.easy.from)}–${formatPace(p.easy.to)}` : 'RPE 3–4 (puedes conversar)';
  const plan = [];
  const lightWeek = ['deload', 'reduce', 'taper'].includes(mode);

  let qualityCount = n >= 5 ? 2 : n >= 3 ? 1 : 0;
  if (lightWeek) qualityCount = Math.min(qualityCount, 1);
  const longKm = n >= 3 ? roundHalf(targetKm * (lightWeek ? 0.25 : 0.3)) : 0;
  const qualityKm = roundHalf(targetKm * 0.18);

  if (longKm > 0) {
    plan.push({
      type: 'long',
      distanceKm: longKm,
      pace: easyPace,
      description: mode === 'build' && p
        ? `Tirada larga cómoda. Si te sientes bien, últimos 15 min a ritmo maratón (${formatPace(p.marathon)}).`
        : 'Tirada larga a ritmo cómodo y constante.'
    });
  }
  if (qualityCount >= 1) {
    plan.push({
      type: 'tempo',
      distanceKm: qualityKm,
      pace: p ? formatPace(p.threshold) : 'RPE 7 (cómodamente duro)',
      description: lightWeek
        ? '15 min suave + 2 × 8 min a ritmo umbral (2 min trote) + 10 min suave.'
        : '15 min suave + 20–30 min a ritmo umbral + 10 min suave.'
    });
  }
  if (qualityCount >= 2) {
    plan.push({
      type: 'intervals',
      distanceKm: qualityKm,
      pace: p ? formatPace(p.interval) : 'RPE 8–9',
      description: '15 min suave + 5–6 × 1000 m a ritmo I con 2–3 min de trote + 10 min suave.'
    });
  }
  const easyCount = n - plan.length;
  const used = plan.reduce((a, x) => a + x.distanceKm, 0);
  const easyKm = easyCount > 0 ? Math.max(3, roundHalf((targetKm - used) / easyCount)) : 0;
  for (let i = 0; i < easyCount; i++) {
    const recovery = i === 0 && (lightWeek || qualityCount >= 2);
    plan.push({
      type: recovery ? 'recovery' : 'easy',
      distanceKm: recovery ? Math.max(3, roundHalf(easyKm * 0.8)) : easyKm,
      pace: easyPace,
      description: recovery ? 'Trote regenerativo muy suave, Z1–Z2.' : 'Rodaje suave en Z2. Añade 4–6 progresivos de 20 s al final.'
    });
  }
  return plan;
}

function weeklyRecommendation({ weeks, load, fitness, goal, intensity, profile }) {
  const full = weeks.filter((w) => !w.current);
  const lastWeek = full[full.length - 1] || { distanceKm: 0, sessions: 0 };
  const last4 = full.slice(-4);
  const avg4 = last4.length ? last4.reduce((a, w) => a + w.distanceKm, 0) / last4.length : 0;
  const last4Sessions = last4.length ? last4.reduce((a, w) => a + w.runs, 0) / last4.length : 0;
  const reasons = [];

  let base = lastWeek.distanceKm || avg4;
  let mode = 'build';
  let factor = 1.08;

  if (!base) {
    mode = 'start';
    base = 15;
    factor = 1;
    reasons.push('Aún no hay volumen reciente: empieza con ~15 km repartidos en 3–4 salidas suaves.');
  } else if (goal && goal.phase === 'taper' && goal.weeksLeft !== null) {
    mode = 'taper';
    factor = goal.weeksLeft <= 1 ? 0.5 : 0.7;
    reasons.push(`Faltan ${goal.weeksLeft} semanas para ${goal.name}: reduce volumen y mantén algo de ritmo para llegar fresco.`);
  } else if (load.status === 'danger' || load.form === 'overreached') {
    mode = 'reduce';
    factor = 0.75;
    reasons.push(load.status === 'danger'
      ? `Carga aguda ${load.acwr}× tu carga habitual (riesgo alto de lesión > 1.5). Baja el volumen ~25%.`
      : `Fatiga acumulada alta (forma ${load.tsb}). Baja el volumen ~25% para asimilar.`);
  } else if (load.status === 'caution' || load.tsb < -20) {
    mode = 'hold';
    factor = 1;
    reasons.push('Subiste carga rápido: mantén el volumen esta semana antes de seguir progresando.');
  } else {
    const last3 = full.slice(-4).map((w) => w.distanceKm);
    let increases = 0;
    for (let i = 1; i < last3.length; i++) if (last3[i] > last3[i - 1] * 1.02) increases++;
    if (increases >= 3) {
      mode = 'deload';
      factor = 0.75;
      reasons.push('Llevas 3 semanas subiendo volumen: toca semana de descarga (−25%) para consolidar la adaptación.');
    } else if (load.status === 'detraining' && avg4 > lastWeek.distanceKm) {
      mode = 'rebuild';
      base = Math.min(avg4, lastWeek.distanceKm * 1.2 || avg4);
      factor = 1;
      reasons.push('Tu carga bajó respecto a lo habitual: recupera volumen de forma gradual.');
    } else {
      reasons.push('Carga en zona óptima: puedes subir ~8% de volumen (regla de no superar 10%).');
    }
  }

  if (intensity) {
    if (intensity.low < 70) {
      reasons.push(`Solo ${intensity.low}% de tu tiempo fue suave (Z1–Z2). Apunta a ~80% suave / 20% intenso para progresar sin quemarte.`);
    } else if (intensity.high < 5 && mode === 'build') {
      reasons.push('Casi todo es suave: añade 1 sesión de calidad por semana para mejorar tu ritmo.');
    }
  }
  if (goal && goal.status === 'unrealistic') {
    reasons.push(`El objetivo de ${goal.name} requiere VDOT ${goal.requiredVdot} (tienes ${fitness.vdot}): considera ajustar la marca o la fecha.`);
  }

  const targetKm = roundHalf(base * factor);
  const sessions = profile && profile.weeklySessions ? profile.weeklySessions : clamp(Math.round(last4Sessions) || 4, 3, 6);
  return {
    mode,
    targetKm,
    lastWeekKm: lastWeek.distanceKm,
    longRunMaxKm: roundHalf(targetKm * 0.35),
    sessions,
    reasons,
    plan: sessionPlan(targetKm, sessions, mode, fitness)
  };
}

/**
 * Resumen completo. `sessions`: sesiones del usuario (≥ 120 días idealmente),
 * `profile`: TrainingProfile o null, `now`: Date.
 */
function buildTrainingSummary(sessions, profile, now = new Date()) {
  const hr = heartRateContext(profile, sessions);
  const todayIdx = localDayIndex(now);
  const sorted = [...sessions].sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
  const analyzed = sorted.map((s) => ({ s, a: analyzeSession(s, hr), day: localDayIndex(s.startDate) }));

  const weeks = buildWeeks(analyzed, todayIdx);
  const load = computeLoadMetrics(analyzed, todayIdx);
  const fitness = estimateFitness(sorted, now);
  const intensity = intensityDistribution(analyzed, todayIdx);
  const efficiency = efficiencyTrend(analyzed, todayIdx);
  const goal = goalStatus(profile, fitness, now);
  const recommendation = weeklyRecommendation({ weeks, load, fitness, goal, intensity, profile });

  return {
    heartRate: hr,
    weeks,
    load,
    fitness,
    intensity,
    efficiency,
    goal,
    recommendation,
    totals: {
      sessions: sorted.length,
      last30DaysKm: round(analyzed.filter(({ s, day }) => isRun(s) && todayIdx - day < 30).reduce((a, { s }) => a + s.distance / 1000, 0), 1)
    }
  };
}

module.exports = {
  heartRateContext,
  hrZone,
  computeLoad,
  analyzeSplits,
  classifySession,
  analyzeSession,
  vdotFromPerformance,
  predictTime,
  trainingPaces,
  estimateFitness,
  buildTrainingSummary,
  weeklyRecommendation,
  localDayIndex,
  weekStartIndex,
  formatPace,
  formatDuration
};
