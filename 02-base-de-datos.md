# 02 — Base de datos (PostgreSQL)

## Esquema general

La base se llama `hockey_eval`. Cada evaluación genera una fila en `jugadoras` y una en `sesiones`, y luego una fila en cada tabla de resultados correspondiente a los módulos completados.

```
jugadoras
    └── sesiones (1 por evaluación)
            ├── resultado_logica          (3 filas — una por pregunta)
            ├── resultado_personalidad    (5 filas — una por ítem)
            ├── resultado_atencion        (1 fila)
            ├── resultado_memoria         (1 fila)
            ├── resultado_reaccion        (3 filas — una por intento)
            ├── resultado_cohesion        (1 fila)
            ├── resultado_liderazgo       (1 fila)
            ├── resultado_comunicacion    (5 filas — una por ítem)
            ├── resultado_conflicto       (1 fila)
            └── resultado_motivacion      (1 fila)
```

---

## Tablas

### `jugadoras`
Datos de identificación de cada jugadora.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | UUID (PK) | Generado automáticamente con `gen_random_uuid()` |
| `nombre` | TEXT | Nombre completo |
| `posicion` | TEXT | Arquera / Defensora / Mediocampista / Delantera / Polivalente |
| `trayectoria` | TEXT | Años en el equipo (opciones predefinidas) |
| `created_at` | TIMESTAMPTZ | Fecha de registro |

---

### `sesiones`
Una sesión por evaluación completada.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | UUID (PK) | ID de sesión |
| `jugadora_id` | UUID (FK) | Referencia a `jugadoras` |
| `completada` | BOOLEAN | `TRUE` cuando se envió el formulario |
| `ip_origen` | TEXT | IP del cliente (informativo) |
| `created_at` | TIMESTAMPTZ | Inicio de la sesión |
| `finished_at` | TIMESTAMPTZ | Momento de envío |

---

### `resultado_logica`
3 filas por sesión (una por pregunta).

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `pregunta` | SMALLINT | 1, 2 o 3 |
| `respuesta` | TEXT | Texto de la opción elegida |
| `correcta` | BOOLEAN | Si la respuesta fue correcta |

---

### `resultado_personalidad`
5 filas por sesión. Escala Likert 1–5.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `item` | SMALLINT | 1 a 5 |
| `descripcion` | TEXT | Texto del ítem |
| `valor` | SMALLINT | Valor elegido (1 a 5, CHECK constraint) |

---

### `resultado_atencion`
1 fila por sesión.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `aciertos` | SMALLINT | Cantidad de "7" marcados correctamente |
| `total_targets` | SMALLINT | Total de "7" en la grilla (siempre 10) |
| `falsos_positivos` | SMALLINT | Números marcados que no eran 7 |

---

### `resultado_memoria`
1 fila por sesión.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `correcta` | BOOLEAN | Si reprodujo la secuencia en orden exacto |
| `intentos` | SMALLINT | Cuántas veces intentó (puede reintentar) |

---

### `resultado_reaccion`
3 filas por sesión (una por intento).

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `intento` | SMALLINT | 1, 2 o 3 |
| `tiempo_ms` | INTEGER | Milisegundos que tardó en reaccionar |

---

### `resultado_cohesion`
1 fila por sesión.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `nivel_union` | TEXT | Respuesta elegida sobre cohesión grupal |
| `apoyo_companieras` | TEXT | Frecuencia de apoyo percibido |

---

### `resultado_liderazgo`
1 fila por sesión.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `claridad_rol` | TEXT | Qué tan claro está su rol |
| `referente` | TEXT | A quién acude en momentos de decisión |

---

### `resultado_comunicacion`
5 filas por sesión. Escala Likert 1–5.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `item` | SMALLINT | 1 a 5 |
| `descripcion` | TEXT | Aspecto de comunicación evaluado |
| `valor` | SMALLINT | Valor 1–5 |

---

