import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseConfigured =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

Future<void> initializeSupabase() async {
  if (!isSupabaseConfigured) {
    debugPrint(
      'Supabase is not configured. Starting in offline mode; '
      'pass SUPABASE_URL and SUPABASE_ANON_KEY for online features.',
    );
    return;
  }

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('Supabase initialized.');
  } catch (error, stackTrace) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
