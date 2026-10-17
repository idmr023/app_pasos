const TrackingLocation = require('../models/TrackingLocation');

function haversine(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Calcula y persiste las estadísticas finales de una sesión de tracking
 * a partir de los puntos GPS guardados (TrackingLocation).
 *
 * Devuelve las stats actualizadas para poder retransmitirlas por socket.
 */
async function finalizeSession(session) {
  if (!session) return null;

  const points = await TrackingLocation.find({ roomCode: session.code })
    .sort({ timestamp: 1 })
    .lean();

  if (points.length > 0) {
    const last = points[points.length - 1];

    // Distancia total: preferimos el acumulado que ya envía el corredor.
    // Fallback: haversine sobre los puntos (sesiones antiguas sin distance).
    let totalDistance = typeof last.distance === 'number' && last.distance > 0
      ? last.distance
      : 0;
    if (totalDistance === 0 && points.length >= 2) {
      let meters = 0;
      for (let i = 1; i < points.length; i++) {
        meters += haversine(
          points[i - 1].latitude, points[i - 1].longitude,
          points[i].latitude, points[i].longitude
        );
      }
      totalDistance = meters / 1000;
    }

    let maxSpeed = 0;
    for (const p of points) {
      if (typeof p.speed === 'number' && p.speed > maxSpeed) {
        maxSpeed = p.speed; // m/s
      }
    }
    const maxSpeedKmh = maxSpeed * 3.6;

    const startMs = new Date(points[0].timestamp || session.startedAt).getTime();
    const endMs = new Date(last.timestamp || session.endedAt || Date.now()).getTime();
    const elapsedSec = Math.max(0, (endMs - startMs) / 1000);

    const avgSpeedKmh = totalDistance > 0 && elapsedSec > 0
      ? totalDistance / (elapsedSec / 3600)
      : 0;
    const avgPace = totalDistance > 0
      ? (elapsedSec / 60) / totalDistance
      : 0;

    session.totalDistance = Math.round(totalDistance * 1000) / 1000; // km
    session.maxSpeed = Math.round(maxSpeedKmh * 10) / 10;
    session.avgSpeed = Math.round(avgSpeedKmh * 10) / 10;
    session.avgPace = Math.round(avgPace * 10) / 10; // min/km
    session.pointCount = points.length;
  }

  if (!session.endedAt) {
    session.endedAt = new Date();
  }
  session.status = 'completed';
  await session.save();

  return session;
}

module.exports = { finalizeSession, haversine };
