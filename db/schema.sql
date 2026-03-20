-- ============================================================
-- Preseleccionado Damas +55 — Hockey sobre Césped
-- Schema PostgreSQL
-- ============================================================

CREATE DATABASE hockey_eval;
\c hockey_eval;

-- Extensión para UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------
-- Jugadoras
-- ------------------------------------------------------------
CREATE TABLE jugadoras (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      TEXT NOT NULL,
    posicion    TEXT NOT NULL,
    trayectoria TEXT NOT NULL,
    club_id     TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Sesiones de evaluación (una por jugadora por convocatoria)
-- ------------------------------------------------------------
CREATE TABLE sesiones (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jugadora_id  UUID REFERENCES jugadoras(id) ON DELETE CASCADE,
    completada   BOOLEAN DEFAULT FALSE,
    ip_origen    TEXT,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    finished_at  TIMESTAMPTZ
);

-- ------------------------------------------------------------
-- Módulo: Razonamiento lógico
-- Guarda respuesta elegida + si fue correcta
-- ------------------------------------------------------------
CREATE TABLE resultado_logica (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id   UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    pregunta    SMALLINT NOT NULL,       -- 1, 2, 3
    respuesta   TEXT NOT NULL,
    correcta    BOOLEAN NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo: Personalidad deportiva (Likert 1-5)
-- ------------------------------------------------------------
CREATE TABLE resultado_personalidad (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id   UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    item        SMALLINT NOT NULL,       -- 1..5
    descripcion TEXT NOT NULL,
    valor       SMALLINT NOT NULL CHECK (valor BETWEEN 1 AND 5),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo: Atención y concentración
-- ------------------------------------------------------------
CREATE TABLE resultado_atencion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id       UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    aciertos        SMALLINT NOT NULL,
    total_targets   SMALLINT NOT NULL,
    falsos_positivos SMALLINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo: Memoria y percepción
-- ------------------------------------------------------------
CREATE TABLE resultado_memoria (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id   UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    correcta    BOOLEAN NOT NULL,
    intentos    SMALLINT DEFAULT 1,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo: Tiempo de reacción
-- ------------------------------------------------------------
CREATE TABLE resultado_reaccion (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id    UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    intento      SMALLINT NOT NULL,     -- 1, 2, 3
    tiempo_ms    INTEGER NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo grupal: Cohesión de equipo
-- ------------------------------------------------------------
CREATE TABLE resultado_cohesion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id       UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    nivel_union     TEXT NOT NULL,
    apoyo_companieras TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo grupal: Roles y liderazgo
-- ------------------------------------------------------------
CREATE TABLE resultado_liderazgo (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id       UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    claridad_rol    TEXT NOT NULL,
    referente       TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo grupal: Comunicación interna (Likert 1-5)
-- ------------------------------------------------------------
CREATE TABLE resultado_comunicacion (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id   UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    item        SMALLINT NOT NULL,
    descripcion TEXT NOT NULL,
    valor       SMALLINT NOT NULL CHECK (valor BETWEEN 1 AND 5),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo grupal: Manejo del conflicto
-- ------------------------------------------------------------
CREATE TABLE resultado_conflicto (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id   UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    mecanismo   TEXT NOT NULL,
    relato      TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Módulo grupal: Motivación y compromiso
-- ------------------------------------------------------------
CREATE TABLE resultado_motivacion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_id       UUID REFERENCES sesiones(id) ON DELETE CASCADE,
    motivacion      TEXT NOT NULL,
    valores_grupo   TEXT,
    mejora_sugerida TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Vista: Resumen por sesión (útil para el panel admin)
-- ------------------------------------------------------------
CREATE VIEW v_resumen_sesiones AS
SELECT
    s.id                            AS sesion_id,
    j.nombre,
    j.posicion,
    j.trayectoria,
    s.created_at,
    s.finished_at,
    s.completada,
    -- Lógica
    (SELECT COUNT(*) FROM resultado_logica l WHERE l.sesion_id = s.id AND l.correcta = TRUE)  AS logica_correctas,
    -- Atención
    a.aciertos                      AS atencion_aciertos,
    a.total_targets                 AS atencion_total,
    a.falsos_positivos,
    -- Memoria
    m.correcta                      AS memoria_ok,
    -- Reacción promedio
    (SELECT ROUND(AVG(tiempo_ms)) FROM resultado_reaccion r WHERE r.sesion_id = s.id) AS reaccion_ms_avg,
    -- Personalidad promedio
    (SELECT ROUND(AVG(valor)::numeric, 2) FROM resultado_personalidad p WHERE p.sesion_id = s.id) AS personalidad_avg,
    -- Comunicación promedio
    (SELECT ROUND(AVG(valor)::numeric, 2) FROM resultado_comunicacion c WHERE c.sesion_id = s.id) AS comunicacion_avg,
    -- Cohesión
    co.nivel_union,
    co.apoyo_companieras,
    -- Motivación
    mo.motivacion
FROM sesiones s
JOIN jugadoras j ON j.id = s.jugadora_id
LEFT JOIN resultado_atencion a ON a.sesion_id = s.id
LEFT JOIN resultado_memoria m ON m.sesion_id = s.id
LEFT JOIN resultado_cohesion co ON co.sesion_id = s.id
LEFT JOIN resultado_motivacion mo ON mo.sesion_id = s.id
ORDER BY s.created_at DESC;

-- ------------------------------------------------------------
-- Índices
-- ------------------------------------------------------------
CREATE INDEX idx_sesiones_jugadora ON sesiones(jugadora_id);
CREATE INDEX idx_logica_sesion ON resultado_logica(sesion_id);
CREATE INDEX idx_personalidad_sesion ON resultado_personalidad(sesion_id);
CREATE INDEX idx_comunicacion_sesion ON resultado_comunicacion(sesion_id);
CREATE INDEX idx_reaccion_sesion ON resultado_reaccion(sesion_id);

-- ------------------------------------------------------------
-- Usuario de aplicación (ejecutar como superuser)
-- ------------------------------------------------------------
-- CREATE USER hockey_app WITH PASSWORD 'CAMBIAR_PASSWORD_SEGURA';
-- GRANT CONNECT ON DATABASE hockey_eval TO hockey_app;
-- GRANT USAGE ON SCHEMA public TO hockey_app;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO hockey_app;
-- GRANT SELECT ON v_resumen_sesiones TO hockey_app;
