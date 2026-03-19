# 05 — Nginx

## Rol de Nginx en el sistema

Nginx cumple tres funciones:

1. **Servir el frontend** — entrega `index.html` y cualquier archivo estático desde `/var/www/hockey-eval/`
2. **Reverse proxy** — redirige las llamadas a `/api/*` al proceso Node.js que corre en `127.0.0.1:3001`
3. **SSL/TLS** — termina HTTPS, los certificados son de Let's Encrypt (gratuitos, renovación automática)

---

## Archivo de configuración

Ubicación en el servidor: `/etc/nginx/sites-available/hockey-eval`

### Bloque HTTP (redirige a HTTPS)

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name tests.miclub.com.ar;

    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://$host$request_uri; }
}
```

Todo el tráfico HTTP es redirigido a HTTPS con código 301 (permanente). La excepción es la ruta de verificación de certbot.

### Bloque HTTPS

```nginx
server {
    listen 443 ssl http2;
    server_name tests.miclub.com.ar;

    ssl_certificate     /etc/letsencrypt/live/tests.miclub.com.ar/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tests.miclub.com.ar/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ...
}
```

---

## Rutas configuradas

### `/` — Frontend estático

```nginx
root /var/www/hockey-eval;
index index.html;

location / {
    try_files $uri $uri/ /index.html;
}
```

`try_files` primero busca el archivo exacto, luego el directorio, y si no encuentra nada devuelve `index.html`. Esto es necesario para que funcione como SPA.

**Cache para assets estáticos:**
```nginx
location ~* \.(js|css|png|jpg|ico|svg|woff2?)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

### `/api/` — Reverse proxy a Node.js

```nginx
location /api/ {
    proxy_pass         http://127.0.0.1:3001;
    proxy_http_version 1.1;
    proxy_set_header   Host $host;
    proxy_set_header   X-Real-IP $remote_addr;
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_read_timeout 30s;
    client_max_body_size 2m;
}
```

Los headers `X-Real-IP` y `X-Forwarded-For` permiten que el backend reciba la IP real del cliente aunque el tráfico pase por Nginx.

---

## Headers de seguridad

```nginx
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header Referrer-Policy "strict-origin-when-cross-origin";
```

| Header | Efecto |
|--------|--------|
| `HSTS` | Los navegadores solo usarán HTTPS durante 2 años |
| `X-Frame-Options DENY` | Previene que la app se cargue en un iframe |
| `X-Content-Type-Options` | Previene MIME-sniffing |
| `Referrer-Policy` | Controla qué info de referrer se envía |

---

## Comandos útiles de Nginx

```bash
# Verificar sintaxis de la configuración antes de recargar
sudo nginx -t

# Recargar configuración sin cortar conexiones activas
sudo systemctl reload nginx

# Reiniciar completamente
sudo systemctl restart nginx

# Ver estado del servicio
sudo systemctl status nginx

# Ver logs en tiempo real
sudo tail -f /var/log/nginx/hockey-eval.access.log
sudo tail -f /var/log/nginx/hockey-eval.error.log

# Activar el sitio (crear symlink)
sudo ln -s /etc/nginx/sites-available/hockey-eval /etc/nginx/sites-enabled/

# Desactivar el sitio
sudo rm /etc/nginx/sites-enabled/hockey-eval
```

---

## SSL con Let's Encrypt

### Obtener el certificado por primera vez

```bash
# El DNS del subdominio debe apuntar al servidor ANTES de correr esto
sudo certbot --nginx -d tests.miclub.com.ar
```

Certbot modifica automáticamente la config de Nginx para agregar los paths de los certificados.

### Renovación automática

Los certificados de Let's Encrypt duran 90 días. Certbot instala un timer systemd que los renueva automáticamente cuando quedan menos de 30 días.

```bash
# Verificar que el timer esté activo
sudo systemctl status certbot.timer

# Simular una renovación sin aplicarla
sudo certbot renew --dry-run
```

### Ubicación de los certificados

```
/etc/letsencrypt/live/tests.miclub.com.ar/
├── fullchain.pem    ← certificado + cadena (usar en ssl_certificate)
├── privkey.pem      ← clave privada (usar en ssl_certificate_key)
├── cert.pem         ← solo el certificado
└── chain.pem        ← solo la cadena intermedia
```

---

## Solución de problemas comunes

### `nginx -t` da error de sintaxis
Revisar que el subdominio esté correctamente escrito y que las rutas de certificados existan.

### Error 502 Bad Gateway
Node.js no está corriendo. Verificar con `pm2 status` y `pm2 logs hockey-eval`.

### Error 404 al recargar la página
Faltan los `try_files` para manejar la SPA. Verificar que el bloque `location /` tenga `try_files $uri $uri/ /index.html`.

### Certificado SSL expirado
```bash
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```
