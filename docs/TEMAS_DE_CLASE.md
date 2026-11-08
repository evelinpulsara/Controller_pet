# PetTracker — Temas de Programación Orientada a la Web

Este documento indica qué temas del curso usa PetTracker, para qué los usa, en qué parte del código están y cómo verlos funcionando.

Casi todo se puede ver en vivo en la app, en **Ajustes → Panel técnico**.

---

## 1. Métricas de rendimiento, Event Loop e INP

**INP (Interaction to Next Paint), medido en vivo**
- La app usa la *Event Timing API* del navegador (`PerformanceObserver` con `type: 'event'`).
- Mide cada interacción con la fórmula del curso: **INP = Input Delay + Processing Duration + Presentation Delay**.
- Clasifica el resultado con los umbrales del curso: Bueno ≤ 200 ms · Necesita mejora 200–500 ms · Pobre > 500 ms.
- Con 50 interacciones o más usa el percentil 98, igual que Chrome.
- También cuenta las *Long Tasks*, es decir, las tareas que bloquean el Main Thread.
- **Demostración:** el botón "Bloquear el hilo 600 ms" ocupa el hilo principal a propósito y el INP pasa a "Pobre".
- **Código:** `lib/core/perf/perf_monitor.dart` y `lib/core/perf/perf_platform_web.dart`.

**Ciclo de vida de un frame**
- Para cada frame se muestra el tiempo en el hilo de UI (build/layout, equivalente al Main Thread) y en el de Raster (pintado en la GPU).
- Se compara con el presupuesto de 16,7 ms por frame.

**Event Loop (Tasks vs Microtasks)**
- Una demostración ejecuta código síncrono, microtasks (`scheduleMicrotask`, `Future.microtask`) y tasks (`Timer`, `Future`).
- Muestra el orden real en que se ejecutan: Call Stack → Microtask Queue → Task Queue.

## 2. Paradigmas de comunicación y contratos de API

La app combina varios paradigmas, cada uno donde conviene:

| Paradigma | Dónde | Por qué |
|---|---|---|
| **REST** (PostgREST de Supabase) | Mascotas, zonas, contactos, salud, paseos | Recursos con GET/POST/PATCH/DELETE. Con `select=` se pide solo lo necesario (evita over-fetching) y se incluye el collar en la misma petición (evita round-trips). |
| **RPC** | `report_location` (collar GPS) y `set_device_key` | El collar llama una función remota como si fuera local. |
| **WebSocket** | Ubicaciones del collar (ver tema 5) | Tiempo real. |
| **SSE** | Resumen del día con IA (ver tema 5) | Flujo servidor → cliente. |

- **Contract-First (OpenAPI):** `backend/api/openapi.yaml` es la fuente única de verdad (SSOT) del API del collar. Quien programe el GPS (por ejemplo con Arduino) sabe exactamente qué enviar y qué recibe, sin leer el código de la app.
- **Tipado de punta a punta:** el esquema de PostgreSQL (`backend/supabase/pettracker_schema.sql`) define los tipos y restricciones (rangos de latitud, batería 0–100…). La app los convierte en clases tipadas (`Pet`, `SafeZone`, `LocationData`…).
- **Validación en tiempo de ejecución ("parsear, no solo validar"):** los datos que llegan de afuera no son confiables aunque el código tenga tipos.
  - `lib/core/validation/collar_data.dart` revisa cada ubicación del collar: rangos, fecha válida y no futura, batería, y el punto (0,0) de un GPS sin señal.
  - Lo que no sirve se descarta. Las respuestas de Gemini también se revisan antes de usarse.
- **gRPC / GraphQL / tRPC (no usados, y por qué):**
  - gRPC-Web necesita un proxy (Envoy) que Supabase no ofrece.
  - tRPC es solo para TypeScript.
  - GraphQL no aporta aquí: las consultas son simples y REST con `select=` ya evita el over-fetching.

## 3. Paralelismo real en el navegador (Workers)

**Web Worker**
- `web/workers/route_analysis_worker.js` analiza recorridos GPS en un hilo aparte: distancia, velocidad máxima, tiempo en cada zona y lugares frecuentes.
- Se comunica con la app por `postMessage`.
- **Demostración en el panel:** analizar 300.000 puntos (unos 7 meses de un collar).
  - "En el hilo principal": la app se congela y el INP empeora.
  - "Con Web Worker": la app sigue fluida.
- El mismo análisis se puede correr con los datos reales de la mascota.
- En celular el equivalente es un *Isolate* (`lib/core/workers/`).

**Service Worker**
- `web/pettracker_sw.js` es un proxy de red: guarda las calles del mapa ya vistas y los sonidos de alarma, para usarlos **sin internet**.
- A propósito no guarda los archivos de la app, para no servir versiones viejas.
- Se registra en `web/index.html`.
- Se usa un `web/flutter_bootstrap.js` propio porque el Service Worker de Flutter se desinstala a sí mismo y borraría el nuestro.

**SharedArrayBuffer y crossOriginIsolated**
- El panel muestra si están disponibles.
- No se activan: requieren las cabeceras COOP/COEP, y COEP bloquearía las imágenes de OpenStreetMap. Para este análisis basta `postMessage`.

## 4. Patrones de rendering web

- PetTracker es **CSR (Client-Side Rendering)**: el servidor envía un HTML mínimo y el navegador ejecuta la app.
- Es el patrón adecuado para una app privada con inicio de sesión (tipo dashboard o SaaS), que no necesita SEO.
- **Mitigación del punto débil de CSR (el primer pintado):** `web/index.html` trae una pantalla de carga en HTML/CSS puro. Se pinta de inmediato, mejorando el FCP, y se quita con el evento `flutter-first-frame`.
- El panel muestra **TTFB, FCP, DOMContentLoaded y carga completa**, medidos con Navigation Timing y Paint Timing.

## 5. Tiempo real en la web

**WebSockets**
- Las ubicaciones del collar llegan por **Supabase Realtime**: un WebSocket persistente y bidireccional.
- La base de datos empuja cada ubicación nueva al instante.
- Solo se publica la tabla `pettracker.location_history`, y las reglas RLS se aplican también aquí, así que cada dueño recibe solo lo suyo.
- **Código:** `lib/features/tracking/data/supabase_collar_service.dart`.

**Short Polling como respaldo**
- Si el WebSocket no está disponible, la app pregunta cada 5 s.
- Aunque el WebSocket funcione, hace una consulta de respaldo cada 30 s por si se perdió un mensaje.
- El panel muestra cuál se está usando.

**SSE (Server-Sent Events)**
- El resumen del día de la IA usa `streamGenerateContent?alt=sse` de Gemini: un flujo `text/event-stream` unidireccional.
- La app muestra el texto mientras llega, sin esperar la respuesta completa.
- **Código:** `lib/features/assistant/gemini_pet_safety_ai_service.dart`.

---

### Cómo mostrarlo en clase
1. Corre la app con `flutter run -d chrome --dart-define-from-file=secrets.json` y entra con **"Probar con la cuenta demo"**.
2. Ve a **Ajustes → Panel técnico**:
   - "Bloquear el hilo" muestra el INP empeorando.
   - "En el hilo principal" contra "Con Web Worker" muestra la diferencia entre bloquear y no bloquear.
   - "Ejecutar demostración" muestra el orden del Event Loop.
3. En **Inicio → Resumen del día → Ver resumen**, el texto aparece por partes (SSE).
4. Para ver el Service Worker: abre el **Mapa**, desconecta el internet y recarga. Las calles ya vistas siguen apareciendo.
