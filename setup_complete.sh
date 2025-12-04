#!/usr/bin/env bash
set -euo pipefail

# setup_complete.sh
# Script completo per generare progetto Next.js + PWA + Supabase partendo da un file SQL schema.
# Funziona bene in GitHub Codespaces (terminale).
# ATTENZIONE: cancella TUTTO il contenuto del repo tranne lo script stesso e lo schema SQL che indicherai.

echo "==============================================="
echo " CAREAUTOPRO - SETUP COMPLETO (Next.js + Supabase)"
echo "==============================================="
echo ""
echo "ATTENZIONE: questo script cancellerà tutti i file e le cartelle"
echo "della repository ad eccezione di questo script e del file SQL dello schema"
echo "che indicherai. Procedi solo se sei sicuro."
echo ""

read -p "Confermi di proseguire e cancellare il contenuto del repo (si/no)? " confirm
if [[ "$confirm" != "si" && "$confirm" != "s" ]]; then
  echo "Operazione annullata dall'utente."
  exit 0
fi

# RICHIESTE INPUT
read -p "Percorso relativo al file SQL dello schema (es: ./schema.sql): " SQL_PATH
if [[ ! -f "$SQL_PATH" ]]; then
  echo "File non trovato: $SQL_PATH"
  exit 1
fi

read -p "Nome progetto (cartella) da creare (es: careautopro): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-careautopro}

echo ""
echo "Vuoi che lo script crei anche il repo GitHub e faccia push automatico? (richiede GitHub CLI o PAT) (si/no)"
read -r CREATE_GH
if [[ "$CREATE_GH" == "si" || "$CREATE_GH" == "s" ]]; then
  echo "Opzione: crea repo GitHub abilitata."
  echo "Preferisci usare gh cli (consigliato) o GitHub PAT? (gh/pat)"
  read -r GH_METHOD
  if [[ "$GH_METHOD" == "pat" ]]; then
    read -p "Inserisci GitHub username (es: tuo-username): " GH_USER
    read -sp "Inserisci GitHub PAT (non sarà salvato): " GH_PAT
    echo ""
  fi
fi

echo ""
echo "Vuoi che lo script esegua 'supabase db push' automaticamente (richiede supabase CLI e login)? (si/no)"
read -r RUN_SUPABASE_PUSH

echo ""
echo "Vuoi configurare e costruire anche Capacitor per Android (scaffold)? (si/no)"
read -r USE_CAPACITOR

echo ""
echo "Vuoi generare le viste AppSheet-like (Deck, Table, Detail, Form, Related)? (si/no)"
read -r GEN_VIEWS

echo ""
echo "OK — procedo con la generazione. Questo può richiedere qualche minuto."

# SALVATAGGIO NOME ASSOLUTO DELLO SCRIPT E FILE SQL
SCRIPT_NAME=$(basename "$0")
KEEP_FILES=("$SCRIPT_NAME" "$SQL_PATH")

# Pulizia: rimuove tutto tranne lo script e il file SQL indicato
echo "-> Pulizia repository (salvo lo script e lo schema SQL)..."
shopt -s extglob
# Lista dei nomi da preservare (solo basenames)
preserve=()
for p in "${KEEP_FILES[@]}"; do preserve+=("$(basename "$p")"); done

for entry in .* *; do
  # skip . and ..
  [[ "$entry" == "." || "$entry" == ".." ]] && continue
  # skip the script itself and the schema file
  skip=false
  for k in "${preserve[@]}"; do
    if [[ "$entry" == "$k" ]]; then skip=true; break; fi
  done
  if [[ "$skip" == true ]]; then
    # preserve
    continue
  fi
  rm -rf -- "$entry" || true
done
shopt -u extglob

# Create base project folder (we'll reuse current dir)
echo "-> Cartella pulita. Genero scaffold progetto in $(pwd)"

# Inizializza package.json se non presente
if [[ ! -f package.json ]]; then
  echo "-> Inizializzo package.json..."
  npm init -y >/dev/null 2>&1 || { echo "npm init fallito"; exit 1; }
fi

# Installa dipendenze principali
echo "-> Installazione dipendenze (next, react, tailwind, supabase-js, capacitor optional)..."
npm install next react react-dom @supabase/supabase-js swr classnames zustand || true
npm install -D tailwindcss postcss autoprefixer eslint prettier || true
npx tailwindcss init -p >/dev/null 2>&1 || true

# Crea struttura cartelle
mkdir -p app components lib public styles supabase/migrations supabase/policies supabase/functions scripts

# Copia lo schema SQL come prima migration
MIGRATION_FILE="supabase/migrations/001_schema.sql"
echo "-> Copio lo schema SQL in $MIGRATION_FILE"
cp "$SQL_PATH" "$MIGRATION_FILE"

