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
