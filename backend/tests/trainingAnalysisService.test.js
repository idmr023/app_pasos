const test = require('node:test');
const assert = require('node:assert/strict');
const t = require('../services/trainingAnalysisService');

const DAY = 24 * 60 * 60 * 1000;
const NOW = new Date('2026-11-26T15:00:00Z'); // jueves
const hr = { maxHR: 190, restHR: 50 };

let seq = 0;
function run({ daysAgo = 0, km = 10, paceSec = 330, avgHR = 0, maxHR = 0, rpe = null, splits, bestEfforts = [], ...rest } = {}) {
  const distance = km * 1000;
  const movingTime = Math.round(km * paceSec);
  return {
    _id: `s${++seq}`,
    sport: 'run',
    title: 'Rodaje',
    startDate: new Date(NOW.getTime() - daysAgo * DAY),
    distance,
    movingTime,
    averageSpeed: distance / movingTime,
    averageHeartRate: avgHR,
    maxHeartRate: maxHR,
    elevationGain: 0,
    rpe,
    splits: splits || [],
    laps: [],
    bestEfforts,
    sessionType: 'auto',
    ...rest
  };
}

const evenSplits = (n, paceSec, hrs) => Array.from({ length: n }, (_, i) => ({
  index: i + 1, distance: 1000, movingTime: paceSec, averageHeartRate: hrs ? hrs[i] : 0, averageSpeed: 1000 / paceSec
}));

test('VDOT de Daniels: 5K en 20:00 ≈ 49.8 y predicción coherente', () => {
  const vdot = t.vdotFromPerformance(5000, 20 * 60);
  assert.ok(Math.abs(vdot - 49.8) < 0.4, `vdot ${vdot}`);
  const predicted = t.predictTime(vdot, 5000);
  assert.ok(Math.abs(predicted - 1200) <= 2);
  // 10K para VDOT ~50 ≈ 41:30
  const tenK = t.predictTime(vdot, 10000);
  assert.ok(tenK > 40 * 60 && tenK < 43 * 60, `10k ${tenK}`);
});

test('Ritmos de entrenamiento para VDOT 50 cercanos a las tablas de Daniels', () => {
  const p = t.trainingPaces(50);
  assert.ok(Math.abs(p.threshold - 255) <= 6, `T ${p.threshold}`); // 4:15/km
  assert.ok(Math.abs(p.interval - 235) <= 8, `I ${p.interval}`);   // ~3:55/km
  assert.ok(p.easy.from < p.easy.to);
  assert.ok(p.repetition < p.interval && p.interval < p.threshold && p.threshold < p.marathon);
});

test('Carga: TRIMP con FC, RPE como respaldo y estimación sin datos', () => {
  const withHr = t.computeLoad(run({ km: 10, paceSec: 360, avgHR: 140 }), hr);
  assert.equal(withHr.source, 'hr');
  assert.ok(withHr.load > 60 && withHr.load < 120, `trimp ${withHr.load}`);
  const withRpe = t.computeLoad(run({ km: 10, paceSec: 360, rpe: 4 }), { maxHR: null, restHR: 60 });
  assert.equal(withRpe.source, 'rpe');
  assert.equal(withRpe.load, 96); // 60 min × 4 × 0.4
  assert.equal(t.computeLoad(run({ km: 10, paceSec: 360 }), { maxHR: null, restHR: 60 }).source, 'estimated');
});

test('Splits: detecta split negativo y desacople cardíaco', () => {
  const splits = [
    ...evenSplits(5, 340, [140, 141, 142, 143, 144]),
    ...evenSplits(5, 320, [146, 147, 148, 149, 150])
  ].map((s, i) => ({ ...s, index: i + 1 }));
  const info = t.analyzeSplits(run({ splits }));
  assert.equal(info.splitType, 'negative');
  assert.equal(info.halfDiffSec, -20);
  assert.ok(info.decouplingPct !== null);
});

test('Clasificación: rodaje suave, tirada larga, tempo, series y carrera', () => {
  assert.equal(t.classifySession(run({ km: 10, avgHR: 125 }), hr, null), 'easy');
  assert.equal(t.classifySession(run({ km: 5, paceSec: 380, avgHR: 120 }), hr, null), 'recovery');
  assert.equal(t.classifySession(run({ km: 18, avgHR: 140 }), hr, null), 'long');
  assert.equal(t.classifySession(run({ km: 8, paceSec: 270, avgHR: 168 }), hr, null), 'tempo');
  const intervals = run({ km: 8, splits: [300, 240, 330, 240, 330, 240, 330, 300].map((p, i) => ({ index: i + 1, distance: 1000, movingTime: p })) });
  assert.equal(t.classifySession(intervals, hr, t.analyzeSplits(intervals)), 'intervals');
  assert.equal(t.classifySession(run({ stravaWorkoutType: 1 }), hr, null), 'race');
  assert.equal(t.classifySession(run({ sessionType: 'tempo', avgHR: 110 }), hr, null), 'tempo');
});

