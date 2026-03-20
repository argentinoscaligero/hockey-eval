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
-- Preguntas configurables por club
-- seccion: 'logica' | 'personalidad' | 'comunicacion' |
--          'cohesion' | 'soporte' | 'rol' | 'lider' | 'conflicto' | 'motivacion'
-- club_id = '' → preguntas por defecto para todos los clubs
-- Si existe al menos 1 fila activa con club_id = 'X' para una sección,
-- esas sobreescriben las del defecto para ese club en esa sección.
-- Para logica: opciones = array de strings, correcta = índice (0-based)
-- Para personalidad/comunicacion: opciones = null (ítems Likert)
-- Para el resto: opciones = array de strings (radio), correcta = null
-- ------------------------------------------------------------
CREATE TABLE preguntas (
    id       SERIAL PRIMARY KEY,
    club_id  TEXT NOT NULL DEFAULT '',
    seccion  TEXT NOT NULL,
    orden    INT  NOT NULL DEFAULT 0,
    texto    TEXT NOT NULL,
    opciones JSONB,
    correcta INT,
    activa   BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_preguntas_club_seccion ON preguntas(club_id, seccion);

-- Preguntas por defecto (club_id = '')
INSERT INTO preguntas (club_id, seccion, orden, texto, opciones, correcta) VALUES
-- Lógica
('', 'logica', 1,
 'En un partido, tu equipo anota 3 goles en el primer tiempo y 2 en el segundo. El rival anota 1 en cada tiempo. ¿Cuántos goles de diferencia tiene tu equipo al final?',
 '["1 gol","3 goles","2 goles","5 goles"]'::jsonb, 1),
('', 'logica', 2,
 'Si A es más rápida que B, y B es más rápida que C, pero C es más resistente que A, ¿quién es la más completa para jugar 70 minutos?',
 '["A (más rápida)","B (intermedia)","C (más resistente)","Ninguna claramente"]'::jsonb, 3),
('', 'logica', 3,
 'En una secuencia táctica se realizan siempre: recepción → control → pase. Si una jugadora recibe y no controla, ¿qué paso se salteó?',
 '["La recepción","El control","El pase","Nada, es válido igual"]'::jsonb, 1),
-- Personalidad deportiva (Likert)
('', 'personalidad', 1, 'Mantengo la calma bajo presión en los últimos minutos', null, null),
('', 'personalidad', 2, 'Acepto bien las críticas del cuerpo técnico', null, null),
('', 'personalidad', 3, 'Me entrego aunque el resultado ya esté definido', null, null),
('', 'personalidad', 4, 'Prefiero el juego colectivo al lucimiento individual', null, null),
('', 'personalidad', 5, 'Me recupero emocionalmente rápido después de un error', null, null),
-- Comunicación (Likert)
('', 'comunicacion', 1, 'Comunicación durante el juego', null, null),
('', 'comunicacion', 2, 'Comunicación en entrenamientos', null, null),
('', 'comunicacion', 3, 'Comunicación fuera de la cancha', null, null),
('', 'comunicacion', 4, 'Comunicación con cuerpo técnico', null, null),
('', 'comunicacion', 5, 'Escucha activa entre compañeras', null, null),
-- Cohesión
('', 'cohesion', 1,
 '¿Cómo describirías el nivel de unión dentro del grupo?',
 '["Muy alta — somos una familia dentro y fuera","Alta — nos llevamos bien aunque no compartamos todo","Media — hay diferencias entre subgrupos","Baja — falta más vínculo entre todas"]'::jsonb, null),
-- Soporte
('', 'soporte', 1,
 '¿Con qué frecuencia sentís que tus compañeras te apoyan en momentos difíciles?',
 '["Siempre","Casi siempre","A veces","Rara vez"]'::jsonb, null),
-- Rol
('', 'rol', 1,
 '¿Sentís que tu rol dentro del equipo está claramente definido?',
 '["Sí, completamente claro","Bastante claro, con algunas dudas","No del todo, a veces es confuso","No, necesito más definición"]'::jsonb, null),
-- Liderazgo
('', 'lider', 1,
 '¿A quién acudís naturalmente cuando el equipo necesita dirección?',
 '["La capitana / vice-capitana designada","La más experimentada en ese momento","Me apoyo en mí misma","Buscamos decisión colectiva","Dependiendo de la situación, varía"]'::jsonb, null),
-- Conflicto
('', 'conflicto', 1,
 'Cuando surge una diferencia importante, ¿cómo suele resolverse?',
 '["Se habla en el momento, dentro del grupo","Se espera y se charla en privado después","Lo resuelve el cuerpo técnico","Queda sin resolver, genera tensión","Se evita para no dañar el clima"]'::jsonb, null),
-- Motivación
('', 'motivacion', 1,
 '¿Cuál es tu principal motivación para seguir en el Masters?',
 '["La competencia y el desafío deportivo","El vínculo con mis compañeras","La representación y el orgullo federativo","Mi superación personal a esta edad","El placer de jugar al hockey"]'::jsonb, null);

-- Permisos (ejecutar como superuser)
-- GRANT SELECT ON preguntas TO hockey_app;
-- GRANT USAGE, SELECT ON SEQUENCE preguntas_id_seq TO hockey_app;

-- ------------------------------------------------------------
-- Usuario de aplicación (ejecutar como superuser)
-- ------------------------------------------------------------
-- CREATE USER hockey_app WITH PASSWORD 'CAMBIAR_PASSWORD_SEGURA';
-- GRANT CONNECT ON DATABASE hockey_eval TO hockey_app;
-- GRANT USAGE ON SCHEMA public TO hockey_app;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO hockey_app;
-- GRANT SELECT ON v_resumen_sesiones TO hockey_app;
