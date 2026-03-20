const router       = require('express').Router();
const { pool }     = require('../db');
const requireAdmin = require('../middleware/requireAdmin');

// Todas las rutas admin requieren JWT válido
router.use(requireAdmin);

// ─────────────────────────────────────────────────────────────
// GET /api/admin/resumen
// Lista de todas las sesiones completas (tabla principal admin)
// ─────────────────────────────────────────────────────────────
router.get('/resumen', async (req, res) => {
  try {
    const { club } = req.query;
    const clubFilter = club ? `WHERE j.club_id = $1` : '';
    const params = club ? [club] : [];
    const result = await pool.query(
      `SELECT v.*, j.club_id
       FROM v_resumen_sesiones v
       JOIN sesiones s ON s.id = v.sesion_id
       JOIN jugadoras j ON j.id = s.jugadora_id
       ${clubFilter}
       ORDER BY v.created_at DESC`,
      params
    );
    res.json(result.rows);
  } catch (err) {
    console.error('[admin/resumen]', err.message);
    res.status(500).json({ error: 'Error al obtener resumen.' });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/jugadora/:sesionId
// Detalle completo de una sesión (para modal / PDF)
// ─────────────────────────────────────────────────────────────
router.get('/jugadora/:sesionId', async (req, res) => {
  const { sesionId } = req.params;
  try {
    const [sesion, logica, pers, atencion, memoria, reaccion,
           cohesion, liderazgo, comms, conflicto, motivacion] = await Promise.all([
      pool.query(`SELECT s.*, j.nombre, j.posicion, j.trayectoria
                  FROM sesiones s JOIN jugadoras j ON j.id = s.jugadora_id
                  WHERE s.id = $1`, [sesionId]),
      pool.query(`SELECT * FROM resultado_logica WHERE sesion_id=$1 ORDER BY pregunta`, [sesionId]),
      pool.query(`SELECT * FROM resultado_personalidad WHERE sesion_id=$1 ORDER BY item`, [sesionId]),
      pool.query(`SELECT * FROM resultado_atencion WHERE sesion_id=$1`, [sesionId]),
      pool.query(`SELECT * FROM resultado_memoria WHERE sesion_id=$1`, [sesionId]),
      pool.query(`SELECT * FROM resultado_reaccion WHERE sesion_id=$1 ORDER BY intento`, [sesionId]),
      pool.query(`SELECT * FROM resultado_cohesion WHERE sesion_id=$1`, [sesionId]),
      pool.query(`SELECT * FROM resultado_liderazgo WHERE sesion_id=$1`, [sesionId]),
      pool.query(`SELECT * FROM resultado_comunicacion WHERE sesion_id=$1 ORDER BY item`, [sesionId]),
      pool.query(`SELECT * FROM resultado_conflicto WHERE sesion_id=$1`, [sesionId]),
      pool.query(`SELECT * FROM resultado_motivacion WHERE sesion_id=$1`, [sesionId]),
    ]);
    if (!sesion.rows.length) return res.status(404).json({ error: 'Sesión no encontrada.' });
    res.json({
      sesion:     sesion.rows[0],
      logica:     logica.rows,
      personalidad: pers.rows,
      atencion:   atencion.rows[0] || null,
      memoria:    memoria.rows[0] || null,
      reaccion:   reaccion.rows,
      cohesion:   cohesion.rows[0] || null,
      liderazgo:  liderazgo.rows[0] || null,
      comunicacion: comms.rows,
      conflicto:  conflicto.rows[0] || null,
      motivacion: motivacion.rows[0] || null,
    });
  } catch (err) {
    console.error('[admin/jugadora]', err.message);
    res.status(500).json({ error: 'Error al obtener detalle.' });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/ranking
// Ranking por dimensión + alertas de perfiles a revisar
// ─────────────────────────────────────────────────────────────
router.get('/ranking', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        j.nombre,
        j.posicion,
        j.club_id,
        s.id AS sesion_id,
        -- Lógica (0-3)
        (SELECT COUNT(*) FROM resultado_logica l WHERE l.sesion_id=s.id AND l.correcta) AS logica_score,
        -- Personalidad avg (1-5)
        ROUND((SELECT AVG(valor) FROM resultado_personalidad p WHERE p.sesion_id=s.id)::numeric,2) AS personalidad_avg,
        -- Atención % aciertos
        CASE WHEN a.total_targets > 0
             THEN ROUND((a.aciertos::numeric/a.total_targets)*100, 1)
             ELSE NULL END AS atencion_pct,
        -- Memoria
        m.correcta AS memoria_ok,
        -- Reacción (ms, menor = mejor)
        ROUND((SELECT AVG(tiempo_ms) FROM resultado_reaccion r WHERE r.sesion_id=s.id)::numeric) AS reaccion_ms,
        -- Comunicación avg (1-5)
        ROUND((SELECT AVG(valor) FROM resultado_comunicacion c WHERE c.sesion_id=s.id)::numeric,2) AS comunicacion_avg,
        -- Alertas (flags para el cuerpo técnico)
        ARRAY_REMOVE(ARRAY[
          CASE WHEN (SELECT COUNT(*) FROM resultado_logica l WHERE l.sesion_id=s.id AND l.correcta) < 2
               THEN 'Lógica baja' END,
          CASE WHEN ROUND((SELECT AVG(valor) FROM resultado_personalidad p WHERE p.sesion_id=s.id)::numeric,2) < 3
               THEN 'Personalidad a trabajar' END,
          CASE WHEN a.total_targets > 0 AND (a.aciertos::numeric/a.total_targets) < 0.6
               THEN 'Atención reducida' END,
          CASE WHEN m.correcta = FALSE
               THEN 'Memoria a reforzar' END,
          CASE WHEN (SELECT AVG(tiempo_ms) FROM resultado_reaccion r WHERE r.sesion_id=s.id) > 400
               THEN 'Reacción lenta (>400ms)' END,
          CASE WHEN ROUND((SELECT AVG(valor) FROM resultado_comunicacion c WHERE c.sesion_id=s.id)::numeric,2) < 3
               THEN 'Comunicación grupal baja' END
        ], NULL) AS alertas
      FROM sesiones s
      JOIN jugadoras j ON j.id = s.jugadora_id
      LEFT JOIN resultado_atencion a ON a.sesion_id=s.id
      LEFT JOIN resultado_memoria m ON m.sesion_id=s.id
      WHERE s.completada = TRUE
      ORDER BY logica_score DESC, reaccion_ms ASC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('[admin/ranking]', err.message);
    res.status(500).json({ error: 'Error al calcular ranking.' });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/comparativa
// Promedios grupales para gráficos comparativos
// ─────────────────────────────────────────────────────────────
router.get('/comparativa', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        j.nombre,
        j.posicion,
        j.club_id,
        s.id AS sesion_id,
        -- Score normalizado 0-10 por dimensión
        ROUND(((SELECT COUNT(*) FROM resultado_logica l WHERE l.sesion_id=s.id AND l.correcta)::numeric / 3)*10, 1) AS logica_norm,
        ROUND(((SELECT COALESCE(AVG(valor),0) FROM resultado_personalidad p WHERE p.sesion_id=s.id)-1)/4*10, 1) AS personalidad_norm,
        CASE WHEN a.total_targets>0
             THEN ROUND((a.aciertos::numeric/a.total_targets)*10,1)
             ELSE 0 END AS atencion_norm,
        CASE WHEN m.correcta THEN 10 ELSE 4 END AS memoria_norm,
        -- Reacción: invertida (600ms=0, 150ms=10)
        GREATEST(0, LEAST(10,
          ROUND((1 - ((SELECT COALESCE(AVG(tiempo_ms),600) FROM resultado_reaccion r WHERE r.sesion_id=s.id)-150)/450)*10, 1)
        )) AS reaccion_norm,
        ROUND(((SELECT COALESCE(AVG(valor),0) FROM resultado_comunicacion c WHERE c.sesion_id=s.id)-1)/4*10, 1) AS comunicacion_norm
      FROM sesiones s
      JOIN jugadoras j ON j.id=s.jugadora_id
      LEFT JOIN resultado_atencion a ON a.sesion_id=s.id
      LEFT JOIN resultado_memoria m ON m.sesion_id=s.id
      WHERE s.completada=TRUE
      ORDER BY j.nombre
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('[admin/comparativa]', err.message);
    res.status(500).json({ error: 'Error al obtener comparativa.' });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/export/csv
// Export completo en CSV
// ─────────────────────────────────────────────────────────────
router.get('/export/csv', async (req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM v_resumen_sesiones`);
    const rows = result.rows;
    if (!rows.length) return res.status(404).json({ error: 'Sin datos.' });
    const headers = Object.keys(rows[0]);
    const csv = [
      headers.join(','),
      ...rows.map(r => headers.map(h => {
        const v = r[h];
        if (v === null || v === undefined) return '';
        const s = String(v).replace(/"/g, '""');
        return `"${s}"`;
      }).join(','))
    ].join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition',
      `attachment; filename="evaluacion_damas55_${new Date().toISOString().slice(0,10)}.csv"`);
    res.send('\uFEFF' + csv);  // BOM para Excel
  } catch (err) {
    console.error('[admin/export/csv]', err.message);
    res.status(500).json({ error: 'Error al exportar.' });
  }
});

module.exports = router;
