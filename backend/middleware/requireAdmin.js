const jwt = require('jsonwebtoken');

module.exports = function requireAdmin(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requerido.' });
  }
  try {
    const payload = jwt.verify(auth.slice(7), process.env.JWT_SECRET);
    if (payload.role !== 'admin') throw new Error('Sin permisos');
    req.admin = payload;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Token inválido o expirado.' });
  }
};
