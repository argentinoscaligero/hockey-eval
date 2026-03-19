# 01 — Arquitectura del sistema

## Visión general

La plataforma es una aplicación web de una sola página (SPA) que corre completamente en tu servidor Linux. No depende de servicios externos de terceros salvo Let's Encrypt para el certificado SSL.

```
Internet
    │
    ▼
[ Nginx :443 ]  ← HTTPS, SSL/TLS
    │
    ├──/             → /var/www/hockey-eval/index.html   (archivos estáticos)
    │
    └──/api/*        → http://127.0.0.1:3001             (Node.js / Express)
                                │
                                ▼
                        [ PostgreSQL :5432 ]
                          DB: hockey_eval
```

---

## Stack tecnológico

| Capa | Tecnología | Versión recomendada |
|------|-----------|---------------------|
| Frontend | HTML5 + CSS3 + JS vanilla | — |
| Gráficos admin | Chart.js | 4.4.x |
| Backend | Node.js + Express | Node 20 LTS |
| ORM / DB driver | node-postgres (`pg`) | 8.x |
| Autenticación | JWT (`jsonwebtoken`) + bcrypt | — |
| Base de datos | PostgreSQL | 15+ |
| Servidor web | Nginx | 1.24+ |
| Process manager | PM2 | 5.x |
| SSL | Let's Encrypt (certbot) | — |
| OS | Ubuntu | 22.04 o 24.04 LTS |

---

## Estructura de archivos (en el servidor)

```
/opt/hockey-eval/                  ← raíz del backend
├── backend/
│   ├── server.js                  ← punto de entrada Express
│   ├── db.js                      ← pool de conexiones PostgreSQL
│   ├── package.json
│   ├── .env                       ← variables de entorno (NO subir al repo)
│   ├── middleware/
│   │   └── requireAdmin.js        ← validación JWT
│   └── routes/
│       ├── auth.js                ← POST /api/auth/login
│       ├── evaluacion.js          ← POST /api/eval/submit
│       └── admin.js               ← GET /api/admin/*
└── db/
    └── schema.sql                 ← definición completa de la DB

/var/www/hockey-eval/
└── index.html                     ← toda la app frontend

/etc/nginx/sites-available/
└── hockey-eval.conf               ← configuración Nginx

/etc/letsencrypt/                  ← certificados SSL (gestionado por certbot)
```

---

## Flujo de datos — evaluación de una jugadora

```
1. Jugadora abre https://tests.miclub.com.ar
2. Rellena nombre, posición, trayectoria → empieza el test
3. Completa 5 módulos psicotécnicos + 5 módulos grupales
4. Al finalizar, el frontend arma un JSON con todas las respuestas
5. POST /api/eval/submit  →  Express lo recibe
6. Una transacción PostgreSQL inserta en 10 tablas de forma atómica
   (si algo falla, no queda nada a medias — todo se revierte)
7. La jugadora ve la pantalla de confirmación con su resumen
```

## Flujo de datos — panel admin

```
1. Admin hace clic en "Admin" → ingresa contraseña
2. POST /api/auth/login → bcrypt verifica hash → devuelve JWT (8h)
3. El token se guarda en memoria (JS) — nunca en localStorage
4. Todas las llamadas admin incluyen Authorization: Bearer <token>
5. Express verifica JWT en cada ruta protegida
6. Los datos llegan desde la vista v_resumen_sesiones y queries específicas
7. Chart.js renderiza los gráficos en el cliente
```

---

## Puertos y servicios

| Servicio | Puerto | Expuesto públicamente |
|----------|--------|----------------------|
| Nginx | 80, 443 | ✅ Sí |
| Node.js / Express | 3001 | ❌ No (solo localhost) |
| PostgreSQL | 5432 | ❌ No (solo localhost) |

> El puerto 3001 **nunca** debe estar abierto en el firewall. Nginx actúa de intermediario.
