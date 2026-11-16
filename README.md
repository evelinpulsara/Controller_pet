# PetTracker — Frontend

App web para rastrear mascotas con un collar GPS. Avisa si la mascota sale de su zona segura y, si se pierde, una IA escribe el mensaje de emergencia para los contactos de WhatsApp y un cartel de "Se busca".

- **App en línea:** `https://ENLACE-DE-VERCEL`
- **Backend:** https://github.com/evelinpulsara/Pet_Backend

## Probar la app (modo demo)
En la pantalla de inicio de sesión toca **"Probar con la cuenta demo"**. Trae dos mascotas de ejemplo y un **collar GPS simulado** que se mueve solo.

1. **Inicio → "Usar mi ubicación"**: la demo aparece donde estás.
2. **Ajustes → Contactos de emergencia**: agrega un número para recibir el mensaje.
3. **Ajustes → Modo prueba → "Simular que sale de la zona"**: la mascota se aleja, suena la alarma y la IA prepara el aviso.
4. **Inicio → Enviar por WhatsApp**: el mensaje lleva un enlace de Google Maps con la ubicación del momento.
5. **Ajustes → Panel técnico**: aquí se ven en vivo los temas del curso.

Las cuentas reales empiezan vacías: nada se mueve ni suena hasta que un collar real envíe datos.

## Qué se implementó
| Parte | Qué hace |
|---|---|
| Seguimiento | Mapa en tiempo real, zonas seguras, historial de ubicaciones y recorridos |
| Alertas | Salida de zona, batería baja, collar desconectado y comportamiento inusual, con sonido |
| Asistente IA | Mensaje de emergencia, cartel de "Se busca" y resumen del día (Gemini, a través del backend) |
| Actividad y salud | Meta diaria, paseos, gráfica semanal y recordatorios de vacunas |
| Diseño adaptable | Barra inferior en celular; menú lateral y columnas en computador |
| Datos | Demo guardada en el navegador; cuentas reales en Supabase con Row Level Security |

## Temas del curso
| Tema | Dónde se ve |
|---|---|
| INP, Long Tasks y Event Loop | Panel técnico: "Bloquear el hilo" y "Ejecutar demostración" |
| Web Worker | Panel técnico: análisis de 300 000 puntos en el hilo principal y en el worker |
| Service Worker | `web/pettracker_sw.js`: mapa y sonidos disponibles sin internet |
| CSR y pantalla de carga | `web/index.html`; métricas TTFB y FCP en el panel |
| WebSocket y Short Polling | Ubicaciones del collar con Supabase Realtime y respaldo cada 5 s |
| SSE | Inicio → Resumen del día: el texto aparece mientras llega |
| REST, RPC y validación | Repositorios de Supabase y `lib/core/validation/collar_data.dart` |

Más detalle en [`docs/TEMAS_DE_CLASE.md`](docs/TEMAS_DE_CLASE.md).

## Arquitectura y patrones
```
lib/
  core/       almacenamiento, tema, rutas, rendimiento y workers
  features/   una carpeta por función (tracking, pets, alerts, assistant...)
  shared/     widgets reutilizables
```
- **Repository:** `PetRepository`, con versiones Local y Supabase.
- **Abstract Factory:** `RepositoryFactory` crea todos los repositorios de un mismo tipo.
- **Proxy:** los repositorios `Switching…` eligen entre local y nube según la cuenta.
- **Factory:** `AiServiceFactory` y `CollarServiceFactory`.
- **Strategy:** `PetSafetyAiService` y `LocationService`, con varias versiones intercambiables.
- **Observer:** `AppController` (`ChangeNotifier`) actualiza las pantallas.

## Correr en local
```
flutter pub get
flutter run -d chrome --dart-define-from-file=secrets.json
```
`secrets.json` no se sube al repositorio. Se despliega en **Vercel** con `vercel-build.sh` y la variable `BACKEND_URL`.