test('Análisis de sesión avisa de rodaje suave demasiado intenso y compara con la anterior', () => {
  const prev = run({ daysAgo: 7, km: 10, paceSec: 340, avgHR: 150 });
  const cur = run({ daysAgo: 0, km: 10, paceSec: 330, avgHR: 145, splits: evenSplits(10, 330, Array(10).fill(160)), sessionType: 'easy' });
  const a = t.analyzeSession(cur, hr, [prev]);
  assert.ok(a.insights.some((i) => i.level === 'warn' && /demasiado intenso/.test(i.text)));
  assert.equal(a.comparison.paceDiffSec, -10);
  assert.equal(a.comparison.hrDiff, -5);
  assert.ok(a.insights.some((i) => /mejorando/.test(i.text)));
});

test('Semana empieza en lunes (hora de Lima)', () => {
  const thursday = t.localDayIndex(NOW);
  const monday = t.weekStartIndex(thursday);
  assert.equal(thursday - monday, 3);
  assert.equal(new Date(monday * DAY).getUTCDay(), 1);
});

test('Resumen: progresión estable → subir ~8% con plan 80/20', () => {
  const sessions = [];
  for (let w = 1; w <= 6; w++) {
    for (const d of [1, 3, 5]) sessions.push(run({ daysAgo: w * 7 + d - 3, km: 8, avgHR: 135, maxHR: 170 }));
  }
  const summary = t.buildTrainingSummary(sessions, { maxHeartRate: 190, restingHeartRate: 50, weeklySessions: 4 }, NOW);
  const rec = summary.recommendation;
  assert.ok(['build', 'hold'].includes(rec.mode), rec.mode);
  assert.ok(rec.targetKm >= rec.lastWeekKm);
  assert.equal(rec.plan.length, 4);
  assert.ok(rec.plan.some((p) => p.type === 'long'));
  assert.ok(rec.plan.some((p) => p.type === 'tempo'));
  assert.equal(summary.weeks.length, 12);
  assert.ok(summary.fitness && summary.fitness.vdot > 30);
});

test('Resumen: pico brusco de carga → reducir', () => {
  const sessions = [];
  for (let w = 1; w <= 5; w++) sessions.push(run({ daysAgo: w * 7, km: 5, avgHR: 140 }));
  for (let d = 0; d < 6; d++) sessions.push(run({ daysAgo: d, km: 15, avgHR: 165 }));
  const summary = t.buildTrainingSummary(sessions, { maxHeartRate: 190, restingHeartRate: 50 }, NOW);
  assert.equal(summary.load.status, 'danger');
  assert.equal(summary.recommendation.mode, 'reduce');
});

test('Resumen: 3 semanas subiendo volumen → semana de descarga', () => {
  const sessions = [];
  const kms = [20, 24, 28, 32]; // semanas -4 … -1
  kms.forEach((km, i) => {
    const weeksAgo = 4 - i;
    for (let k = 0; k < 4; k++) sessions.push(run({ daysAgo: weeksAgo * 7 + k - 2, km: km / 4, avgHR: 135 }));
  });
  const summary = t.buildTrainingSummary(sessions, { maxHeartRate: 190, restingHeartRate: 50 }, NOW);
  assert.equal(summary.recommendation.mode, 'deload');
  assert.ok(summary.recommendation.targetKm < summary.recommendation.lastWeekKm);
});

test('Objetivo: estado y fase según VDOT requerido y semanas restantes', () => {
  const sessions = [run({ daysAgo: 10, km: 5, paceSec: 240, bestEfforts: [{ name: '5K', distance: 5000, elapsedTime: 1200 }] })];
  const goalDate = new Date(NOW.getTime() + 10 * 7 * DAY);
  const easy = t.buildTrainingSummary(sessions, { goal: { distanceKm: 10, targetTimeSec: 44 * 60, date: goalDate } }, NOW);
  assert.equal(easy.goal.status, 'on_track');
  assert.equal(easy.goal.phase, 'build');
  const hard = t.buildTrainingSummary(sessions, { goal: { distanceKm: 10, targetTimeSec: 34 * 60, date: goalDate } }, NOW);
  assert.equal(hard.goal.status, 'unrealistic');
});

test('Sin sesiones: arranque con 15 km', () => {
  const summary = t.buildTrainingSummary([], null, NOW);
  assert.equal(summary.recommendation.mode, 'start');
  assert.equal(summary.recommendation.targetKm, 15);
  assert.equal(summary.fitness, null);
});
