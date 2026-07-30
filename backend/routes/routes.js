const express = require('express');
const crypto = require('crypto');
const auth = require('../middleware/auth');
const Route = require('../models/Route');
const StravaState = require('../models/StravaState');

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

const MAPBOX_STYLES = {
  cyberpunk: 'dark-v11',
  titan: 'dark-v11',
  encuadre: 'light-v11',
  caligrafia: 'light-v11',
  semanal: 'dark-v11',
  split: 'streets-v12',
  dashboard: 'dark-v11',
  pulse: 'satellite-streets-v12',
  minimal: 'light-v11',
  cinematic: 'satellite-streets-v12'
};

const MAPBOX_LINE_COLORS = {
  cyberpunk: '00D4FF',
  titan: 'FFFFFF',
  encuadre: '3B82F6',
  caligrafia: '1A1A2E',
  semanal: '6366F1',
  split: 'F97316',
  dashboard: '06B6D4',
  pulse: 'EF4444',
  minimal: 'A1A1AA',
  cinematic: 'EAB308'
};

router.get('/:id/map-card', auth, async (req, res) => {
  try {
    const route = await Route.findOne({ _id: req.params.id, user: req.user._id });
    if (!route) return res.status(404).json({ error: 'Ruta no encontrada' });

    const template = req.query.template || 'cyberpunk';
    const width = Math.min(parseInt(req.query.width) || 1080, 4096);
    const height = Math.min(parseInt(req.query.height) || 1350, 4096);
    const mapboxToken = process.env.MAPBOX_ACCESS_TOKEN;

    if (!mapboxToken) {
      return res.status(400).json({ error: 'Mapbox token no configurado en el servidor' });
    }

    if (route.coordinates.length < 2) {
      return res.status(400).json({ error: 'La ruta necesita al menos 2 coordenadas' });
    }

    const style = MAPBOX_STYLES[template] || 'dark-v11';
    const lineColor = MAPBOX_LINE_COLORS[template] || '00D4FF';

    const coords = route.coordinates.map(c => [c.lng, c.lat]);

    const geojson = {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'LineString',
        coordinates: coords
      }
    };

    const encoded = encodeURIComponent(JSON.stringify(geojson));

    const url = `https://api.mapbox.com/styles/v1/mapbox/${style}/static/geojson(${encoded})/auto/${width}x${height}@2x?padding=40&access_token=${mapboxToken}`;

    const stats = {
      title: route.title,
      distance: route.distance,
      duration: route.duration,
      elevationGain: route.elevationGain,
      averagePace: route.averagePace,
      averageHeartRate: route.averageHeartRate,
      maxHeartRate: route.maxHeartRate,
      calories: route.calories,
      activityType: route.activityType,
      startDate: route.startDate,
      source: route.source
    };

    res.json({ url, stats, template, width, height });
  } catch (error) {
    res.status(500).json({ error: 'Error al generar card', message: error.message });
  }
});

router.post('/strava/init', auth, async (req, res) => {
  const clientId = process.env.STRAVA_CLIENT_ID;
  const redirectUri = process.env.STRAVA_REDIRECT_URI || 'http://localhost:3000/api/routes/strava/callback';
  if (!clientId) {
    return res.status(400).json({ error: 'Strava Client ID no configurado en el servidor' });
  }

  const state = crypto.randomBytes(24).toString('hex');

  await StravaState.create({
    state,
    user: req.user._id,
    connected: false
  });

  const url = `https://www.strava.com/oauth/authorize?client_id=${clientId}&response_type=code&redirect_uri=${encodeURIComponent(redirectUri)}&state=${state}&approval_prompt=force&scope=read,activity:read_all`;

  res.json({ url, state });
});

router.get('/strava/callback', async (req, res) => {
  const { code, state, error } = req.query;
  if (error || !code || !state) {
    return res.send(`
      <html><body style="background:#0F0F1E;color:white;font-family:sans-serif;text-align:center;padding-top:50px;">
        <h3>Error o acceso denegado en Strava</h3><p>Puedes cerrar esta ventana.</p>
      </body></html>
    `);
  }

  try {
    const axios = require('axios');
    const stravaState = await StravaState.findOne({ state });
    if (!stravaState) {
      return res.send(`
        <html><body style="background:#0F0F1E;color:white;font-family:sans-serif;text-align:center;padding-top:50px;">
          <h3>Enlace expirado o inválido</h3><p>Vuelve a intentar desde la aplicación.</p>
        </body></html>
      `);
    }

    const clientId = process.env.STRAVA_CLIENT_ID;
    const clientSecret = process.env.STRAVA_CLIENT_SECRET;
    const redirectUri = process.env.STRAVA_REDIRECT_URI || 'http://localhost:3000/api/routes/strava/callback';

    const tokenRes = await axios.post('https://www.strava.com/oauth/token', {
      client_id: clientId,
      client_secret: clientSecret,
      code,
      grant_type: 'authorization_code'
    });

    const data = tokenRes.data;
    if (!data.access_token || !data.refresh_token) {
      stravaState.connected = false;
      await stravaState.save();
      return res.send(`
        <html><body style="background:#0F0F1E;color:white;font-family:sans-serif;text-align:center;padding-top:50px;">
          <h3>Error al conectar</h3><p>Respuesta inválida de Strava. Vuelve a intentar.</p>
        </body></html>
      `);
    }

    const User = require('../models/User');
    const user = await User.findById(stravaState.user);
    if (user) {
      user.strava = {
        accessToken: data.access_token,
        refreshToken: data.refresh_token,
        expiresAt: data.expires_at,
        athleteId: data.athlete?.id || null
      };
      await user.save();
    }

    stravaState.connected = true;
    await stravaState.save();

    res.send(`
      <html>
        <head><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
        <body style="background:#0F0F1E;color:white;font-family:sans-serif;text-align:center;padding:40px 20px;">
          <h2 style="color:#FC4C02;">¡Conectado con éxito!</h2>
          <p>Ya puedes volver a la aplicación App Pasos.</p>
          <p style="font-size:13px;color:rgba(255,255,255,0.5);">Esta ventana se cerrará automáticamente...</p>
          <script>setTimeout(() => window.close(), 3000);</script>
        </body>
      </html>
    `);
  } catch (err) {
    res.send(`
      <html><body style="background:#0F0F1E;color:white;font-family:sans-serif;text-align:center;padding-top:50px;">
        <h3>Error al conectar con Strava</h3><p>${err.response?.data?.message || err.message}</p>
      </body></html>
    `);
  }
});

