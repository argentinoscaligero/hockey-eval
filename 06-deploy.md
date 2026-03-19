# 06 — Guía de despliegue

> Sistema operativo: Ubuntu 22.04 o 24.04 LTS  
> Asumimos acceso SSH con `sudo` al servidor.

---

## Paso 1 — Instalar dependencias del sistema

```bash
# Actualizar paquetes
sudo apt update && sudo apt upgrade -y

# Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verificar
node --version   # debe mostrar v20.x.x
npm --version

# PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Nginx
sudo apt install -y nginx

# Certbot para SSL gratuito
sudo apt install -y certbot python3-certbot-nginx

# PM2 — process manager para Node.js
sudo npm install -g pm2

# Verificar PM2
pm2 --version
```

---

## Paso 2 — Configurar PostgreSQL

```bash
# Entrar a la consola de postgres
sudo -u postgres psql
```

Dentro de `psql`, ejecutar:

```sql
-- Crear base de datos
CREATE DATABASE hockey_eval;

-- Crear usuario de aplicación (elegir una contraseña segura)
CREATE USER hockey_app WITH PASSWORD 'ELEGÍ_UNA_PASSWORD_SEGURA';

-- Dar permisos
GRANT CONNECT ON DATABASE hockey_eval TO hockey_app;
\c hockey_eval
GRANT USAGE ON SCHEMA public TO hockey_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO hockey_app;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO hockey_app;

-- Salir
\q
```

Luego, aplicar el schema:

```bash
sudo -u postgres psql hockey_eval < /opt/hockey-eval/db/schema.sql

# Verificar que se crearon las tablas
sudo -u postgres psql hockey_eval -c "\dt"
```

Deberías ver 10 tablas (`jugadoras`, `sesiones`, `resultado_logica`, etc.) y la vista `v_resumen_sesiones`.

---

## Paso 3 — Subir el backend al servidor

Desde tu máquina local (o usando SFTP/FileZilla):

```bash
# Crear el directorio en el servidor
sudo mkdir -p /opt/hockey-eval
sudo chown $USER:$USER /opt/hockey-eval

# Copiar desde tu máquina local
scp -r hockey-eval/backend/ usuario@IP_SERVIDOR:/opt/hockey-eval/
scp -r hockey-eval/db/      usuario@IP_SERVIDOR:/opt/hockey-eval/
```

En el servidor, instalar dependencias:

```bash
cd /opt/hockey-eval/backend
npm install --production
```

---

## Paso 4 — Configurar las variables de entorno

```bash
cd /opt/hockey-eval/backend

# Copiar el template
cp .env.example .env

# Editar
nano .env
```

Completar cada variable. Para generar los valores secretos:

```bash
# Generar JWT_SECRET (ejecutar en el servidor o en tu PC)
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# Generar el hash de la contraseña del admin
# Reemplazá 'mi_password_segura' por la contraseña que quieras usar
node -e "const b=require('bcryptjs'); b.hash('mi_password_segura', 12).then(console.log)"
```

Proteger el archivo:

```bash
chmod 600 /opt/hockey-eval/backend/.env
```

---

## Paso 5 — Iniciar el backend con PM2

```bash
cd /opt/hockey-eval/backend

# Iniciar el proceso
pm2 start server.js --name hockey-eval

# Verificar que está corriendo
pm2 status

# Ver los logs (deberías ver "✅ Hockey Eval API corriendo en puerto 3001")
pm2 logs hockey-eval

# Configurar para que arranque automáticamente con el servidor
pm2 startup
# Ejecutar el comando que PM2 te indica (empieza con "sudo env PATH=...")
pm2 save
```

Verificar que la API responde:

```bash
curl http://localhost:3001/api/health
# Respuesta esperada: {"status":"ok","db":"connected",...}
```

---

## Paso 6 — Desplegar el frontend

```bash
# Crear el directorio web
sudo mkdir -p /var/www/hockey-eval
sudo chown $USER:$USER /var/www/hockey-eval

# Copiar el HTML desde tu máquina local
scp hockey-eval/frontend/index.html usuario@IP_SERVIDOR:/var/www/hockey-eval/

# O si ya está en el servidor
cp /opt/hockey-eval/frontend/index.html /var/www/hockey-eval/
```

---

## Paso 7 — Configurar Nginx (sin SSL todavía)

```bash
# Copiar la configuración
sudo cp /opt/hockey-eval/nginx/hockey-eval.conf /etc/nginx/sites-available/hockey-eval

# Editar y reemplazar tests.miclub.com.ar por tu subdominio
sudo nano /etc/nginx/sites-available/hockey-eval

# Activar el sitio
sudo ln -s /etc/nginx/sites-available/hockey-eval /etc/nginx/sites-enabled/

# Verificar sintaxis
sudo nginx -t

# Recargar Nginx
sudo systemctl reload nginx
```

> ⚠️ En este punto la config apunta a los certificados que aún no existen. Para la prueba inicial podés comentar temporalmente los bloques `ssl_*` y escuchar solo en el puerto 80.

---

## Paso 8 — Obtener el certificado SSL

Antes de este paso, el registro DNS del subdominio debe estar apuntando a la IP del servidor. Verificarlo con:

```bash
dig tests.miclub.com.ar   # o nslookup tests.miclub.com.ar
```

Una vez que el DNS resuelve correctamente:

```bash
sudo certbot --nginx -d tests.miclub.com.ar
```

Certbot va a pedir un email, aceptar los términos, y automáticamente:
- Verificar que el dominio apunta al servidor
- Obtener el certificado
- Modificar la config de Nginx para agregar las rutas SSL
- Recargar Nginx

Verificar que el timer de renovación está activo:

```bash
sudo systemctl status certbot.timer
```

---

## Paso 9 — Configurar el firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'   # abre puertos 80 y 443
sudo ufw enable

# Verificar — el puerto 3001 NO debe aparecer como abierto
sudo ufw status
```

---

## Paso 10 — Verificación final

```bash
# 1. API health check
curl https://tests.miclub.com.ar/api/health

# 2. Abrir en el navegador
# https://tests.miclub.com.ar  →  debe cargar el formulario de la jugadora

# 3. Hacer una evaluación de prueba
# Completar el test completo y verificar que aparece en el panel admin

# 4. Verificar que los datos llegaron a la DB
sudo -u postgres psql hockey_eval -c "SELECT nombre, posicion FROM jugadoras;"
```

---

## Resumen de ubicaciones en el servidor

| Qué | Dónde |
|-----|-------|
| Frontend | `/var/www/hockey-eval/index.html` |
| Backend | `/opt/hockey-eval/backend/` |
| Schema DB | `/opt/hockey-eval/db/schema.sql` |
| Config Nginx | `/etc/nginx/sites-available/hockey-eval` |
| Variables de entorno | `/opt/hockey-eval/backend/.env` |
| Logs Nginx | `/var/log/nginx/hockey-eval.*.log` |
| Certificados SSL | `/etc/letsencrypt/live/tests.miclub.com.ar/` |
