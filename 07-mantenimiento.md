# 07 — Mantenimiento y troubleshooting

## Operaciones cotidianas

### Ver estado de todos los servicios
```bash
pm2 status                          # Node.js
sudo systemctl status nginx         # Nginx
sudo systemctl status postgresql    # PostgreSQL
```

### Ver logs en tiempo real
```bash
pm2 logs hockey-eval                              # logs de Node.js
sudo tail -f /var/log/nginx/hockey-eval.error.log # errores Nginx
sudo tail -f /var/log/nginx/hockey-eval.access.log # accesos Nginx
```

### Reiniciar servicios
```bash
pm2 restart hockey-eval             # reiniciar Node.js (sin downtime)
sudo systemctl reload nginx         # recargar Nginx (sin cortar conexiones)
sudo systemctl restart postgresql   # reiniciar Postgres (solo si hace falta)
```

---

## Actualizar el frontend

Solo hay que reemplazar el archivo HTML:

```bash
# Desde tu máquina local
scp nuevo-index.html usuario@IP_SERVIDOR:/var/www/hockey-eval/index.html

# No hace falta restartar nada — Nginx sirve el archivo directamente
```

---

## Actualizar el backend

```bash
cd /opt/hockey-eval/backend

# Reemplazar los archivos JS modificados
# (o hacer git pull si usás git)

# Si hay nuevas dependencias
npm install --production

# Reiniciar el proceso
pm2 restart hockey-eval

# Verificar que levantó bien
pm2 logs hockey-eval --lines 20
```

---

## Base de datos

### Conectarse a la DB
```bash
sudo -u postgres psql hockey_eval
```

### Consultas de monitoreo
```bash
# Cuántas evaluaciones hay
sudo -u postgres psql hockey_eval -c "SELECT COUNT(*) FROM sesiones WHERE completada = TRUE;"

# Última evaluación recibida
sudo -u postgres psql hockey_eval -c "SELECT nombre, posicion, finished_at FROM sesiones JOIN jugadoras ON jugadoras.id = sesiones.jugadora_id ORDER BY finished_at DESC LIMIT 5;"

# Tamaño de la base
sudo -u postgres psql hockey_eval -c "SELECT pg_size_pretty(pg_database_size('hockey_eval'));"
```

### Backup manual
```bash
# Backup completo
sudo -u postgres pg_dump hockey_eval > /home/tu_usuario/backup_$(date +%Y%m%d_%H%M).sql

# Comprimir (recomendado para backups grandes)
sudo -u postgres pg_dump hockey_eval | gzip > /home/tu_usuario/backup_$(date +%Y%m%d_%H%M).sql.gz
```

### Restaurar backup
```bash
# Desde un .sql
sudo -u postgres psql hockey_eval < backup_20250318.sql

# Desde un .sql.gz
gunzip -c backup_20250318.sql.gz | sudo -u postgres psql hockey_eval
```

### Backup automático con cron
```bash
# Editar el crontab del usuario postgres
sudo crontab -u postgres -e

# Agregar esta línea para backup diario a las 3am:
0 3 * * * pg_dump hockey_eval > /var/backups/hockey_eval_$(date +\%Y\%m\%d).sql
```

---

## Cambiar la contraseña del admin

```bash
# Generar nuevo hash (reemplazá 'nueva_password' por la contraseña real)
node -e "const b=require('bcryptjs'); b.hash('nueva_password', 12).then(console.log)"

# Copiar el hash generado y pegarlo en el .env
nano /opt/hockey-eval/backend/.env
# Actualizar ADMIN_PASSWORD_HASH=...

# Restartar para que tome el nuevo valor
pm2 restart hockey-eval
```

---

## Renovar SSL manualmente (si hiciera falta)

```bash
sudo certbot renew
sudo systemctl reload nginx

# Verificar fecha de vencimiento
sudo certbot certificates
```

---

## Troubleshooting

### La app no carga (pantalla en blanco o error 502)

```bash
# 1. Verificar que Node.js está corriendo
pm2 status
# Si está "stopped" o "errored":
pm2 restart hockey-eval
pm2 logs hockey-eval

# 2. Verificar que Nginx está OK
sudo nginx -t
sudo systemctl status nginx
```

### Error "cannot connect to database"

```bash
# Verificar que PostgreSQL está corriendo
sudo systemctl status postgresql

# Verificar las credenciales en el .env
cat /opt/hockey-eval/backend/.env | grep DB_

# Probar la conexión manualmente
psql -h localhost -U hockey_app -d hockey_eval
```

### El panel admin dice "Error cargando datos"

```bash
# Verificar los logs del backend
pm2 logs hockey-eval

# Verificar que la vista existe en la DB
sudo -u postgres psql hockey_eval -c "\dv"
# Debe aparecer "v_resumen_sesiones"
```

### Error al guardar una evaluación

El backend usa transacciones atómicas. Si hay un error, no se guarda nada a medias. Ver el log:

```bash
pm2 logs hockey-eval --lines 50
```

Los errores de DB aparecen con el prefijo `[eval/submit]`.

### Nginx devuelve 404 al recargar la página

```bash
# Verificar que el location / tiene try_files correctamente
sudo cat /etc/nginx/sites-available/hockey-eval | grep -A3 "location /"
# Debe tener: try_files $uri $uri/ /index.html;

sudo nginx -t && sudo systemctl reload nginx
```

### El servidor se reinició y la app no levantó

```bash
# Verificar que PM2 está configurado para arrancar con el sistema
pm2 list
pm2 startup   # si no está configurado, ejecutar el comando que sugiere
pm2 save

# Levantar manualmente si hace falta
pm2 start /opt/hockey-eval/backend/server.js --name hockey-eval
```

---

## Monitoreo con PM2

```bash
# Dashboard interactivo (CPU, memoria, logs en tiempo real)
pm2 monit

# Métricas del proceso
pm2 show hockey-eval

# Historial de reinicios
pm2 logs hockey-eval --lines 100 | grep "restarted"
```

---

## Agregar nuevas jugadoras o limpiar datos de prueba

```bash
sudo -u postgres psql hockey_eval

-- Eliminar una evaluación de prueba (por nombre)
DELETE FROM jugadoras WHERE nombre = 'Prueba Test';
-- Las sesiones y resultados se eliminan en cascada automáticamente

-- Ver y confirmar antes de borrar
SELECT j.nombre, s.created_at, s.completada
FROM jugadoras j JOIN sesiones s ON s.jugadora_id = j.id
ORDER BY s.created_at DESC;
```
