import 'package:flutter/material.dart';
import '../../../core/constants/app_localizations.dart';
import '../../../core/perf/perf_monitor.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/workers/route_worker.dart';
import '../../../shared/widgets/widgets.dart';
import '../../tracking/data/supabase_collar_service.dart';
import '../../tracking/presentation/app_controller.dart';

class TechPanelScreen extends StatefulWidget {
  const TechPanelScreen({super.key});
  @override
  State<TechPanelScreen> createState() => _TechPanelScreenState();
}

class _TechPanelScreenState extends State<TechPanelScreen> {
  final perf = PerfMonitor.instance;
  List<String>? _eventLoop;
  RouteAnalysis? _mainResult, _workerResult, _realResult;
  bool _runningMain = false, _runningWorker = false, _runningReal = false;
  ServiceWorkerInfo? _sw;

  static const _demoPoints = 300000;

  @override
  void initState() {
    super.initState();
    perf.start();
    perf.serviceWorkerInfo().then((v) => mounted ? setState(() => _sw = v) : null);
  }

  Future<void> _runAnalysis(bool inWorker) async {
    final c = AppScope.of(context);
    setState(() => inWorker ? _runningWorker = true : _runningMain = true);
    await Future.delayed(const Duration(milliseconds: 50));
    final zones = [for (final z in c.zones) <Object>[z.latitude, z.longitude, z.radius, z.name]];
    final r = await analyzeRoute(points: const [], zones: zones, synthetic: _demoPoints, inWorker: inWorker);
    if (!mounted) return;
    setState(() {
      if (inWorker) {
        _workerResult = r;
        _runningWorker = false;
      } else {
        _mainResult = r;
        _runningMain = false;
      }
    });
  }

