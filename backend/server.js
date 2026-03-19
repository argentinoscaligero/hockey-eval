require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const rateLimit = require('express-rate-limit');

const { pool } = require('./db');
const authRouter    = require('./routes/auth');
const evalRouter    = require('./routes/evaluacion');
const adminRouter   = require('./routes/admin');

const app  = express();
const PORT = process.env.PORT || 3001;

// ── Seguridad básica ─────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '1mb' }));

// ── Rate limiting ────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutos
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Demasiadas solicitudes. Intentá en 15 minutos.' }
});
app.use('/api/', limiter);

// Límite más estricto para el login admin
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,   // 1 hora
  max: 10,
  message: { error: 'Demasiados intentos de login.' }
});
app.use('/api/auth/', authLimiter);

// ── Rutas ─────────────────────────────────────────────────────
app.use('/api/auth',  authRouter);
app.use('/api/eval',  evalRouter);
app.use('/api/admin', adminRouter);

// ── Health check ──────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected', ts: new Date() });
  } catch (err) {
    res.status(500).json({ status: 'error', db: 'disconnected' });
  }
});

// ── Error handler global ──────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ error: 'Error interno del servidor.' });
});

app.listen(PORT, () => {
  console.log(`✅ Hockey Eval API corriendo en puerto ${PORT}`);
});
