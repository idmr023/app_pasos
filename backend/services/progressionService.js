/**
 * Motor de progresión de carga (doble progresión).
 *
 * Funciones puras, sin acceso a base de datos: reciben la prescripción de la
 * rutina, el estado guardado (ExerciseProgress) y las series reales de la
 * sesión, y devuelven el nuevo estado + la sugerencia para la próxima vez.
 * Reglas R1-R10 en docs/GYM_MODULE.md (sección "Progresión de carga").
 */

const BIG_JUMP_RATIO = 0.20;
const STALL_SESSIONS = 2;
const DELOAD_FACTOR = 0.90;
const TIME_STEP_S = 5;
const DEFAULT_INCREMENT_KG = 2.5;
const tolerance = (repsMin) => Math.max(5, repsMin - 2);

const EPS = 0.01;

function round2(n) {
  return Math.round(n * 100) / 100;
}

/** Redondea al múltiplo más cercano del incremento (0.5 kg si no hay incremento). */
function roundToIncrement(weightKg, incrementKg) {
  const step = incrementKg > 0 ? incrementKg : 0.5;
  return round2(Math.round(weightKg / step) * step);
}

function fmtKg(n) {
  return `${round2(n)} kg`;
}

function joinSeries(numbers) {
  if (numbers.length === 1) return `la serie ${numbers[0]}`;
  return `las series ${numbers.slice(0, -1).join(', ')} y ${numbers[numbers.length - 1]}`;
}

/**
 * Deriva la prescripción a partir de un ejercicio de rutina.
 * `reps`: "6-10" → 6-10; "10" → 10-10; "45s" → por tiempo; "Al fallo" → sin sugerencias.
 */
function parsePrescription(routineExercise = {}) {
  const sets = Math.max(1, parseInt(routineExercise.sets) || 3);
  const inc = Number(routineExercise.incrementKg);
  const incrementKg = Number.isFinite(inc) && inc >= 0 ? inc : DEFAULT_INCREMENT_KG;
  const reps = (routineExercise.reps ?? '').toString().trim().toLowerCase();

  const timed = reps.match(/^(\d+)\s*s/);
  if (timed) {
    return { sets, incrementKg, isTimed: true, targetSeconds: parseInt(timed[1]), repsMin: null, repsMax: null, mode: 'timed' };
  }

  let repsMin = Number(routineExercise.repsMin) || null;
  let repsMax = Number(routineExercise.repsMax) || null;
  if (!repsMin || !repsMax) {
    const range = reps.match(/^(\d+)\s*-\s*(\d+)$/);
    const single = reps.match(/^(\d+)$/);
    if (range) {
      repsMin = parseInt(range[1]);
      repsMax = parseInt(range[2]);
    } else if (single) {
      repsMin = repsMax = parseInt(single[1]);
    }
  }
  if (!repsMin || !repsMax || repsMin > repsMax) {
    return { sets, incrementKg, isTimed: false, repsMin: null, repsMax: null, mode: 'none' };
  }
  return { sets, incrementKg, isTimed: false, repsMin, repsMax, mode: 'reps' };
}

function defaultState() {
  return {
    currentWeightKg: 0,
    previousWeightKg: 0,
    currentSeconds: 0,
    status: 'calibrating',
    bridgeTargetKg: 0,
    bridgeHeavySets: 0,
    stallCount: 0,
    lastSession: null,
    next: null,
  };
}

function normalizeSession(session) {
  return (session || [])
    .map((s) => ({
      weightKg: Math.max(0, Number(s.weightKg) || 0),
      reps: Math.max(0, parseInt(s.reps) || 0),
      seconds: Math.max(0, parseInt(s.seconds) || 0),
      rir: s.rir === undefined || s.rir === null ? null : Number(s.rir),
    }));
}

/** Peso de trabajo: el más repetido en la sesión (empate → el mayor). */
function workingWeight(session) {
  const counts = new Map();
  for (const s of session) {
    const k = round2(s.weightKg);
    counts.set(k, (counts.get(k) || 0) + 1);
  }
  let best = 0;
  let bestCount = 0;
  for (const [w, c] of counts) {
    if (c > bestCount || (c === bestCount && w > best)) {
      best = w;
      bestCount = c;
    }
  }
  return best;
}

/**
 * Base de un ejercicio sin calibrar (R1).
 * Prioridad: serie con 2-3 repeticiones en reserva → mayor peso que llegó al piso
 * sin quedar al fallo → null (no se pudo determinar).
 */
function calibrationBase(session, repsMin) {
  const withRir = session.filter((s) => s.weightKg > 0 && s.rir !== null && s.rir >= 2 && s.rir <= 3);
  if (withRir.length) return withRir[withRir.length - 1].weightKg;
  const ok = session.filter((s) => s.weightKg > 0 && s.reps >= repsMin && !(s.rir !== null && s.rir < 2));
  if (ok.length) return Math.max(...ok.map((s) => s.weightKg));
  return null;
}

function suggestion(fields) {
  return {
    action: null,
    weightKg: 0,
    targetReps: null,
    heavySets: 0,
    baseWeightKg: 0,
    targetSeconds: null,
    message: '',
    ...fields,
  };
}