router.get('/strava/status/:state', auth, async (req, res) => {
  try {
    const stravaState = await StravaState.findOne({ state: req.params.state, user: req.user._id });
    if (!stravaState) {
      return res.json({ connected: false, expired: true });
    }
    res.json({ connected: stravaState.connected, expired: false });
  } catch (error) {
    res.status(500).json({ error: 'Error al verificar estado' });
  }
});

router.post('/strava/sync', auth, async (req, res) => {
  const axios = require('axios');
  try {
    const user = req.user;
    if (!user.strava || !user.strava.accessToken) {
      return res.status(400).json({ error: 'Strava no está conectado' });
    }

    let token = user.strava.accessToken;

    if (Date.now() / 1000 > user.strava.expiresAt) {
      const refreshRes = await axios.post('https://www.strava.com/oauth/token', {
        client_id: process.env.STRAVA_CLIENT_ID,
        client_secret: process.env.STRAVA_CLIENT_SECRET,
        grant_type: 'refresh_token',
        refresh_token: user.strava.refreshToken
      });
      token = refreshRes.data.access_token;
      user.strava.accessToken = token;
      user.strava.refreshToken = refreshRes.data.refresh_token;
      user.strava.expiresAt = refreshRes.data.expires_at;
      await user.save();
    }

    const activitiesRes = await axios.get('https://www.strava.com/api/v3/athlete/activities?per_page=10', {
      headers: { Authorization: `Bearer ${token}` }
    });

    let importedCount = 0;
    for (const act of activitiesRes.data) {
      const exists = await Route.findOne({ user: user._id, stravaActivityId: act.id });
      if (!exists && act.map && act.map.summary_polyline) {
        const polyline = require('@mapbox/polyline');
        const decoded = polyline.decode(act.map.summary_polyline);
        const coordinates = decoded.map(([lat, lng]) => ({
          lat,
          lng,
          elevation: 0,
          timestamp: act.start_date || '',
          heartRate: act.average_heartrate ? Math.round(act.average_heartrate) : 0
        }));

        if (coordinates.length >= 2) {
          const stats = computeStats(coordinates);
          let actType = 'run';
          if (act.type === 'Ride' || act.sport_type === 'Ride') actType = 'ride';
          else if (act.type === 'Walk' || act.sport_type === 'Walk') actType = 'walk';
          else if (act.type === 'Hike' || act.sport_type === 'Hike') actType = 'hike';

          const newRoute = new Route({
            user: user._id,
            title: act.name || 'Actividad Strava',
            source: 'strava',
            stravaActivityId: act.id,
            coordinates,
            activityType: actType,
            startDate: act.start_date ? new Date(act.start_date) : new Date(),
            calories: act.calories ? Math.round(act.calories) : 0,
            averageHeartRate: act.average_heartrate ? Math.round(act.average_heartrate) : 0,
            maxHeartRate: act.max_heartrate ? Math.round(act.max_heartrate) : 0,
            distance: Math.round(act.distance || stats.distance),
            duration: Math.round(act.moving_time || stats.duration),
            elevationGain: Math.round(act.total_elevation_gain || stats.elevationGain),
            averagePace: stats.averagePace
          });
          await newRoute.save();
          importedCount++;
        }
      }
    }

    res.json({ success: true, count: importedCount });
  } catch (error) {
    res.status(500).json({ error: 'Error al sincronizar con Strava', message: error.response?.data?.message || error.message });
  }
});

router.post('/strava/disconnect', auth, async (req, res) => {
  try {
    req.user.strava = {
      accessToken: '',
      refreshToken: '',
      expiresAt: 0,
      athleteId: null
    };
    await req.user.save();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al desconectar Strava' });
  }
});

module.exports = router;