/// Conexión a Supabase (proyecto compartido; PetTracker usa el esquema `pettracker`).
///
/// La URL y la clave PÚBLICA (publishable) son seguras en la app: los datos
/// están protegidos con Row Level Security. NUNCA pongas aquí la clave secreta
/// (sb_secret_...) ni la contraseña de la base de datos.
///
/// Se pueden cambiar sin tocar el código con secrets.json:
///   {"SUPABASE_URL": "...", "SUPABASE_KEY": "sb_publishable_..."}
