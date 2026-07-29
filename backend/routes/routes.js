const express = require('express');
const auth = require('../middleware/auth');
const Route = require('../models/Route');

const router = express.Router();

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

function computeStats(coordinates) {
  if (!coordinates || coordinates.length < 2) {
    return { distance: 0, duration: 0, elevationGain: 0, averagePace: 0 };
  }

  let distance = 0;
  let elevationGain = 0;
  let prev = coordinates[0];

  for (let i = 1; i < coordinates.length; i++) {
    const cur = coordinates[i];
    distance += haversine(prev.lat, prev.lng, cur.lat, cur.lng);
    if (cur.elevation > prev.elevation) {
      elevationGain += cur.elevation - prev.elevation;
    }
    prev = cur;
  }

  let duration = 0;
  if (coordinates[0].timestamp && coordinates[coordinates.length - 1].timestamp) {
    const start = new Date(coordinates[0].timestamp).getTime();
    const end = new Date(coordinates[coordinates.length - 1].timestamp).getTime();
    if (!isNaN(start) && !isNaN(end) && end > start) {
      duration = Math.round((end - start) / 1000);
    }
  }

  const averagePace = distance > 0 ? duration / (distance / 1000) : 0;

  return {
    distance: Math.round(distance),
    duration,
    elevationGain: Math.round(elevationGain),
    averagePace: Math.round(averagePace),
  };
}

router.get('/', auth, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const routes = await Route.find({ user: req.user._id })
      .sort({ createdAt: -1 })
      .limit(limit)
      .select('-coordinates')
      .lean();

    res.json({ routes });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener rutas' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const route = await Route.findOne({
      _id: req.params.id,
      user: req.user._id
    }).lean();

    if (!route) return res.status(404).json({ error: 'Ruta no encontrada' });

    res.json({ route });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener ruta' });
  }
});

router.post('/', auth, async (req, res) => {
  try {
    const { title, source, coordinates, activityType, startDate, calories, heartRate } = req.body;

    if (!coordinates || coordinates.length < 2) {
      return res.status(400).json({ error: 'Se requieren al menos 2 coordenadas' });
    }

    const cleanCoords = coordinates.map(c => ({
      lat: parseFloat(c.lat),
      lng: parseFloat(c.lng),
      elevation: parseFloat(c.elevation) || 0,
      timestamp: c.timestamp || '',
      heartRate: parseInt(c.heartRate) || 0,
    })).filter(c => !isNaN(c.lat) && !isNaN(c.lng));

    if (cleanCoords.length < 2) {
      return res.status(400).json({ error: 'Coordenadas inválidas' });
    }

    const stats = computeStats(cleanCoords);

    let avgHR = 0;
    let maxHR = 0;
    const hrPoints = cleanCoords.filter(c => c.heartRate > 0);
    if (hrPoints.length > 0) {
      avgHR = Math.round(hrPoints.reduce((s, c) => s + c.heartRate, 0) / hrPoints.length);
      maxHR = Math.max(...hrPoints.map(c => c.heartRate));
    }

    const route = new Route({
      user: req.user._id,
      title: (title || '').trim() || 'Ruta sin título',
      source: source || 'manual',
      coordinates: cleanCoords,
      activityType: activityType || 'run',
      startDate: startDate ? new Date(startDate) : (cleanCoords[0].timestamp ? new Date(cleanCoords[0].timestamp) : new Date()),
      calories: parseInt(calories) || 0,
      averageHeartRate: avgHR || parseInt(heartRate) || 0,
      maxHeartRate: maxHR,
      ...stats,
    });

    await route.save();

    const { coordinates: _, ...routeSummary } = route.toObject();
    res.status(201).json({ route: { ...routeSummary, coordinates: cleanCoords } });
  } catch (error) {
    res.status(500).json({ error: 'Error al crear ruta', message: error.message });
  }
});

router.put('/:id', auth, async (req, res) => {
  try {
    const { title, design, activityType } = req.body;
    const route = await Route.findOne({ _id: req.params.id, user: req.user._id });

    if (!route) return res.status(404).json({ error: 'Ruta no encontrada' });

    if (title !== undefined) route.title = title;
    if (activityType !== undefined) route.activityType = activityType;
    if (design !== undefined) route.design = design;

    await route.save();
    res.json({ route });
  } catch (error) {
    res.status(500).json({ error: 'Error al actualizar ruta' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const route = await Route.findOneAndDelete({
      _id: req.params.id,
      user: req.user._id
    });

    if (!route) return res.status(404).json({ error: 'Ruta no encontrada' });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar ruta' });
  }
});

module.exports = router;