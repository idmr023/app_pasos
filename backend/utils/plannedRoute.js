const { haversine } = require('./finalizeTracking');

const MAX_ROUTE_POINTS = 3000;

/**
 * Valida y normaliza la ruta planificada que sube el corredor.
 * `points`: [[lat, lng, ele?], ...]. Devuelve { route } o { error }.
 */
function normalizePlannedRoute(body) {
  const raw = body && Array.isArray(body.points) ? body.points : null;
  if (!raw || raw.length < 2) return { error: 'La ruta necesita al menos 2 puntos' };
  if (raw.length > MAX_ROUTE_POINTS) return { error: `Máximo ${MAX_ROUTE_POINTS} puntos (simplifica la ruta)` };

  const points = [];
  for (const p of raw) {
    if (!Array.isArray(p) || p.length < 2) continue;
    const lat = Number(p[0]);
    const lng = Number(p[1]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) continue;
    const ele = p.length > 2 && Number.isFinite(Number(p[2])) ? Math.round(Number(p[2]) * 10) / 10 : null;
    const lat6 = Math.round(lat * 1e6) / 1e6;
    const lng6 = Math.round(lng * 1e6) / 1e6;
    points.push(ele === null ? [lat6, lng6] : [lat6, lng6, ele]);
  }
  if (points.length < 2) return { error: 'La ruta no tiene coordenadas válidas' };

  let totalDistance = 0;
  let elevationGain = 0;
  let refEle = null;
  for (let i = 0; i < points.length; i++) {
    if (i > 0) totalDistance += haversine(points[i - 1][0], points[i - 1][1], points[i][0], points[i][1]);
    const ele = points[i][2];
    if (typeof ele === 'number') {
      if (refEle === null) refEle = ele;
      else if (Math.abs(ele - refEle) >= 3) {
        if (ele > refEle) elevationGain += ele - refEle;
        refEle = ele;
      }
    }
  }

  const name = typeof body.name === 'string' && body.name.trim() ? body.name.trim().slice(0, 80) : 'Ruta';
  return {
    route: {
      name,
      points,
      totalDistance: Math.round(totalDistance),
      elevationGain: Math.round(elevationGain),
    },
  };
}

/** Normaliza un punto GPS del corredor; null si es inválido. */
function normalizeLocationPoint(data) {
  if (!data || typeof data !== 'object') return null;
  const lat = Number(data.latitude);
  const lng = Number(data.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);
  const ts = Number(data.timestamp);
  const timestamp = Number.isFinite(ts) && ts > 0 ? ts : Date.now();
  return {
    latitude: lat,
    longitude: lng,
    speed: num(data.speed),
    pace: num(data.pace),
    heading: num(data.heading),
    accuracy: num(data.accuracy),
    altitude: num(data.altitude),
    distance: Math.max(0, num(data.distance)),
    timestamp,
  };
}

/** Reduce una lista ordenada a ≤ max elementos, conservando primero y último. */
function samplePoints(list, max) {
  if (list.length <= max) return list;
  const out = [];
  const step = (list.length - 1) / (max - 1);
  for (let i = 0; i < max; i++) out.push(list[Math.round(i * step)]);
  return out;
}

module.exports = { normalizePlannedRoute, normalizeLocationPoint, samplePoints, MAX_ROUTE_POINTS };
