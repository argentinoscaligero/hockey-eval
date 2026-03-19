# Hockey Eval — Documentación
### Preseleccionado Damas +55 · Hockey sobre Césped

---

## Índice de documentos

| # | Archivo | Contenido |
|---|---------|-----------|
| 1 | [`01-arquitectura.md`](./01-arquitectura.md) | Visión general del sistema, stack tecnológico y estructura de archivos |
| 2 | [`02-base-de-datos.md`](./02-base-de-datos.md) | Schema PostgreSQL: tablas, relaciones, vista y guía de consultas útiles |
| 3 | [`03-backend.md`](./03-backend.md) | API Node.js/Express: rutas, autenticación JWT, variables de entorno |
| 4 | [`04-frontend.md`](./04-frontend.md) | App HTML: módulos del test, flujo de navegación, panel admin |
| 5 | [`05-nginx.md`](./05-nginx.md) | Configuración Nginx: reverse proxy, SSL con Let's Encrypt |
| 6 | [`06-deploy.md`](./06-deploy.md) | Guía paso a paso de despliegue en servidor Linux (Ubuntu 22/24) |
| 7 | [`07-mantenimiento.md`](./07-mantenimiento.md) | Comandos de operación, backups, actualización y troubleshooting |

---

## Flujo rápido

```
Jugadora abre tests.miclub.com.ar
        ↓
Completa test psicotécnico + grupal
        ↓
POST /api/eval/submit  →  PostgreSQL (transacción atómica)
        ↓
Admin abre /admin  →  login JWT  →  panel de análisis + gráficos
```

---

## Stack

- **Frontend:** HTML5 + CSS3 + JS vanilla + Chart.js
- **Backend:** Node.js 20 + Express 4
- **Base de datos:** PostgreSQL 15+
- **Servidor web:** Nginx (reverse proxy + SSL)
- **Process manager:** PM2
- **SSL:** Let's Encrypt (certbot, renovación automática)

---

> Ante cualquier duda, empezá por [`06-deploy.md`](./06-deploy.md) que tiene todos los pasos en orden.
