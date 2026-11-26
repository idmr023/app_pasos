const test = require('node:test');
const assert = require('node:assert/strict');
const { computeNext, parsePrescription, roundToIncrement } = require('../services/progressionService');

const progressing = (weightKg, extra = {}) => ({ currentWeightKg: weightKg, status: 'progressing', ...extra });
const sets = (weightKg, reps) => reps.map((r) => ({ weightKg, reps: r }));

test('parsePrescription deriva rango, tiempo y "Al fallo"', () => {
  assert.deepEqual(
    [parsePrescription({ sets: 4, reps: '6-10' }).repsMin, parsePrescription({ sets: 4, reps: '6-10' }).repsMax],
    [6, 10],
  );
  const single = parsePrescription({ reps: '10' });
  assert.equal(single.repsMin, 10);
  assert.equal(single.repsMax, 10);
  const timed = parsePrescription({ sets: 4, reps: '45s' });
  assert.equal(timed.isTimed, true);
  assert.equal(timed.targetSeconds, 45);
  assert.equal(parsePrescription({ reps: 'Al fallo' }).mode, 'none');
  // Los campos explícitos ganan sobre el texto.
  const explicit = parsePrescription({ reps: '10', repsMin: 8, repsMax: 12, incrementKg: 2 });
  assert.deepEqual([explicit.repsMin, explicit.repsMax, explicit.incrementKg], [8, 12, 2]);
});

test('Press de pecho 15 kg, 6-6-6-6 → mantener, objetivo 7', () => {
  const p = parsePrescription({ sets: 4, reps: '6-10', incrementKg: 2.5 });
  const { suggestion, state } = computeNext(p, progressing(15), sets(15, [6, 6, 6, 6]));
  assert.equal(suggestion.action, 'hold');
  assert.equal(suggestion.weightKg, 15);
  assert.equal(suggestion.targetReps, 7);
  assert.equal(state.currentWeightKg, 15);
});

test('Press de pecho 15 kg, 10-10-10-10 → sube a 17.5 kg sin puente', () => {
  const p = parsePrescription({ sets: 4, reps: '6-10', incrementKg: 2.5 });
  const { suggestion, state } = computeNext(p, progressing(15), sets(15, [10, 10, 10, 10]));
  assert.equal(suggestion.action, 'increase');
  assert.equal(suggestion.weightKg, 17.5);
  assert.equal(suggestion.targetReps, 6);
  assert.equal(state.currentWeightKg, 17.5);
  assert.equal(state.previousWeightKg, 15);
  assert.match(suggestion.message, /Sube a 17.5 kg/);
});

test('Elevaciones laterales 7.5 kg, 15-15-15 → puente con 10 kg', () => {
  const p = parsePrescription({ sets: 3, reps: '12-15', incrementKg: 2.5 });
  const { suggestion, state } = computeNext(p, progressing(7.5), sets(7.5, [15, 15, 15]));
  assert.equal(suggestion.action, 'bridge');
  assert.equal(suggestion.weightKg, 10);
  assert.equal(suggestion.heavySets, 1);
  assert.equal(suggestion.baseWeightKg, 7.5);
  assert.equal(state.status, 'bridge');
  assert.equal(state.currentWeightKg, 7.5);
  assert.match(suggestion.message, /1 serie con 10 kg y 2 con 7.5 kg/);
});

test('Elevaciones laterales en puente, 10/15/14 → 2 series pesadas', () => {
  const p = parsePrescription({ sets: 3, reps: '12-15', incrementKg: 2.5 });
  const prev = progressing(7.5, { status: 'bridge', bridgeTargetKg: 10, bridgeHeavySets: 1 });
  const session = [{ weightKg: 10, reps: 10 }, { weightKg: 7.5, reps: 15 }, { weightKg: 7.5, reps: 14 }];
  const { suggestion, state } = computeNext(p, prev, session);
  assert.equal(suggestion.action, 'bridge');
  assert.equal(suggestion.heavySets, 2);
  assert.equal(state.bridgeHeavySets, 2);
  assert.match(suggestion.message, /2 series con 10 kg y 1 con 7.5 kg/);
});