function holdSuggestion(prescription, weightKg, session) {
  const reps = session.map((s) => s.reps);
  const lowest = Math.min(...reps);
  const target = Math.min(prescription.repsMax, lowest + 1);
  const lowestSets = reps.map((r, i) => (r === lowest ? i + 1 : null)).filter(Boolean);
  const where = lowestSets.length < reps.length && session.length >= prescription.sets
    ? ` en ${joinSeries(lowestSets)}`
    : '';
  const kg = weightKg > 0 ? `Mantén ${fmtKg(weightKg)} y busca` : 'Busca';
  return suggestion({
    action: 'hold',
    weightKg,
    baseWeightKg: weightKg,
    targetReps: target,
    message: `${kg} ${target} repeticiones${where}`,
  });
}

function bridgeMessage(prescription, heavy, base) {
  const light = prescription.sets - heavy;
  const heavyTxt = heavy === 1 ? '1 serie' : `${heavy} series`;
  return `Puente: ${heavyTxt} con ${fmtKg(base.target)} y ${light} con ${fmtKg(base.current)}`;
}

function computeTimed(prescription, state, session) {
  const base = state.currentSeconds || prescription.targetSeconds;
  const done = session.length >= prescription.sets
    && session.every((s) => s.seconds === 0 || s.seconds >= base);
  if (done) {
    const next = base + TIME_STEP_S;
    state.currentSeconds = next;
    state.status = 'progressing';
    return suggestion({ action: 'increase', targetSeconds: next, message: `Sube a ${next} s por serie` });
  }
  state.currentSeconds = base;
  return suggestion({ action: 'hold', targetSeconds: base, message: `Mantén ${base} s y completa las ${prescription.sets} series` });
}

/**
 * @param prescription { sets, repsMin, repsMax, incrementKg, isTimed, targetSeconds, mode }
 * @param prevState    ExerciseProgress (o null)
 * @param rawSession   [{ weightKg, reps, seconds, rir? }]
 * @returns { state, suggestion } — suggestion es null si no hay nada que sugerir.
 */