### `resultado_conflicto`
1 fila por sesión.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `mecanismo` | TEXT | Cómo se resuelven los conflictos |
| `relato` | TEXT | Respuesta abierta (puede ser NULL) |

---

### `resultado_motivacion`
1 fila por sesión.

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `motivacion` | TEXT | Motivación principal elegida |
| `valores_grupo` | TEXT | Respuesta abierta (puede ser NULL) |
| `mejora_sugerida` | TEXT | Respuesta abierta (puede ser NULL) |

---

## Vista `v_resumen_sesiones`

Junta todas las tablas en una sola fila por sesión. Es lo que usa el panel admin en la tabla principal.

```sql
SELECT * FROM v_resumen_sesiones;
```

Columnas principales que devuelve:

| Columna | Descripción |
|---------|-------------|
| `sesion_id` | UUID de la sesión |
| `nombre` | Nombre de la jugadora |
| `posicion` | Posición en el equipo |
| `trayectoria` | Años en el equipo |
| `logica_correctas` | Cuántas preguntas de lógica acertó (0–3) |
| `atencion_aciertos` | Aciertos en la grilla de atención |
| `atencion_total` | Total de targets (10) |
| `falsos_positivos` | Errores en la grilla |
| `memoria_ok` | TRUE/FALSE |
| `reaccion_ms_avg` | Promedio de los 3 intentos de reacción |
| `personalidad_avg` | Promedio Likert de personalidad (1–5) |
| `comunicacion_avg` | Promedio Likert de comunicación (1–5) |
| `nivel_union` | Respuesta cohesión |
| `motivacion` | Motivación principal |
| `created_at` | Fecha de la evaluación |

---

## Consultas útiles

### Ver todas las evaluaciones completadas
```sql
SELECT * FROM v_resumen_sesiones;
```

### Ranking por tiempo de reacción (menor = mejor)
```sql
SELECT j.nombre, ROUND(AVG(r.tiempo_ms)) AS ms_promedio
FROM resultado_reaccion r
JOIN sesiones s ON s.id = r.sesion_id
JOIN jugadoras j ON j.id = s.jugadora_id
GROUP BY j.nombre
ORDER BY ms_promedio ASC;
```

### Promedio de personalidad por posición
```sql
SELECT j.posicion, ROUND(AVG(p.valor)::numeric, 2) AS personalidad_avg
FROM resultado_personalidad p
JOIN sesiones s ON s.id = p.sesion_id
JOIN jugadoras j ON j.id = s.jugadora_id
GROUP BY j.posicion
ORDER BY personalidad_avg DESC;
```

### Jugadoras con más de 1 alerta (para revisar)
```sql
SELECT j.nombre, j.posicion,
  (SELECT COUNT(*) FROM resultado_logica l WHERE l.sesion_id = s.id AND l.correcta) AS logica_ok,
  a.aciertos, a.total_targets,
  ROUND(AVG(r.tiempo_ms)) AS reaccion_ms
FROM sesiones s
JOIN jugadoras j ON j.id = s.jugadora_id
LEFT JOIN resultado_atencion a ON a.sesion_id = s.id
LEFT JOIN resultado_reaccion r ON r.sesion_id = s.id
WHERE s.completada = TRUE
GROUP BY j.nombre, j.posicion, s.id, a.aciertos, a.total_targets;
```

### Respuestas abiertas sobre mejoras sugeridas
```sql
SELECT j.nombre, m.mejora_sugerida
FROM resultado_motivacion m
JOIN sesiones s ON s.id = m.sesion_id
JOIN jugadoras j ON j.id = s.jugadora_id
WHERE m.mejora_sugerida IS NOT NULL AND m.mejora_sugerida != ''
ORDER BY s.created_at DESC;
```

### Backup completo
```bash
sudo -u postgres pg_dump hockey_eval > backup_$(date +%Y%m%d_%H%M).sql
```

### Restaurar backup
```bash
sudo -u postgres psql hockey_eval < backup_20250318.sql
```