# Estrai i nomi delle tabelle CREATE TABLE public.* o CREATE TABLE *; (semplice parsing)
echo "-> Estrazione nomi tabelle dallo schema (per generare RLS di base)..."
TABLES=()
while read -r line; do
  # rileva CREATE TABLE [IF NOT EXISTS] [schema.]nome
  if [[ $line =~ CREATE[[:space:]]+TABLE ]]; then
    # estrai il token dopo TABLE (si toglie eventuale schema)
    token=$(echo "$line" | sed -E 's/CREATE[[:space:]]+TABLE[[:space:]]+IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+//I' | sed -E 's/CREATE[[:space:]]+TABLE[[:space:]]+//I' | awk '{print $1}')
    # rimuovi eventuale schema prefix "public."
    token=${token#public.}
    # rimuovi parentesi se rimasta
    token=${token/(/}
    # rimuovi eventuali virgolette
    token=${token//\"/}
    TABLES+=("$token")
  fi
done < <(tr '\r' '\n' < "$MIGRATION_FILE")

# Unici
unique_tables=()
for t in "${TABLES[@]}"; do
  if [[ -n "$t" ]]; then
    skip=false
    for ut in "${unique_tables[@]}"; do [[ "$ut" == "$t" ]] && skip=true; done
    $([[ "$skip" == false ]] && unique_tables+=("$t") || true)
  fi
done

echo "-> Tabelle trovate: ${unique_tables[*]:-nessuna}"

# Genera file policy RLS di esempio
RLS_FILE="supabase/policies/rls_examples.sql"
echo "-> Generazione file RLS di esempio in $RLS_FILE"
cat > "$RLS_FILE" <<'SQL'
-- Esempi di policy di base (ADATTARE manualmente se necessario)
-- Abilitare RLS per ogni tabella sensibile e definire policy adeguate.
SQL

for t in "${unique_tables[@]}"; do
  cat >> "$RLS_FILE" <<SQL

-- Abilita RLS per $t
ALTER TABLE public.$t ENABLE ROW LEVEL SECURITY;

-- Policy di selezione e inserimento per proprietario (assumendo colonna user_id/utente_id)
CREATE POLICY "${t}_select_own" ON public.$t
  FOR SELECT USING (auth.uid() = coalesce(user_id, utente_id, id));

CREATE POLICY "${t}_insert_own" ON public.$t
  FOR INSERT WITH CHECK (auth.uid() = coalesce(user_id, utente_id, id));

SQL
done

# Genera RPC di esempio (incrementa_km) se esiste tabella veicoli o vehicles
echo "-> Generazione RPC di esempio (se applicabile)..."
if printf "%s\n" "${unique_tables[@]}" | grep -qiE '(^|[[:space:]]|_)veicoli($|[[:space:]]|_)|(^|[[:space:]]|_)vehicles($|[[:space:]]|_)'; then
  cat > supabase/migrations/002_functions_incrementa_km.sql <<'SQL'
-- Funzione di esempio: incrementa km per veicolo
create or replace function public.incrementa_km(vehicle_uuid uuid, km numeric)
returns void language plpgsql as $$
begin
  update public.veicoli
    set kmdagps = coalesce(kmdagps,0) + km,
        kmdagpsdataorainserimento = now()
  where veicolo_id = vehicle_uuid;
end;
$$;
SQL
  echo "-> RPC incrementa_km generata: supabase/migrations/002_functions_incrementa_km.sql"
fi

# Genera .env.example
cat > .env.example <<EOF
# Variabili d'ambiente (aggiungi i valori in .env.local o in Vercel)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
EOF

# Genera supabase client (lib/supabaseClient.js)
cat > lib/supabaseClient.js <<'JS'
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);
JS

# Genera PWA manifest e service worker di base
cat > public/manifest.json <<'JSON'
{
  "name": "CareAutoPro",
  "short_name": "CareAuto",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0d6efd",
  "icons": []
}
JSON

cat > public/service-worker.js <<'JS'
self.addEventListener('install', function(event) {
  event.waitUntil(caches.open('careauto-cache-v1').then(function(cache) {
    return cache.addAll(['/']);
  }));
});
self.addEventListener('fetch', function(event) {
  event.respondWith(caches.match(event.request).then(function(resp) {
    return resp || fetch(event.request);
  }));
});
JS

# Genera layout base app/page e componenti AppSheet-like se richiesto
mkdir -p app/veicoli components

cat > app/page.jsx <<'JS'
export default function Home() {
  return (
    <main style={{ padding: 16 }}>
      <h1 style={{ fontSize: 28 }}>CareAutoPro</h1>
      <p>Progetto generato automaticamente. Modifica i file in /app e /components.</p>
    </main>
  );
}
JS

# Se richiesto, crea viste AppSheet-like
if [[ "$GEN_VIEWS" == "si" || "$GEN_VIEWS" == "s" ]]; then
  echo "-> Generazione viste AppSheet-like in /app/veicoli e /components..."
  cat > components/DeckView.jsx <<'JS'
'use client'
export default function DeckView({items, onOpen}) {
  return (
    <div style={{display:'grid',gap:8}}>
      {items?.map(i => (
        <div key={i.veicolo_id} style={{padding:12,background:'#fff',borderRadius:6,boxShadow:'0 1px 3px rgba(0,0,0,0.08)'}}>
          <div style={{display:'flex',justifyContent:'space-between'}}>
            <div>
              <strong>{i.nomeveicolo}</strong>
              <div style={{fontSize:12,color:'#666'}}>Targa: {i.targa}</div>
            </div>
            <button onClick={()=>onOpen(i)}>Apri</button>
          </div>
        </div>
      ))}
    </div>
  );
}
JS

  cat > components/TableView.jsx <<'JS'
'use client'
export default function TableView({items, onOpen}) {
  return (
    <table style={{width:'100%',borderCollapse:'collapse',background:'#fff'}}>
      <thead><tr><th>Nome</th><th>Targa</th><th>Km</th><th></th></tr></thead>
      <tbody>
      {items?.map(i => (
        <tr key={i.veicolo_id}>
          <td>{i.nomeveicolo}</td>
          <td>{i.targa}</td>
          <td>{i.kmattuali ?? '--'}</td>
          <td><button onClick={()=>onOpen(i)}>Dettagli</button></td>
        </tr>
      ))}
      </tbody>
    </table>
  );
}
JS

  cat > components/DetailView.jsx <<'JS'
'use client'
export default function DetailView({item}) {
  if(!item) return <div>Seleziona un veicolo</div>
  return (
    <div style={{padding:12,background:'#fff',borderRadius:6}}>
      <h3>{item.nomeveicolo}</h3>
      <div>Targa: {item.targa}</div>
      <div>Km attuali: {item.kmattuali ?? '--'}</div>
    </div>
  );
}
JS

  cat > components/FormView.jsx <<'JS'
'use client'
import {useState} from 'react'
export default function FormView({onSave, initial}) {
  const [nome, setNome] = useState(initial?.nomeveicolo ?? '')
  const [targa, setTarga] = useState(initial?.targa ?? '')
  return (
    <form onSubmit={e => { e.preventDefault(); onSave({nomeveicolo:nome,targa}); }}>
      <input value={nome} onChange={e=>setNome(e.target.value)} placeholder="Nome veicolo" />
      <input value={targa} onChange={e=>setTarga(e.target.value)} placeholder="Targa" />
      <button type="submit">Salva</button>
    </form>
  );
}
JS

  cat > app/veicoli/page.jsx <<'JS'
'use client'
import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabaseClient';
import DeckView from '../../components/DeckView';
import TableView from '../../components/TableView';
import DetailView from '../../components/DetailView';
import FormView from '../../components/FormView';

export default function VeicoliPage(){
  const [items,setItems] = useState([]);
  const [selected,setSelected] = useState(null);
  const [mode,setMode] = useState('deck');

  useEffect(()=>{
    (async()=>{
      try {
        const { data } = await supabase.from('veicoli').select('*');
        setItems(data || []);
      } catch(e){ console.error(e); }
    })();
  },[]);

  const onSave = async (v) => {
    await supabase.from('veicoli').insert([{ nomeveicolo: v.nomeveicolo, targa: v.targa }]);
    const { data } = await supabase.from('veicoli').select('*');
    setItems(data || []);
  };

  return (
    <div style={{padding:16}}>
      <div style={{marginBottom:8}}>
        <button onClick={()=>setMode('deck')}>Deck</button>
        <button onClick={()=>setMode('table')}>Table</button>
        <button onClick={()=>setMode('form')}>Aggiungi</button>
      </div>

      {mode==='deck' && <DeckView items={items} onOpen={setSelected} />}
      {mode==='table' && <TableView items={items} onOpen={setSelected} />}
      {mode==='form' && <FormView onSave={onSave} />}

      <div style={{marginTop:12}}>
        <DetailView item={selected} />
      </div>
    </div>
  );
}
JS

fi

# Capacitor scaffold (opzionale)
if [[ "$USE_CAPACITOR" == "si" || "$USE_CAPACITOR" == "s" ]]; then
  echo "-> Scaffold Capacitor (in sola creazione files di configurazione)..."
  npm install @capacitor/core @capacitor/cli @capacitor/android @capacitor/ios --save-dev || true
  npx cap init CareAutoPro com.careautopro.app --web-dir=out >/dev/null 2>&1 || true
  echo "-> Capacitor: file di base creati (eseguire npx cap add android/ios localmente se desideri build native)."
fi

# Inizializza git e primo commit
echo "-> Inizializzo git e faccio primo commit..."
git init >/dev/null 2>&1 || true
git add .
git commit -m "Scaffold autom. CareAutoPro from schema $SQL_PATH" || true

# Creazione repo GitHub (opzionale)
if [[ "${CREATE_GH:-no}" == "si" || "${CREATE_GH:-no}" == "s" ]]; then
  if command -v gh >/dev/null 2>&1; then
    echo "-> Creazione repo su GitHub tramite gh cli..."
    gh repo create "$PROJECT_NAME" --public --source=. --push || echo "gh repo create fallito"
  elif [[ "${GH_METHOD:-}" == "pat" && -n "${GH_PAT:-}" ]]; then
    echo "-> Creazione repo su GitHub via API con PAT..."
    curl -H "Authorization: token $GH_PAT" -H "Accept: application/vnd.github+json" \
      https://api.github.com/user/repos -d "{\"name\":\"$PROJECT_NAME\"}" || true
    git remote add origin "https://github.com/${GH_USER}/${PROJECT_NAME}.git" || true
    git branch -M main || true
    git push -u origin main || true
  else
    echo "-> Creazione repo GitHub saltata (gh non installato e PAT non fornito)."
  fi
fi

# Esegui supabase db push se richiesto e supabase CLI è disponibile
if [[ "$RUN_SUPABASE_PUSH" == "si" || "$RUN_SUPABASE_PUSH" == "s" ]]; then
  if command -v supabase >/dev/null 2>&1; then
    echo "-> Eseguo 'supabase db push' (richiede che SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY siano impostati in env)..."
    supabase db push || echo "supabase db push fallito (verifica credenziali/CLI)."
  else
    echo "-> SUPABASE CLI non trovata. Salta 'db push'."
  fi
fi

echo ""
echo "=================================="
echo "OPERAZIONE COMPLETATA"
echo "Cartella progetto: $(pwd)"
echo "- Migration copiata in: $MIGRATION_FILE"
echo "- Policies di esempio in: $RLS_FILE"
echo "- Client Supabase in: lib/supabaseClient.js"
echo "- Viste (se generate) in: app/veicoli e components/"
echo ""
echo "Prossimi passi consigliati:"
echo "1) Imposta variabili d'ambiente (.env.local o Vercel/GitHub secrets): NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY"
echo "2) Controlla ed eventualmente adatta le policy in supabase/policies/rls_examples.sql"
echo "3) Esegui localmente: npm install && npm run dev"
echo "4) (Opzionale) supabase db push --schema-only (se usi supabase CLI)"
echo ""
echo "Se vuoi, posso generare ora:"
echo " - file README esteso (y/n)"
echo " - workflow GitHub Actions per CI/CD (y/n)"
echo " - script di deploy su Vercel (y/n)"
read -r -p "Scegli (README/WORKFLOW/VERCEL/N): " NEXT_ACTION

case "$NEXT_ACTION" in
  README|readme|Readme|y|Y)
    cat > README.md <<'MD'
# CareAutoPro - scaffold generato

## Setup locale
1. Copia `.env.example` in `.env.local` e riempi le variabili.
2. npm install
3. npm run dev

## Supabase
Importa le migrazioni dalla cartella `supabase/migrations` o esegui `supabase db push` se usi Supabase CLI.

## Note
Controlla le policy RLS in `supabase/policies/rls_examples.sql` e adatta ai campi reali.
MD
    echo "README generato."
    ;;
  WORKFLOW|workflow)
    mkdir -p .github/workflows
    cat > .github/workflows/ci.yml <<'YML'
name: CI

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
YML
    echo "Workflow CI generato."
    ;;
  VERCEL|vercel)
    cat > scripts/deploy_vercel.sh <<'SH'
#!/usr/bin/env bash
if ! command -v vercel >/dev/null 2>&1; then
  echo "Installa vercel CLI prima (npm i -g vercel)"
  exit 1
fi
vercel --prod
SH
    chmod +x scripts/deploy_vercel.sh
    echo "Script deploy su Vercel generato: scripts/deploy_vercel.sh"
    ;;
  *)
    echo "Nessuna azione aggiuntiva richiesta."
    ;;
esac

echo ""
echo "Fine. Buon lavoro!"