function computeNext(prescription, prevState, rawSession) {
  const state = { ...defaultState(), ...(prevState || {}) };
  const session = normalizeSession(rawSession);
  if (!session.length) return { state, suggestion: state.next || null };

  const finish = (sugg, weightKg) => {
    state.lastSession = {
      date: new Date(),
      weightKg: weightKg ?? workingWeight(session),
      reps: session.map((s) => s.reps),
    };
    state.next = sugg;
    return { state, suggestion: sugg };
  };

  // R8: ejercicios por tiempo.
  if (prescription.isTimed) return finish(computeTimed(prescription, state, session), 0);
  // "Al fallo" u otro texto: se registra la sesión pero no se sugiere nada.
  if (prescription.mode !== 'reps') return finish(null);

  const { sets, repsMin, repsMax, incrementKg } = prescription;
  const tol = tolerance(repsMin);

  // Peso corporal: sin peso registrado y sin base.
  if (state.currentWeightKg === 0 && session.every((s) => s.weightKg === 0)) {
    const allTop = session.length >= sets && session.every((s) => s.reps >= repsMax);
    if (allTop) {
      return finish(suggestion({
        action: 'hold',
        targetReps: repsMax,
        message: 'Llegaste al tope: agrega peso o usa una variante más difícil',
      }), 0);
    }
    return finish(holdSuggestion(prescription, 0, session), 0);
  }

  // R1: calibración. Si se encuentra la base, se sigue evaluando la sesión con ella.
  if (state.currentWeightKg === 0) {
    const base = calibrationBase(session, repsMin);
    if (base === null) {
      const minW = Math.min(...session.filter((s) => s.weightKg > 0).map((s) => s.weightKg));
      const lower = roundToIncrement(Math.max(0, minW - (incrementKg || 0.5)), incrementKg);
      state.status = 'calibrating';
      return finish(suggestion({
        action: 'calibrate',
        weightKg: lower,
        targetReps: repsMin,
        message: `Prueba con ${fmtKg(lower)} para llegar a ${repsMin} repeticiones`,
      }));
    }
    state.currentWeightKg = base;
    state.status = 'progressing';
    state.stallCount = 0;
    // Sesión de prueba con varios pesos: solo fija la base, no se evalúa el rango.
    if (new Set(session.map((s) => round2(s.weightKg))).size > 1) {
      return finish(suggestion({
        action: 'hold',
        weightKg: base,
        baseWeightKg: base,
        targetReps: repsMin,
        message: `Base fijada en ${fmtKg(base)}: haz todas las series y busca ${repsMin} repeticiones`,
      }), base);
    }
  }

  // R6: puente en curso.
  if (state.status === 'bridge' && state.bridgeTargetKg > 0) {
    const heavy = session.filter((s) => s.weightKg >= state.bridgeTargetKg - EPS);
    let heavySets = state.bridgeHeavySets || 1;
    if (heavy.length) {
      const lastHeavy = heavy[heavy.length - 1];
      if (lastHeavy.reps >= tol) heavySets = Math.min(sets, heavy.length + 1);
      else heavySets = Math.max(1, heavy.length);
    }
    if (heavySets >= sets) {
      state.previousWeightKg = state.currentWeightKg;
      state.currentWeightKg = state.bridgeTargetKg;
      state.status = 'progressing';
      state.bridgeTargetKg = 0;
      state.bridgeHeavySets = 0;
      state.stallCount = 0;
      return finish(suggestion({
        action: 'increase',
        weightKg: state.currentWeightKg,
        baseWeightKg: state.currentWeightKg,
        targetReps: repsMin,
        message: `Puente completo: todas las series con ${fmtKg(state.currentWeightKg)}, busca ${repsMin} repeticiones`,
      }), state.previousWeightKg);
    }
    state.bridgeHeavySets = heavySets;
    return finish(suggestion({
      action: 'bridge',
      weightKg: state.bridgeTargetKg,
      baseWeightKg: state.currentWeightKg,
      heavySets,
      targetReps: tol,
      message: bridgeMessage(prescription, heavySets, { target: state.bridgeTargetKg, current: state.currentWeightKg }),
    }), state.currentWeightKg);
  }

  // Si el usuario usó otro peso del sugerido, manda lo que hizo de verdad.
  const used = workingWeight(session);
  if (used > 0 && Math.abs(used - state.currentWeightKg) > EPS) {
    if (used > state.currentWeightKg) state.previousWeightKg = state.currentWeightKg;
    else if (state.previousWeightKg >= used) state.previousWeightKg = 0;
    state.currentWeightKg = used;
  }
  const current = state.currentWeightKg;

  // R5: primera serie por debajo de la tolerancia → volver al peso anterior.
  if (session[0].reps < tol) {
    const prev = state.previousWeightKg > 0 && state.previousWeightKg < current
      ? state.previousWeightKg
      : roundToIncrement(Math.max(0, current - (incrementKg || 0.5)), incrementKg);
    state.currentWeightKg = prev;
    state.previousWeightKg = 0;
    state.stallCount = 0;
    return finish(suggestion({
      action: 'decrease',
      weightKg: prev,
      baseWeightKg: prev,
      targetReps: repsMin,
      message: `Baja a ${fmtKg(prev)} y busca ${repsMin} repeticiones`,
    }), current);
  }

  // R3 / R6: todas las series al tope.
  if (session.length >= sets && session.every((s) => s.reps >= repsMax)) {
    if (!(incrementKg > 0)) {
      return finish(suggestion({
        action: 'hold',
        weightKg: current,
        baseWeightKg: current,
        targetReps: repsMax,
        message: 'Llegaste al tope: define un incremento para subir de peso',
      }), current);
    }
    const target = roundToIncrement(current + incrementKg, incrementKg);
    state.stallCount = 0;
    if (current > 0 && incrementKg / current > BIG_JUMP_RATIO && sets > 1) {
      state.status = 'bridge';
      state.bridgeTargetKg = target;
      state.bridgeHeavySets = 1;
      return finish(suggestion({
        action: 'bridge',
        weightKg: target,
        baseWeightKg: current,
        heavySets: 1,
        targetReps: tol,
        message: bridgeMessage(prescription, 1, { target, current }),
      }), current);
    }
    state.previousWeightKg = current;
    state.currentWeightKg = target;
    return finish(suggestion({
      action: 'increase',
      weightKg: target,
      baseWeightKg: target,
      targetReps: repsMin,
      message: `Sube a ${fmtKg(target)} y vuelve a ${repsMin} repeticiones`,
    }), current);
  }

  // R7: estancamiento (mismo peso, sin sumar repeticiones totales).
  const total = session.reduce((sum, s) => sum + s.reps, 0);
  const last = state.lastSession;
  if (last && Math.abs((last.weightKg || 0) - current) <= EPS
      && Array.isArray(last.reps) && total <= last.reps.reduce((a, b) => a + b, 0)) {
    state.stallCount = (state.stallCount || 0) + 1;
    if (state.stallCount >= STALL_SESSIONS) {
      let deload = roundToIncrement(current * DELOAD_FACTOR, incrementKg);
      if (deload >= current) deload = roundToIncrement(Math.max(0, current - (incrementKg || 0.5)), incrementKg);
      state.previousWeightKg = 0;
      state.currentWeightKg = deload;
      state.stallCount = 0;
      return finish(suggestion({
        action: 'deload',
        weightKg: deload,
        baseWeightKg: deload,
        targetReps: repsMin,
        message: `Estancado: baja a ${fmtKg(deload)} y vuelve a subir. Revisa sueño y comida`,
      }), current);
    }
    return finish(holdSuggestion(prescription, current, session), current);
  }

  // R4: mantener.
  state.stallCount = 0;
  return finish(holdSuggestion(prescription, current, session), current);
}

module.exports = {
  computeNext,
  parsePrescription,
  roundToIncrement,
  defaultState,
  tolerance,
  BIG_JUMP_RATIO,
  STALL_SESSIONS,
  DELOAD_FACTOR,
  TIME_STEP_S,
};