test('Puente: si la última serie pesada no llega al umbral, no avanza', () => {
  const p = parsePrescription({ sets: 3, reps: '12-15', incrementKg: 2.5 });
  const prev = progressing(7.5, { status: 'bridge', bridgeTargetKg: 10, bridgeHeavySets: 2 });
  const session = [{ weightKg: 10, reps: 11 }, { weightKg: 10, reps: 8 }, { weightKg: 7.5, reps: 14 }];
  const { suggestion } = computeNext(p, prev, session);
  assert.equal(suggestion.heavySets, 2);
});

test('Puente: con todas las series pesadas el peso nuevo pasa a ser la base', () => {
  const p = parsePrescription({ sets: 3, reps: '12-15', incrementKg: 2.5 });
  const prev = progressing(7.5, { status: 'bridge', bridgeTargetKg: 10, bridgeHeavySets: 2 });
  const session = [{ weightKg: 10, reps: 12 }, { weightKg: 10, reps: 10 }, { weightKg: 7.5, reps: 15 }];
  const { suggestion, state } = computeNext(p, prev, session);
  assert.equal(suggestion.action, 'increase');
  assert.equal(state.status, 'progressing');
  assert.equal(state.currentWeightKg, 10);
  assert.equal(state.bridgeTargetKg, 0);
});

test('Curl con mancuernas 12 kg, 6-6-5 → mantener, objetivo 6 en la tercera', () => {
  const p = parsePrescription({ sets: 3, reps: '6-10', incrementKg: 2 });
  const { suggestion } = computeNext(p, progressing(12), sets(12, [6, 6, 5]));
  assert.equal(suggestion.action, 'hold');
  assert.equal(suggestion.weightKg, 12);
  assert.equal(suggestion.targetReps, 6);
  assert.match(suggestion.message, /la serie 3/);
});

test('Press francés barra Z 10 kg, 12-12-12 → puente con 12.5 kg (salto 25 %)', () => {
  const p = parsePrescription({ sets: 3, reps: '10-12', incrementKg: 2.5 });
  const { suggestion } = computeNext(p, progressing(10), sets(10, [12, 12, 12]));
  assert.equal(suggestion.action, 'bridge');
  assert.equal(suggestion.weightKg, 12.5);
  assert.equal(suggestion.heavySets, 1);
});

test('Remo en discos 15 kg, 10-9-9 tres sesiones → estancamiento a 12.5 kg', () => {
  const p = parsePrescription({ sets: 3, reps: '10-12', incrementKg: 2.5 });
  let state = progressing(15);
  let r = computeNext(p, state, sets(15, [10, 9, 9]));
  assert.equal(r.suggestion.action, 'hold');
  r = computeNext(p, r.state, sets(15, [10, 9, 9]));
  assert.equal(r.suggestion.action, 'hold');
  assert.equal(r.state.stallCount, 1);
  r = computeNext(p, r.state, sets(15, [10, 9, 9]));
  assert.equal(r.suggestion.action, 'deload');
  assert.equal(r.suggestion.weightKg, 12.5);
  assert.equal(r.state.currentWeightKg, 12.5);
  assert.equal(r.state.stallCount, 0);
});

test('Mejorar repeticiones reinicia el estancamiento', () => {
  const p = parsePrescription({ sets: 3, reps: '10-12', incrementKg: 2.5 });
  let r = computeNext(p, progressing(15), sets(15, [10, 9, 9]));
  r = computeNext(p, r.state, sets(15, [10, 9, 9]));
  assert.equal(r.state.stallCount, 1);
  r = computeNext(p, r.state, sets(15, [10, 10, 9]));
  assert.equal(r.state.stallCount, 0);
  assert.equal(r.suggestion.action, 'hold');
});

