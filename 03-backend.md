# 03 — Backend (Node.js + Express)

## Estructura de archivos

```
backend/
├── server.js               ← punto de entrada, middlewares globales
├── db.js                   ← pool de conexiones a PostgreSQL
├── package.json
├── .env                    ← variables de entorno (no subir al repo)
├── .env.example            ← template con instrucciones
├── middleware/
│   └── requireAdmin.js     ← valida el JWT en rutas protegidas
└── routes/
    ├── auth.js             ← autenticación del administrador
    ├── evaluacion.js       ← recibe y guarda el test completo
    └── admin.js            ← endpoints del panel de análisis
```

---

## Variables de entorno (`.env`)

```bash
# Base de datos
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hockey_eval
DB_USER=hockey_app
DB_PASSWORD=TU_PASSWORD_SEGURA

# Servidor
PORT=3001
NODE_ENV=production

# JWT — generar con:
# node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
JWT_SECRET=STRING_ALEATORIO_LARGO

# Hash bcrypt de la contraseña admin — generar con:
# node -e "const b=require('bcryptjs'); b.hash('TU_PASSWORD',12).then(console.log)"
ADMIN_PASSWORD_HASH=$2a$12$HASH_AQUI

# CORS — URL del frontend
FRONTEND_URL=https://tests.miclub.com.ar
```

> ⚠️ El archivo `.env` nunca debe subirse a un repositorio git. Agregarlo al `.gitignore`.

---

## Endpoints de la API

### `GET /api/health`
Health check. No requiere autenticación.

**Respuesta exitosa:**
```json
{
  "status": "ok",
  "db": "connected",
  "ts": "2025-03-18T10:00:00.000Z"
}
```

---

### `POST /api/auth/login`
Login del administrador. Verifica la contraseña con bcrypt y devuelve un JWT válido por 8 horas.

**Body:**
```json
{
  "password": "la_contraseña_del_admin"
}
```

**Respuesta exitosa:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": "8h"
}
```

**Errores:**
- `400` — contraseña no enviada
- `401` — contraseña incorrecta
- `429` — demasiados intentos (rate limit: 10 por hora)

---

### `POST /api/eval/submit`
Guarda la evaluación completa de una jugadora. Toda la operación es una transacción PostgreSQL: si algo falla en cualquier tabla, se revierte todo.

**Body completo:**
```json
{
  "jugadora": {
    "nombre": "María García",
    "posicion": "Mediocampista",
    "trayectoria": "4 a 7 años"
  },
  "psicotecnico": {
    "logica": [
      { "pregunta": 1, "respuesta": "3 goles", "correcta": true },
      { "pregunta": 2, "respuesta": "Ninguna claramente", "correcta": true },
      { "pregunta": 3, "respuesta": "El control", "correcta": true }
    ],
    "personalidad": [
      { "item": 1, "descripcion": "Mantengo la calma...", "valor": 4 },
      { "item": 2, "descripcion": "Acepto bien las críticas...", "valor": 5 }
    ],
    "atencion": {
      "aciertos": 8,
      "totalTargets": 10,
      "falsosPositivos": 1
    },
    "memoria": {
      "correcta": true,
      "intentos": 1
    },
    "reaccion": [245, 312, 198]
  },
  "grupal": {
    "cohesion": {
      "nivelUnion": "Alta — nos llevamos bien aunque no compartamos todo",
      "apoyo": "Casi siempre"
    },
    "liderazgo": {
      "claridadRol": "Sí, completamente claro",
      "referente": "La capitana / vice-capitana designada"
    },
    "comunicacion": [
      { "item": 1, "descripcion": "Comunicación durante el juego", "valor": 4 }
    ],
    "conflicto": {
      "mecanismo": "Se habla en el momento, dentro del grupo",
      "relato": "En el último torneo tuvimos una diferencia táctica..."
    },
    "motivacion": {
      "motivacion": "El vínculo con mis compañeras",
      "valoresGrupo": "La amistad y el respeto mutuo",
      "mejoraSugerida": "Más reuniones de equipo fuera de la cancha"
    }
  }
}
```

**Respuesta exitosa:**
```json
{
  "ok": true,
  "sesionId": "uuid-de-la-sesion"
}
```

**Errores:**
- `400` — datos de jugadora incompletos
- `500` — error de base de datos (con rollback automático)

---

### `GET /api/admin/resumen` 🔒
Devuelve todas las sesiones completas usando la vista `v_resumen_sesiones`. Requiere JWT.

---

### `GET /api/admin/jugadora/:sesionId` 🔒
Detalle completo de una jugadora por sesión: todas las tablas unidas. Se usa en el modal de detalle.

---

### `GET /api/admin/ranking` 🔒
Ranking por dimensión + array de alertas automáticas por jugadora. Las alertas se calculan en SQL con umbrales predefinidos:

| Alerta | Umbral |
|--------|--------|
| Lógica baja | Menos de 2 correctas |
| Personalidad a trabajar | Promedio < 3 |
| Atención reducida | Aciertos < 60% |
| Memoria a reforzar | Secuencia incorrecta |
| Reacción lenta | Promedio > 400ms |
| Comunicación grupal baja | Promedio < 3 |

---

### `GET /api/admin/comparativa` 🔒
Scores normalizados 0–10 por jugadora para graficar el radar y las barras comparativas.

| Dimensión | Normalización |
|-----------|--------------|
| Lógica | (correctas / 3) × 10 |
| Personalidad | (avg − 1) / 4 × 10 |
| Atención | (aciertos / total) × 10 |
| Memoria | 10 si correcta, 4 si no |
| Reacción | Invertida: 150ms=10, 600ms=0 |
| Comunicación | (avg − 1) / 4 × 10 |

---

### `GET /api/admin/export/csv` 🔒
Devuelve un archivo `.csv` con BOM UTF-8 (compatible con Excel en español) con todas las sesiones de `v_resumen_sesiones`.

---

## Seguridad implementada

- **Helmet** — headers HTTP de seguridad (CSP, X-Frame-Options, etc.)
- **CORS** — solo acepta requests desde `FRONTEND_URL`
- **Rate limiting** — 100 requests / 15 min general, 10 intentos / hora en `/auth/login`
- **bcrypt** (cost factor 12) — la contraseña admin nunca se guarda en texto plano
- **JWT** — expira en 8 horas, firmado con secret de 64 bytes aleatorios
- **Pool de conexiones** — máximo 10 conexiones simultáneas a PostgreSQL
- **Transacciones** — los envíos de test usan `BEGIN / COMMIT / ROLLBACK`
- **Puerto 3001** — solo escucha en `127.0.0.1`, nunca expuesto públicamente

---

## Dependencias (`package.json`)

| Paquete | Uso |
|---------|-----|
| `express` | Framework web |
| `pg` | Driver PostgreSQL |
| `cors` | Control de CORS |
| `helmet` | Headers de seguridad |
| `express-rate-limit` | Rate limiting |
| `dotenv` | Variables de entorno |
| `bcryptjs` | Hash de contraseñas |
| `jsonwebtoken` | Generación y validación de JWT |
| `uuid` | Generación de UUIDs (por si se necesita en el futuro) |
