
import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';

// ======================================================
// CONFIGURAÇÕES DO SUPABASE
// ======================================================

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;

const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

// Verifica se as variáveis de ambiente estão configuradas
if (!url || !key) {
  throw new Error(
    'Variáveis do Supabase ausentes. Confira o arquivo .env e reinicie com: npx expo start -c',
  );
}

// ======================================================
// CLIENTE SUPABASE
// ======================================================

export const supabase = createClient(url, key, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// ======================================================
// GERENCIAMENTO AUTOMÁTICO DA SESSÃO
// ======================================================

// Renova o token enquanto o aplicativo estiver em primeiro plano.
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    supabase.auth.startAutoRefresh();
  } else {
    supabase.auth.stopAutoRefresh();
  }
});