test('Sentadilla en pared 4 × 45s completas → sugerir 50 s', () => {
  const p = parsePrescription({ sets: 4, reps: '45s' });
  const session = [1, 2, 3, 4].map(() => ({ weightKg: 0, reps: 0, seconds: 45 }));
  const { suggestion, state } = computeNext(p, null, session);
  assert.equal(suggestion.action, 'increase');
  assert.equal(suggestion.targetSeconds, 50);
  assert.equal(state.currentSeconds, 50);
});

test('R5: primera serie bajo la tolerancia → vuelve al peso anterior', () => {
  const p = parsePrescription({ sets: 4, reps: '6-10', incrementKg: 2.5 });
  const prev = progressing(17.5, { previousWeightKg: 15 });
  const { suggestion, state } = computeNext(p, prev, sets(17.5, [4, 4, 3, 3]));
  assert.equal(suggestion.action, 'decrease');
  assert.equal(suggestion.weightKg, 15);
  assert.equal(state.currentWeightKg, 15);
});

test('Sin base: la primera sesión fija la base y evalúa la sesión', () => {
  const p = parsePrescription({ sets: 4, reps: '6-10', incrementKg: 2.5 });
  const { suggestion, state } = computeNext(p, null, sets(15, [6, 6, 6, 6]));
  assert.equal(state.currentWeightKg, 15);
  assert.equal(state.status, 'progressing');
  assert.equal(suggestion.action, 'hold');
  assert.equal(suggestion.targetReps, 7);
});

test('Sin base: la calibración prefiere la serie con 2-3 repeticiones en reserva', () => {
  const p = parsePrescription({ sets: 3, reps: '6-10', incrementKg: 2.5 });
  const session = [
    { weightKg: 10, reps: 8, rir: 5 },
    { weightKg: 12.5, reps: 8, rir: 2 },
    { weightKg: 15, reps: 6, rir: 0 },
  ];
  const { state } = computeNext(p, null, session);
  assert.equal(state.currentWeightKg, 12.5);
});

test('Sin base y sin llegar al piso → sugiere un escalón menos', () => {
  const p = parsePrescription({ sets: 3, reps: '10-12', incrementKg: 2.5 });
  const { suggestion, state } = computeNext(p, null, sets(20, [6, 5, 4]));
  assert.equal(suggestion.action, 'calibrate');
  assert.equal(suggestion.weightKg, 17.5);
  assert.equal(state.currentWeightKg, 0);
});

test('reps no numérico ("Al fallo") → sin sugerencia', () => {
  const p = parsePrescription({ sets: 3, reps: 'Al fallo' });
  const { suggestion, state } = computeNext(p, null, sets(20, [12, 10, 8]));
  assert.equal(suggestion, null);
  assert.ok(state.lastSession);
});

test('Incremento 0: al tope no sube y lo avisa', () => {
  const p = parsePrescription({ sets: 3, reps: '6-10', incrementKg: 0 });
  const { suggestion } = computeNext(p, progressing(20), sets(20, [10, 10, 10]));
  assert.equal(suggestion.action, 'hold');
  assert.equal(suggestion.weightKg, 20);
});

test('Sesión con menos series que la rutina no sube de peso', () => {
  const p = parsePrescription({ sets: 4, reps: '6-10', incrementKg: 2.5 });
  const { suggestion } = computeNext(p, progressing(15), sets(15, [10, 10]));
  assert.equal(suggestion.action, 'hold');
});

test('Sesión vacía no cambia el estado', () => {
  const p = parsePrescription({ sets: 3, reps: '6-10' });
  const { state, suggestion } = computeNext(p, progressing(15), []);
  assert.equal(state.currentWeightKg, 15);
  assert.equal(suggestion, null);
});

test('roundToIncrement redondea a múltiplos del incremento', () => {
  assert.equal(roundToIncrement(13.5, 2.5), 12.5);
  assert.equal(roundToIncrement(16.4, 2), 16);
  assert.equal(roundToIncrement(10.3, 0), 10.5);
});
