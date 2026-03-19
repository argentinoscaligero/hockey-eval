const router = require('express').Router();
const { pool } = require('../db');

/**
 * POST /api/eval/submit
 * Guarda la evaluación completa de una jugadora en una transacción.
 * Body: { jugadora, psicotecnico, grupal }
 */
router.post('/submit', async (req, res) => {
  const { jugadora, psicotecnico, grupal } = req.body;

  // Validación mínima
  if (!jugadora?.nombre || !jugadora?.posicion || !jugadora?.trayectoria) {
    return res.status(400).json({ error: 'Datos de jugadora incompletos.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Insertar jugadora
    const jRes = await client.query(
      `INSERT INTO jugadoras (nombre, posicion, trayectoria)
       VALUES ($1, $2, $3) RETURNING id`,
      [jugadora.nombre.trim(), jugadora.posicion, jugadora.trayectoria]
    );
    const jugadoraId = jRes.rows[0].id;

    // 2. Crear sesión
    const sRes = await client.query(
      `INSERT INTO sesiones (jugadora_id, ip_origen, completada, finished_at)
       VALUES ($1, $2, TRUE, NOW()) RETURNING id`,
      [jugadoraId, req.ip]
    );
    const sesionId = sRes.rows[0].id;

    // 3. Razonamiento lógico
    if (psicotecnico?.logica?.length) {
      for (const item of psicotecnico.logica) {
        await client.query(
          `INSERT INTO resultado_logica (sesion_id, pregunta, respuesta, correcta)
           VALUES ($1, $2, $3, $4)`,
          [sesionId, item.pregunta, item.respuesta, item.correcta]
        );
      }
    }

    // 4. Personalidad
    if (psicotecnico?.personalidad?.length) {
      for (const item of psicotecnico.personalidad) {
        await client.query(
          `INSERT INTO resultado_personalidad (sesion_id, item, descripcion, valor)
           VALUES ($1, $2, $3, $4)`,
          [sesionId, item.item, item.descripcion, item.valor]
        );
      }
    }

    // 5. Atención
    if (psicotecnico?.atencion) {
      const a = psicotecnico.atencion;
      await client.query(
        `INSERT INTO resultado_atencion (sesion_id, aciertos, total_targets, falsos_positivos)
         VALUES ($1, $2, $3, $4)`,
        [sesionId, a.aciertos, a.totalTargets, a.falsosPositivos]
      );
    }

    // 6. Memoria
    if (psicotecnico?.memoria != null) {
      await client.query(
        `INSERT INTO resultado_memoria (sesion_id, correcta, intentos)
         VALUES ($1, $2, $3)`,
        [sesionId, psicotecnico.memoria.correcta, psicotecnico.memoria.intentos || 1]
      );
    }

    // 7. Reacción
    if (psicotecnico?.reaccion?.length) {
      for (let i = 0; i < psicotecnico.reaccion.length; i++) {
        await client.query(
          `INSERT INTO resultado_reaccion (sesion_id, intento, tiempo_ms)
           VALUES ($1, $2, $3)`,
          [sesionId, i + 1, psicotecnico.reaccion[i]]
        );
      }
    }

    // 8. Cohesión
    if (grupal?.cohesion) {
      await client.query(
        `INSERT INTO resultado_cohesion (sesion_id, nivel_union, apoyo_companieras)
         VALUES ($1, $2, $3)`,
        [sesionId, grupal.cohesion.nivelUnion, grupal.cohesion.apoyo]
      );
    }

    // 9. Liderazgo
    if (grupal?.liderazgo) {
      await client.query(
        `INSERT INTO resultado_liderazgo (sesion_id, claridad_rol, referente)
         VALUES ($1, $2, $3)`,
        [sesionId, grupal.liderazgo.claridadRol, grupal.liderazgo.referente]
      );
    }

    // 10. Comunicación
    if (grupal?.comunicacion?.length) {
      for (const item of grupal.comunicacion) {
        await client.query(
          `INSERT INTO resultado_comunicacion (sesion_id, item, descripcion, valor)
           VALUES ($1, $2, $3, $4)`,
          [sesionId, item.item, item.descripcion, item.valor]
        );
      }
    }

    // 11. Conflicto
    if (grupal?.conflicto) {
      await client.query(
        `INSERT INTO resultado_conflicto (sesion_id, mecanismo, relato)
         VALUES ($1, $2, $3)`,
        [sesionId, grupal.conflicto.mecanismo, grupal.conflicto.relato || null]
      );
    }

    // 12. Motivación
    if (grupal?.motivacion) {
      await client.query(
        `INSERT INTO resultado_motivacion (sesion_id, motivacion, valores_grupo, mejora_sugerida)
         VALUES ($1, $2, $3, $4)`,
        [sesionId,
         grupal.motivacion.motivacion,
         grupal.motivacion.valoresGrupo || null,
         grupal.motivacion.mejoraSugerida || null]
      );
    }

    await client.query('COMMIT');
    res.json({ ok: true, sesionId });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[eval/submit]', err.message);
    res.status(500).json({ error: 'Error al guardar la evaluación.' });
  } finally {
    client.release();
  }
});

module.exports = router;
