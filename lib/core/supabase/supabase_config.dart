class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://zcsfkltvilypjxocoojz.supabase.co');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_KEY', defaultValue: 'sb_publishable_ng-YqVkaUzj2SG0Op8VpnA_cjt3AgWm');
  static const schema = 'pettracker';

  static bool get configured => url.isNotEmpty && publishableKey.isNotEmpty;
}
