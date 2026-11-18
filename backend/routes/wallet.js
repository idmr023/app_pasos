const express = require('express');
const auth = require('../middleware/auth');
const wallet = require('../services/walletService');

const router = express.Router();

function handle(res, error, fallback) {
  if (error instanceof wallet.WalletError) {
    return res.status(error.status).json({ error: error.message, ...error.extra });
  }
  console.error(fallback, error.message);
  return res.status(500).json({ error: fallback });
}

// GET /api/wallet → saldo + últimos movimientos + inventario + equipado
router.get('/', auth, async (req, res) => {
  try {
    res.json(await wallet.getWalletSummary(req.userId));
  } catch (error) {
    handle(res, error, 'Error al obtener el monedero');
  }
});

// GET /api/wallet/catalog → artículos de la tienda con owned/equipped
router.get('/catalog', auth, async (req, res) => {
  try {
    res.json(await wallet.getCatalog(req.userId));
  } catch (error) {
    handle(res, error, 'Error al obtener la tienda');
  }
});

// POST /api/wallet/purchase { itemId }
router.post('/purchase', auth, async (req, res) => {
  try {
    const { itemId } = req.body || {};
    if (!itemId || typeof itemId !== 'string') {
      return res.status(400).json({ error: 'itemId requerido' });
    }
    const result = await wallet.purchase(req.userId, itemId);
    res.status(201).json(result);
  } catch (error) {
    handle(res, error, 'Error al comprar');
  }
});

// GET /api/wallet/inventory
router.get('/inventory', auth, async (req, res) => {
  try {
    res.json(await wallet.getInventory(req.userId));
  } catch (error) {
    handle(res, error, 'Error al obtener el inventario');
  }
});

// POST /api/wallet/equip { slot: 'skin'|'trail', itemId | null }
router.post('/equip', auth, async (req, res) => {
  try {
    const { slot, itemId } = req.body || {};
    res.json(await wallet.equip(req.userId, slot, itemId ?? null));
  } catch (error) {
    handle(res, error, 'Error al equipar');
  }
});

module.exports = router;
