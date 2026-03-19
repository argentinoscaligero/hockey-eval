# 04 — Frontend (index.html)

## Características generales

- Un único archivo HTML autocontenido: no hay bundler, no hay dependencias npm.
- Se sirve como archivo estático desde Nginx.
- Usa `fetch()` para comunicarse con la API en `/api/*` (mismo origen, sin CORS).
- La librería Chart.js se carga desde CDN (cdnjs.cloudflare.com).
- No usa `localStorage` ni `sessionStorage` — todo el estado vive en variables JS en memoria.

---

## Pantallas de la aplicación

```
screen-entry    ← ingreso de datos de la jugadora
    ↓
screen-tests
    ├── section-0 (psicotécnico)
    │   ├── mod-0  Razonamiento lógico
    │   ├── mod-1  Personalidad deportiva
    │   ├── mod-2  Atención y concentración
    │   ├── mod-3  Memoria y percepción
    │   └── mod-4  Tiempo de reacción
    └── section-1 (grupal)
        ├── gmod-0  Cohesión de equipo
        ├── gmod-1  Roles y liderazgo
        ├── gmod-2  Comunicación interna
        ├── gmod-3  Manejo del conflicto
        └── gmod-4  Motivación y compromiso
    ↓
screen-final    ← confirmación con resumen de resultados
```

El panel admin es una pantalla separada accesible desde el botón "Admin" en el header.

---

## Módulos del test psicotécnico

### Módulo 1 — Razonamiento lógico
3 preguntas de opción múltiple contextualizadas al hockey. Cada respuesta queda registrada junto con si fue correcta o no.

### Módulo 2 — Personalidad deportiva
Escala Likert 1–5 con 5 ítems sobre temperamento competitivo:
1. Calma bajo presión
2. Aceptación de críticas
3. Entrega independientemente del marcador
4. Juego colectivo vs. lucimiento individual
5. Recuperación emocional tras errores

### Módulo 3 — Atención y concentración
Grilla de 48 números (6×8 o 8×6 según pantalla). El jugador debe marcar todos los `7`. Hay exactamente 10 sevens en posiciones aleatorias. Cronómetro de 45 segundos. Se registran aciertos y falsos positivos.

### Módulo 4 — Memoria y percepción
Grilla de 12 emojis. El sistema ilumina 4 en secuencia aleatoria (800ms por figura). La jugadora debe replicar el orden tocándolos. Puede reintentar. Se registra si fue correcta y la cantidad de intentos.

### Módulo 5 — Tiempo de reacción
Recuadro que cambia de rojo a verde tras un delay aleatorio (1.5–4.5 segundos). 3 intentos. Se registran los ms de cada intento y se calcula el promedio. Si toca antes del verde, el intento se cancela (no se penaliza).

---

## Módulos del test grupal

### Cohesión de equipo
2 preguntas de opción múltiple sobre nivel de unión percibido y frecuencia de apoyo entre compañeras.

### Roles y liderazgo
2 preguntas sobre claridad del propio rol y a quién se recurre en momentos de decisión.

### Comunicación interna
Escala Likert 1–5 sobre 5 dimensiones de comunicación (durante el juego, entrenamientos, fuera de la cancha, con el cuerpo técnico, escucha activa).

### Manejo del conflicto
1 pregunta cerrada sobre el mecanismo habitual de resolución + 1 pregunta abierta para describir una situación concreta.

### Motivación y compromiso
1 pregunta cerrada sobre motivación principal + 2 preguntas abiertas sobre valores del grupo y mejoras sugeridas.

---

## Panel de administración

### Acceso
Botón "Admin" en el header → contraseña → JWT almacenado en memoria JS.

### Pestañas

#### 📋 Respuestas
Tabla con todas las sesiones completadas. Columnas: nombre, posición, lógica (pill verde/amarillo), atención, memoria, reacción, promedios Likert, fecha. Botón "Ver →" abre el modal de detalle completo.

#### 🏅 Ranking
5 sub-tablas con ranking ordenado por cada dimensión evaluada:
- Razonamiento lógico (0–3, mayor = mejor)
- Atención % de aciertos (mayor = mejor)
- Reacción en ms (menor = mejor)
- Personalidad promedio (1–5, mayor = mejor)
- Comunicación promedio (1–5, mayor = mejor)

#### 📊 Gráficos
- **Radar individual:** selector de jugadora → gráfico de tela de araña con 6 dimensiones normalizadas a 0–10
- **Barras comparativas:** 4 gráficos horizontales mostrando a todas las jugadoras lado a lado en Lógica, Reacción, Personalidad y Comunicación

#### ⚠️ Alertas
Lista de jugadoras que superaron uno o más umbrales de alerta. Si ninguna tiene alertas, muestra mensaje de confirmación. Cada alerta tiene su etiqueta descriptiva y botón para ver el detalle completo.

### Modal de detalle
Abre todas las respuestas de una jugadora organizadas por sección: datos personales, cada módulo psicotécnico con sus respuestas y resultados, y cada dimensión grupal incluyendo las respuestas abiertas.

### Exportar CSV
Descarga directamente desde la API un `.csv` con BOM UTF-8, listo para abrir en Excel sin problemas de encoding.

---

## Configuración del endpoint API

En la línea 1 del bloque `<script>` del frontend:

```javascript
const API = '/api';  // mismo origen vía Nginx
```

Si en algún momento el backend estuviera en un dominio diferente, cambiar a:

```javascript
const API = 'https://api.miclub.com.ar';
```

---

## Compatibilidad

- Chrome / Edge / Firefox / Safari modernos (2022+)
- iOS Safari 15+
- Android Chrome 100+
- No requiere instalación — funciona directamente en el navegador
- Responsive: adaptado para pantallas desde 320px
