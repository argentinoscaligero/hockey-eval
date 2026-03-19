const router  = require('express').Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { password } = req.body;
  if (!password) return res.status(400).json({ error: 'Contraseña requerida.' });

  const hash = process.env.ADMIN_PASSWORD_HASH;
  if (!hash) return res.status(500).json({ error: 'Configuración de admin incompleta.' });

  const ok = await bcrypt.compare(password, hash);
  if (!ok) return res.status(401).json({ error: 'Contraseña incorrecta.' });

  const token = jwt.sign(
    { role: 'admin' },
    process.env.JWT_SECRET,
    { expiresIn: '8h' }
  );
  res.json({ token, expiresIn: '8h' });
});

module.exports = router;
