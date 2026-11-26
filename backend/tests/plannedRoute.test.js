const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizePlannedRoute, normalizeLocationPoint, samplePoints } = require('../utils/plannedRoute');

test('ruta planificada: calcula distancia y desnivel, descarta puntos inválidos', () => {
  const { route, error } = normalizePlannedRoute({
    name: '  Arena 35K  ',
    points: [[-12, -77, 10], [-12.009, -77, 30], ['x', 1], [200, 0], [-12.018, -77, 15]],
  });
  assert.equal(error, undefined);
  assert.equal(route.name, 'Arena 35K');
  assert.equal(route.points.length, 3);
  assert.ok(Math.abs(route.totalDistance - 2002) < 10, `dist ${route.totalDistance}`);
  assert.equal(route.elevationGain, 20);
});

test('ruta planificada: rechaza vacía o enorme', () => {
  assert.ok(normalizePlannedRoute({ points: [[1, 1]] }).error);
  assert.ok(normalizePlannedRoute({ points: Array(3001).fill([1, 1]) }).error);
  assert.ok(normalizePlannedRoute(null).error);
});

test('punto GPS: valida coordenadas y normaliza números', () => {
  assert.equal(normalizeLocationPoint({ latitude: 'a', longitude: 1 }), null);
  assert.equal(normalizeLocationPoint({ latitude: 95, longitude: 1 }), null);
  const p = normalizeLocationPoint({ latitude: -12, longitude: -77, distance: -3, timestamp: 1000, speed: 'x' });
  assert.equal(p.distance, 0);
  assert.equal(p.speed, 0);
  assert.equal(p.timestamp, 1000);
});

test('samplePoints conserva extremos y respeta el máximo', () => {
  const list = Array.from({ length: 10000 }, (_, i) => i);
  const s = samplePoints(list, 4000);
  assert.equal(s.length, 4000);
  assert.equal(s[0], 0);
  assert.equal(s[s.length - 1], 9999);
  assert.deepEqual(samplePoints([1, 2], 10), [1, 2]);
});
