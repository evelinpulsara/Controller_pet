{{flutter_js}}
{{flutter_build_config}}

// Arranque personalizado de Flutter.
// No se registra el Service Worker de Flutter (en esta versión solo se
// desinstala a sí mismo y borraría el de PetTracker, web/pettracker_sw.js).
_flutter.loader.load();
