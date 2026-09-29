/// Connection details for the shared Supabase project (Phase 21/22).
///
/// The anon/publishable key is safe to ship in the client — it identifies the
/// project, not a privileged user; every table it can reach is still gated by
/// the Row Level Security policies defined in `supabase/migrations/`. Never
/// put the service-role key here.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://wwhdawwdizvpzlnytijn.supabase.co';
  static const String anonKey =
      'sb_publishable_p-07z4Vthyjw3rtRbKFlvQ_54jqXOBl';
}
