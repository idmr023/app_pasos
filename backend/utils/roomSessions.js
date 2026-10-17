// Caché en memoria de roomCode -> sessionId para evitar un findOne en cada
// locationUpdate. Vive en un módulo aparte para que la compartan server.js
// (sockets) y routes/tracking.js (REST /close). Es best-effort: si el proceso
// se reinicia solo se reconstruye consultando MongoDB.
const roomSessionIds = {};

async function getSessionIdForRoom(roomCode, TrackingSession) {
  if (!roomCode) return null;
  if (roomSessionIds[roomCode]) return roomSessionIds[roomCode];
  const session = await TrackingSession.findOne({ code: roomCode }).select('_id');
  if (session) {
    roomSessionIds[roomCode] = session._id;
    return session._id;
  }
  return null;
}

function setSessionIdForRoom(roomCode, sessionId) {
  if (roomCode && sessionId) roomSessionIds[roomCode] = sessionId;
}

function clearRoomSession(roomCode) {
  if (roomCode) delete roomSessionIds[roomCode];
}

module.exports = {
  getSessionIdForRoom,
  setSessionIdForRoom,
  clearRoomSession,
};
