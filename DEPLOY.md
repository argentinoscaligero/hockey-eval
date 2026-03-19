# Guía de despliegue — Hockey Eval
# Preseleccionado Damas +55 · Ubuntu 22/24 LTS

## ESTRUCTURA DEL PROYECTO EN EL SERVIDOR
```
/var/www/hockey-eval/          ← frontend estático (Nginx sirve desde aquí)
/opt/hockey-eval/              ← backend Node.js
/etc/nginx/sites-available/    ← config Nginx
```

---

## PASO 1 — Instalar dependencias del sistema

```bash
# Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Nginx
sudo apt install -y nginx

# Certbot (SSL gratuito con Let's Encrypt)
sudo apt install -y certbot python3-certbot-nginx

# PM2 (process manager para Node.js)
sudo npm install -g pm2
```

---

## PASO 2 — Configurar PostgreSQL

```bash
# Entrar como postgres
sudo -u postgres psql

# Dentro de psql:
CREATE DATABASE hockey_eval;
CREATE USER hockey_app WITH PASSWORD 'ELEGÍ_UNA_PASSWORD_SEGURA';
GRANT CONNECT ON DATABASE hockey_eval TO hockey_app;
\c hockey_eval
GRANT USAGE ON SCHEMA public TO hockey_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO hockey_app;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO hockey_app;
\q

# Aplicar el schema
sudo -u postgres psql hockey_eval < /opt/hockey-eval/db/schema.sql

# Verificar
sudo -u postgres psql hockey_eval -c "\dt"
```

---

## PASO 3 — Subir y configurar el backend

```bash
# Crear directorio
sudo mkdir -p /opt/hockey-eval
sudo chown $USER:$USER /opt/hockey-eval

# Copiar archivos del backend (desde tu máquina local):
scp -r backend/ usuario@tu-servidor:/opt/hockey-eval/
scp -r db/      usuario@tu-servidor:/opt/hockey-eval/

# En el servidor: instalar dependencias
cd /opt/hockey-eval/backend
npm install --production

# Crear archivo .env (¡NUNCA subir al repo!)
cp .env.example .env
nano .env
```

### Completar el .env con:
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hockey_eval
DB_USER=hockey_app
DB_PASSWORD=LA_PASSWORD_QUE_ELEGISTE

PORT=3001
NODE_ENV=production

# Generar JWT_SECRET:
# node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
JWT_SECRET=PEGAR_RESULTADO_AQUI

# Generar hash de la password del admin:
# node -e "const b=require('bcryptjs');b.hash('TU_PASSWORD_ADMIN',12).then(console.log)"
ADMIN_PASSWORD_HASH=PEGAR_HASH_AQUI

FRONTEND_URL=https://tests.miclub.com.ar
```

```bash
# Proteger el .env
chmod 600 /opt/hockey-eval/backend/.env
```

---

## PASO 4 — Iniciar el backend con PM2

```bash
cd /opt/hockey-eval/backend

# Iniciar
pm2 start server.js --name hockey-eval

# Verificar que está corriendo
pm2 status
pm2 logs hockey-eval

# Configurar para que arranque con el sistema
pm2 startup
pm2 save
```

---

## PASO 5 — Desplegar el frontend

```bash
# Crear directorio web
sudo mkdir -p /var/www/hockey-eval
sudo chown $USER:$USER /var/www/hockey-eval

# Copiar el HTML (desde tu máquina local)
scp frontend/index.html usuario@tu-servidor:/var/www/hockey-eval/

# O desde el servidor directamente:
cp /opt/hockey-eval/frontend/index.html /var/www/hockey-eval/
```

---

## PASO 6 — Configurar Nginx

```bash
# Copiar la config
sudo cp /opt/hockey-eval/nginx/hockey-eval.conf /etc/nginx/sites-available/hockey-eval

# Editar y poner tu subdominio real
sudo nano /etc/nginx/sites-available/hockey-eval
# Reemplazar tests.miclub.com.ar por tu subdominio

# Activar el sitio
sudo ln -s /etc/nginx/sites-available/hockey-eval /etc/nginx/sites-enabled/
sudo nginx -t   # verificar sintaxis
sudo systemctl reload nginx
```

---

## PASO 7 — Obtener certificado SSL (HTTPS gratuito)

```bash
# Asegurate de que el DNS del subdominio ya apunte al servidor
# (registro A en tu panel de DNS: tests.miclub.com.ar → IP_DEL_SERVIDOR)

sudo certbot --nginx -d tests.miclub.com.ar

# Seguir las instrucciones, poner email, aceptar ToS
# Certbot configura HTTPS automáticamente

# Verificar renovación automática
sudo systemctl status certbot.timer
```

---

## PASO 8 — Verificar que todo funciona

```bash
# Test API health
curl https://tests.miclub.com.ar/api/health

# Debería responder: {"status":"ok","db":"connected",...}

# Logs en tiempo real
pm2 logs hockey-eval
sudo tail -f /var/log/nginx/hockey-eval.error.log
```

---

## MANTENIMIENTO

```bash
# Actualizar el frontend (solo copiar el HTML)
cp nuevo-index.html /var/www/hockey-eval/index.html

# Actualizar el backend
cd /opt/hockey-eval/backend
git pull   # o copiar archivos manualmente
npm install --production
pm2 restart hockey-eval

# Ver respuestas en la DB directamente
sudo -u postgres psql hockey_eval
SELECT * FROM v_resumen_sesiones;

# Backup de la DB
sudo -u postgres pg_dump hockey_eval > backup_$(date +%Y%m%d).sql
```

---

## SEGURIDAD ADICIONAL (recomendado)

```bash
# Firewall: solo abrir puertos necesarios
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable

# El puerto 3001 (Node.js) NO debe estar expuesto públicamente
# Nginx hace de proxy — verificar que no esté abierto:
sudo ufw status
```

---

## RESUMEN DE ARCHIVOS

| Archivo | Destino en servidor | Descripción |
|---------|--------------------|-----------  |
| `db/schema.sql` | Ejecutar en psql | Crea todas las tablas y la vista |
| `backend/` | `/opt/hockey-eval/backend/` | API Node.js + Express |
| `frontend/index.html` | `/var/www/hockey-eval/` | App completa (jugadoras + admin) |
| `nginx/hockey-eval.conf` | `/etc/nginx/sites-available/` | Config Nginx con SSL |