  Future<void> _analyzeReal() async {
    final c = AppScope.of(context);
    setState(() => _runningReal = true);
    final pts = <List<double>>[
      for (final h in c.history.reversed)
        [h.location.latitude, h.location.longitude, h.location.timestamp.millisecondsSinceEpoch.toDouble()],
    ];
    final zones = [for (final z in c.zones) <Object>[z.latitude, z.longitude, z.radius, z.name]];
    final r = await analyzeRoute(points: pts, zones: zones, inWorker: true);
    if (!mounted) return;
    setState(() {
      _realResult = r;
      _runningReal = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = AppL10n.fromLocale(c.locale);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('Panel técnico', 'Tech panel'))),
      body: AnimatedBuilder(
        animation: perf,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          Text(
            l.t('Aquí puedes ver, funcionando en vivo, las técnicas web que usa PetTracker.',
                'Here you can see, live, the web techniques PetTracker uses.'),
            style: context.text.bodyMedium?.copyWith(color: context.colors.muted),
          ),
          const SizedBox(height: 14),
          _inpCard(l),
          _framesCard(l),
          _eventLoopCard(l),
          _workerCard(l, c),
          _realtimeCard(l, c),
          _serviceWorkerCard(l),
          _renderingCard(l),
          _apiCard(l),
        ]),
      ),
    );
  }

  Widget _inpCard(AppL10n l) {
    final s = perf.inpSample;
    final inp = perf.inp;
    final rating = PerfMonitor.rating(inp);
    final color = switch (rating) { 'good' => AppTheme.ok, 'needs' => AppTheme.warning, 'poor' => AppTheme.danger, _ => context.colors.muted };
    final label = switch (rating) {
      'good' => l.t('Bueno (≤ 200 ms)', 'Good (≤ 200 ms)'),
      'needs' => l.t('Necesita mejora (200–500 ms)', 'Needs improvement (200–500 ms)'),
      'poor' => l.t('Pobre (> 500 ms)', 'Poor (> 500 ms)'),
      _ => l.t('Toca botones de la app para medir', 'Tap buttons in the app to measure'),
    };
    return _Section(
      icon: Icons.speed_rounded,
      title: 'INP · Interaction to Next Paint',
      children: [
        if (!perf.isWeb)
          Text(l.t('El INP se mide en la versión web (en el navegador).', 'INP is measured in the web version (browser).'),
              style: context.text.bodySmall),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(inp == null ? '—' : '${inp.round()} ms', style: context.text.displaySmall?.copyWith(color: color)),
          const SizedBox(width: 10),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: StatusChip(label: label, icon: Icons.circle, color: color),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          l.t('${perf.interactions.length} interacciones medidas · tareas largas: ${perf.longTasks} (máx. ${perf.longestTaskMs.round()} ms)',
              '${perf.interactions.length} interactions measured · long tasks: ${perf.longTasks} (max ${perf.longestTaskMs.round()} ms)'),
          style: context.text.bodySmall,
        ),
        if (s != null) ...[
          const SizedBox(height: 12),
          Text(l.t('Peor interacción ("${s.type}") = Input Delay + Processing + Presentation Delay',
                  'Worst interaction ("${s.type}") = Input Delay + Processing + Presentation Delay'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _BreakdownBar(parts: [
            (l.t('Retardo de entrada', 'Input delay'), s.inputDelay, AppTheme.warning),
            (l.t('Procesamiento', 'Processing'), s.processing, context.accent),
            (l.t('Presentación', 'Presentation'), s.presentation, const Color(0xFF2F80ED)),
          ]),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.hourglass_bottom_rounded, size: 18),
            label: Text(l.t('Bloquear el hilo 600 ms', 'Block the thread 600 ms')),
            onPressed: () => perf.blockMainThread(600),
          ),
          TextButton(onPressed: perf.reset, child: Text(l.t('Reiniciar medición', 'Reset'))),
        ]),
        Text(
          l.t('Prueba: toca "Bloquear el hilo" y verás cómo el INP pasa a "Pobre": mientras el hilo principal está ocupado, la app no puede responder ni pintar.',
              'Try it: tap "Block the thread" and INP becomes "Poor": while the main thread is busy the app cannot respond or paint.'),
          style: context.text.bodySmall,
        ),
      ],
    );
  }

  Widget _framesCard(AppL10n l) {
    String ms(double v) => '${v.toStringAsFixed(1)} ms';
    return _Section(
      icon: Icons.layers_rounded,
      title: l.t('Ciclo de vida de un frame', 'Frame lifecycle'),
      children: [
        Text(
          l.t('Cada frame pasa por el hilo de UI (build y layout, como el Main Thread del navegador) y luego por el de Raster '
              '(pintado y composición en la GPU). Para 60 fps, cada frame debe tardar menos de 16,7 ms.',
              'Each frame goes through the UI thread (build/layout, like the browser Main Thread) and then Raster '
                  '(paint and compositing on the GPU). For 60 fps each frame must take under 16.7 ms.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 10),
        InfoRow(icon: Icons.code_rounded, label: l.t('Hilo de UI (promedio / peor)', 'UI thread (avg / worst)'), value: '${ms(perf.uiAvg)} / ${ms(perf.uiMax)}'),
        InfoRow(icon: Icons.brush_rounded, label: l.t('Raster / GPU (promedio / peor)', 'Raster / GPU (avg / worst)'), value: '${ms(perf.rasterAvg)} / ${ms(perf.rasterMax)}'),
        InfoRow(icon: Icons.movie_rounded, label: l.t('Frames medidos', 'Frames measured'), value: '${perf.framesMeasured}'),
        if (perf.framesMeasured == 0)
          Text(l.t('Navega o desplázate por la app y vuelve aquí para ver las mediciones.', 'Move around the app and come back to see measurements.'),
              style: context.text.bodySmall),
      ],
    );
  }

  Widget _eventLoopCard(AppL10n l) => _Section(
        icon: Icons.loop_rounded,
        title: 'Event Loop: Tasks vs Microtasks',
        children: [
          Text(
            l.t('El código se agenda en este orden y se ejecuta así: primero lo síncrono (Call Stack), luego TODAS las microtasks y después las tasks.',
                'Code is scheduled in this order and runs like this: synchronous code first (Call Stack), then ALL microtasks, then tasks.'),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l.t('Ejecutar demostración', 'Run demo')),
            onPressed: () async {
              final r = await eventLoopDemo(l.isEs);
              if (mounted) setState(() => _eventLoop = r);
            },
          ),
          if (_eventLoop != null)
            for (var i = 0; i < _eventLoop!.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  CircleAvatar(radius: 11, backgroundColor: context.accent.withValues(alpha: 0.15),
                      child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: context.accent, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_eventLoop![i], style: context.text.bodySmall?.copyWith(color: context.colors.ink))),
                ]),
              ),
        ],
      );

  Widget _workerCard(AppL10n l, AppController c) {
    Widget result(RouteAnalysis? r, bool running, String who) {
      if (running) {
        return Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 10),
          Expanded(child: Text(l.t('Analizando en $who...', 'Analyzing in $who...'))),
        ]);
      }
      if (r == null) return const SizedBox.shrink();
      return Text(
        l.t('$who: ${r.elapsedMs.round()} ms · ${(r.distanceM / 1000).toStringAsFixed(0)} km · ${r.insidePct.round()} % del tiempo en zona',
            '$who: ${r.elapsedMs.round()} ms · ${(r.distanceM / 1000).toStringAsFixed(0)} km · ${r.insidePct.round()} % of time in zone'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
    }

    return _Section(
      icon: Icons.memory_rounded,
      title: 'Web Workers',
      children: [
        Text(
          l.t('Analizar 300.000 puntos GPS (unos 7 meses del collar) es pesado. En el hilo principal la app se congela: '
              'la ruedita de carga se detiene y el INP empeora. En un Web Worker el cálculo va en otro hilo y la app sigue fluida. '
              'Se comunican por postMessage.',
              'Analyzing 300,000 GPS points (~7 months of collar data) is heavy. On the main thread the app freezes: '
                  'the spinner stops and INP gets worse. In a Web Worker it runs on another thread and the app stays smooth. '
                  'They talk via postMessage.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.warning_amber_rounded, size: 18),
            label: Text(l.t('En el hilo principal', 'On the main thread')),
            onPressed: _runningMain || _runningWorker ? null : () => _runAnalysis(false),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text(l.t('Con Web Worker', 'With Web Worker')),
            onPressed: _runningMain || _runningWorker ? null : () => _runAnalysis(true),
          ),
        ]),
        const SizedBox(height: 10),
        result(_mainResult, _runningMain, l.t('hilo principal', 'main thread')),
        const SizedBox(height: 4),
        result(_workerResult, _runningWorker, perf.isWeb ? 'Web Worker' : 'Isolate'),
        const Divider(height: 28),
        Text(l.t('Con los datos reales de ${c.selectedPet?.name ?? ''}', "With ${c.selectedPet?.name ?? ''}'s real data"),
            style: context.text.titleMedium),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          icon: const Icon(Icons.route_rounded, size: 18),
          label: Text(l.t('Analizar su recorrido (${c.history.length} puntos)', 'Analyze route (${c.history.length} points)')),
          onPressed: _runningReal || c.history.length < 2 ? null : _analyzeReal,
        ),
        if (_runningReal) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (_realResult != null) ...[
          const SizedBox(height: 8),
          InfoRow(icon: Icons.straighten_rounded, label: l.t('Distancia', 'Distance'), value: Fmt.distance(_realResult!.distanceM, c.metric)),
          InfoRow(icon: Icons.speed_rounded, label: l.t('Velocidad máxima', 'Top speed'), value: '${_realResult!.maxSpeedKmh.toStringAsFixed(1)} km/h'),
          InfoRow(icon: Icons.shield_rounded, label: l.t('Tiempo dentro de sus zonas', 'Time inside zones'), value: '${_realResult!.insidePct.round()} %'),
          for (final e in _realResult!.zoneMs.entries)
            InfoRow(icon: Icons.place_outlined, label: e.key, value: fmtDuration(Duration(milliseconds: e.value.round()))),
          Text(l.t('Calculado en ${_realResult!.elapsedMs.toStringAsFixed(1)} ms (${_realResult!.thread})',
                  'Computed in ${_realResult!.elapsedMs.toStringAsFixed(1)} ms (${_realResult!.thread})'),
              style: context.text.bodySmall),
        ],
        const Divider(height: 28),
        InfoRow(
          icon: Icons.lock_outline_rounded,
          label: 'crossOriginIsolated',
          value: perf.crossOriginIsolated ? l.t('Sí', 'Yes') : l.t('No', 'No'),
        ),
        InfoRow(
          icon: Icons.memory_outlined,
          label: 'SharedArrayBuffer',
          value: perf.sharedArrayBufferAvailable ? l.t('Disponible', 'Available') : l.t('No disponible', 'Not available'),
        ),
        Text(
          l.t('SharedArrayBuffer (memoria compartida con Atomics) exige crossOriginIsolated (cabeceras COOP/COEP). '
              'No lo activamos: COEP bloquearía las imágenes del mapa de OpenStreetMap. Para este análisis basta postMessage.',
              'SharedArrayBuffer (shared memory with Atomics) requires crossOriginIsolated (COOP/COEP headers). '
                  "We don't enable it: COEP would block OpenStreetMap tiles. postMessage is enough for this analysis."),
          style: context.text.bodySmall,
        ),
      ],
    );
  }

  Widget _realtimeCard(AppL10n l, AppController c) {
    final svc = c.session?.service;
    Widget transport;
    if (c.isDemo || c.session?.mock != null) {
      transport = StatusChip(label: l.t('Collar simulado (cuenta demo)', 'Simulated collar (demo)'), icon: Icons.science_outlined, color: AppTheme.warning);
    } else if (svc is SupabaseCollarService) {
      transport = ValueListenableBuilder(
        valueListenable: svc.transport,
        builder: (_, t, _) => switch (t) {
          CollarTransport.websocket => StatusChip(label: 'WebSocket (Supabase Realtime)', icon: Icons.bolt_rounded, color: AppTheme.ok),
          CollarTransport.polling => StatusChip(label: l.t('Short polling (cada 5 s)', 'Short polling (every 5 s)'), icon: Icons.sync_rounded, color: AppTheme.warning),
          CollarTransport.connecting => StatusChip(label: l.t('Conectando...', 'Connecting...'), icon: Icons.hourglass_top_rounded, color: context.colors.muted),
        },
      );
    } else {
      transport = StatusChip(label: l.t('Sin conexión a la nube', 'Not connected to the cloud'), icon: Icons.cloud_off_rounded, color: context.colors.muted);
    }
    return _Section(
      icon: Icons.sensors_rounded,
      title: l.t('Tiempo real', 'Real time'),
      children: [
        Text(l.t('Ubicaciones del collar', 'Collar locations'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        transport,
        const SizedBox(height: 8),
        Text(
          l.t('WebSocket: conexión persistente y bidireccional; la base de datos avisa al instante cuando el collar envía una ubicación. '
              'Si el WebSocket falla, la app pasa a Short Polling (pregunta cada pocos segundos) para no perder datos.',
              'WebSocket: persistent, bidirectional connection; the database pushes each new collar location instantly. '
                  'If it fails, the app falls back to Short Polling (asks every few seconds) so no data is lost.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(l.t('Resumen del día con IA', 'AI daily summary'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        StatusChip(label: 'SSE · text/event-stream', icon: Icons.stream_rounded, color: context.accent),
        const SizedBox(height: 8),
        Text(
          l.t('Server-Sent Events: el servidor de Gemini envía el texto en pedacitos por una conexión HTTP abierta (solo del servidor a la app), '
              'y la app lo muestra mientras se escribe. Pruébalo en Inicio → "Resumen del día".',
              'Server-Sent Events: Gemini streams the text in chunks over an open HTTP connection (server → app only), '
                  'and the app shows it while it is written. Try it in Home → "Daily summary".'),
          style: context.text.bodySmall,
        ),
      ],
    );
  }

  Widget _serviceWorkerCard(AppL10n l) {
    final sw = _sw;
    return _Section(
      icon: Icons.cloud_sync_rounded,
      title: 'Service Worker',
      children: [
        Text(
          l.t('Funciona como un proxy de red: guarda las calles del mapa que ya viste y los sonidos de alarma, '
              'para que el mapa se vea aunque no tengas internet. No guarda la app en sí, así siempre cargas la versión más nueva.',
              'Acts as a network proxy: caches map tiles you already saw and the alarm sounds, so the map works offline. '
                  'It does not cache the app itself, so you always load the newest version.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 8),
        InfoRow(
          icon: Icons.verified_user_outlined,
          label: l.t('Estado', 'Status'),
          value: sw == null
              ? '...'
              : !sw.supported
                  ? l.t('No disponible aquí', 'Not available here')
                  : sw.active
                      ? l.t('Activo', 'Active')
                      : l.t('Registrado (activo al recargar)', 'Registered (active after reload)'),
        ),
        InfoRow(icon: Icons.map_outlined, label: l.t('Calles del mapa guardadas', 'Map tiles cached'), value: '${sw?.cachedTiles ?? 0}'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.t('Actualizar', 'Refresh')),
            onPressed: () => perf.serviceWorkerInfo().then((v) => mounted ? setState(() => _sw = v) : null),
          ),
        ),
      ],
    );
  }

  Widget _renderingCard(AppL10n l) {
    final t = perf.loadTimings;
    String ms(double? v) => v == null || v <= 0 ? '—' : '${v.round()} ms';
    return _Section(
      icon: Icons.web_rounded,
      title: l.t('Patrón de rendering: CSR', 'Rendering pattern: CSR'),
      children: [
        Text(
          l.t('PetTracker es Client-Side Rendering: el servidor envía un HTML mínimo y el navegador descarga y ejecuta la app. '
              'Es lo adecuado para una app privada con inicio de sesión (no necesita SEO). Su punto débil es el primer pintado, '
              'por eso el HTML trae una pantalla de carga que se pinta al instante y se quita cuando Flutter dibuja su primer frame.',
              'PetTracker uses Client-Side Rendering: the server sends minimal HTML and the browser downloads and runs the app. '
                  "It fits a private, logged-in app (no SEO needed). Its weak spot is first paint, so the HTML ships a splash that paints instantly "
                  'and is removed when Flutter draws its first frame.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 8),
        InfoRow(icon: Icons.dns_outlined, label: 'TTFB (Time To First Byte)', value: ms(t?.ttfb)),
        InfoRow(icon: Icons.format_paint_outlined, label: 'FCP (First Contentful Paint)', value: ms(t?.fcp)),
        InfoRow(icon: Icons.article_outlined, label: 'DOMContentLoaded', value: ms(t?.domContentLoaded)),
        InfoRow(icon: Icons.check_circle_outline_rounded, label: l.t('Carga completa', 'Full load'), value: ms(t?.load)),
      ],
    );
  }

  Widget _apiCard(AppL10n l) => _Section(
        icon: Icons.hub_rounded,
        title: l.t('Comunicación y contratos de API', 'Communication & API contracts'),
        children: [
          for (final (name, what) in [
            ('REST (PostgREST)', l.t('Mascotas, zonas, contactos, salud... (recursos con GET/POST/PATCH/DELETE)', 'Pets, zones, contacts, health... (resources via GET/POST/PATCH/DELETE)')),
            ('RPC', l.t('report_location: el collar llama una función remota como si fuera local', 'report_location: the collar calls a remote function as if local')),
            ('WebSocket', l.t('Ubicaciones del collar en tiempo real', 'Real-time collar locations')),
            ('SSE', l.t('Resumen del día con IA, palabra por palabra', 'AI daily summary, word by word')),
            ('OpenAPI', l.t('Contrato del API del collar: backend/api/openapi.yaml (Contract-First)', 'Collar API contract: backend/api/openapi.yaml (Contract-First)')),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 110, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(child: Text(what, style: context.text.bodySmall)),
              ]),
            ),
          Text(
            l.t('Validación en tiempo de ejecución: las ubicaciones que llegan del collar se revisan (rangos, fecha, batería) antes de usarlas; '
                'las inválidas se descartan.',
                'Runtime validation: collar locations are checked (ranges, date, battery) before use; invalid ones are dropped.'),
            style: context.text.bodySmall,
          ),
        ],
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: context.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: context.text.titleMedium)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({required this.parts});
  final List<(String, double, Color)> parts;
  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (t, p) => t + p.$2);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: Row(children: [
            for (final p in parts)
              if (p.$2 > 0) Expanded(flex: (p.$2 * 10).round().clamp(1, 1 << 30), child: Container(color: p.$3)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final p in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${p.$1}: ${p.$2.round()} ms', style: context.text.bodySmall),
          ]),
      ]),
      if (total > 0) const SizedBox(height: 2),
    ]);
  }
}
