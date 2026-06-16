import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://smvegrscjnoelfsipwqq.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNtdmVncnNjam5vZWxmc2lwd3FxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNTU5MjcsImV4cCI6MjA4ODczMTkyN30.z6h0ubNjAC0QfdGgg3FhAfSCy9RVVCupOuQUKuD98ig',
  );
  
  try {
    final res = await supabase.from('user_fcm_tokens').select('id, user_id, app_type, platform, updated_at');
    print('FCM Tokens in DB:');
    print(res);
  } catch (e) {
    print('Error: $e');
  }
}
