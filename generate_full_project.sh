#!/usr/bin/env bash
set -euo pipefail

# generate_full_project.sh
# Genera un progetto Next.js (Enterprise B) completo:
# - Next.js App Router
# - TailwindCSS
# - Supabase client/server helpers
# - PWA manifest + service worker
# - scripts: gen-types.sh, prebuild.sh, setup_project.sh
# - struttura components, app, lib, hooks, types (vuota)
# Uso: esegui in GitHub Codespaces (o in una cartella vuota).

PROJECT_DIR=${1:-careautopro}
echo "Generazione progetto in ./\$PROJECT_DIR ..."

# 1) crea cartella e posizionati
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 2) package.json minimo con script utili
cat > package.json <<'JSON'
{
  "name": "careautopro",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "postinstall": "bash scripts/gen-types.sh || true",
    "vercel-build": "bash scripts/prebuild.sh && next build",
    "generate-types": "bash scripts/gen-types.sh",
    "setup-project": "bash scripts/setup_project.sh"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.0.0",
    "next": "14.0.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "swr": "^2.0.0",
    "classnames": "^2.3.2"
  },
  "devDependencies": {
    "autoprefixer": "^10.0.0",
    "postcss": "^8.0.0",
    "tailwindcss": "^3.0.0",
    "typescript": "^5.0.0",
    "eslint": "^8.0.0",
    "prettier": "^2.0.0"
  }
}
JSON

# 3) basic gitignore
cat > .gitignore <<'TXT'
node_modules
.next
.env
.env.local
.DS_Store
dist
out
.vscode
TXT

# 4) tsconfig.json
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": false,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "incremental": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"],
      "@lib/*": ["lib/*"],
      "@types/*": ["types/*"],
      "@components/*": ["components/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
  "exclude": ["node_modules"]
}
JSON

# 5) next.config.mjs
cat > next.config.mjs <<'JS'
const nextConfig = {
  reactStrictMode: true,
  experimental: { appDir: true }
};
export default nextConfig;
JS

# 6) vercel.json
cat > vercel.json <<'JSON'
{
  "buildCommand": "npm run vercel-build",
  "framework": "nextjs",
  "rewrites": [{ "source": "/(.*)", "destination": "/" }]
}
JSON

# 7) Tailwind config + postcss
cat > tailwind.config.js <<'JS'
module.exports = {
  content: ["./app/**/*.{ts,tsx,js,jsx}", "./components/**/*.{ts,tsx,js,jsx}"],
  theme: { extend: {} },
  plugins: []
};
JS

cat > postcss.config.js <<'JS'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
};
JS

# 8) crea cartelle
mkdir -p app components/components ui components/layout components/auth lib/supabase scripts public/icons styles hooks types supabase/migrations supabase/policies

# 9) styles/globals.css
cat > styles/globals.css <<'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

html,body,#root { height: 100%; }
body { font-family: Inter, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial; background:#f8fafc; }
CSS

# 10) PWA files (public)
mkdir -p public/icons
cat > public/manifest.json <<'JSON'
{
  "name": "CareAutoPro",
  "short_name": "CareAuto",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#0d6efd",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
JSON

cat > public/service-worker.js <<'JS'
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open('careauto-cache-v1').then(c => c.addAll(['/'])));
});
self.addEventListener('fetch', (e) => {
  e.respondWith(caches.match(e.request).then(resp => resp || fetch(e.request)));
});
JS

# 11) lib/supabase client + server
mkdir -p lib/supabase
cat > lib/supabase/client.ts <<'TS'
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@types/database";

export const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
TS

cat > lib/supabase/server.ts <<'TS'
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@types/database";

export const supabaseAdmin = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);
TS

# 12) scripts: gen-types.sh & prebuild.sh & setup_project.sh
cat > scripts/gen-types.sh <<'SH'
#!/usr/bin/env bash
set -e
echo "[gen-types] Rigenerazione tipi Supabase..."
if [ -z "${SUPABASE_PROJECT_ID:-}" ]; then
  echo "[gen-types] ERRORE: SUPABASE_PROJECT_ID non impostata."
  exit 1
fi
mkdir -p types
npx supabase gen types typescript --project-id "$SUPABASE_PROJECT_ID" > types/database.ts
echo "[gen-types] OK: types/database.ts aggiornato"
SH
chmod +x scripts/gen-types.sh

cat > scripts/prebuild.sh <<'SH'
#!/usr/bin/env bash
set -e
echo "[prebuild] Prebuild Vercel: generazione tipi..."
if [ -z "${SUPABASE_PROJECT_ID:-}" ]; then
  echo "[prebuild] ERRORE: SUPABASE_PROJECT_ID non impostato."
  exit 1
fi
mkdir -p types
npx supabase gen types typescript --project-id "$SUPABASE_PROJECT_ID" > types/database.ts
echo "[prebuild] types/database.ts generato"
SH
chmod +x scripts/prebuild.sh

# setup_project.sh (script sicuro per Codespaces; non contiene token)
cat > scripts/setup_project.sh <<'SH'
#!/usr/bin/env bash
echo "======== setup_project.sh (interactive) ========"
# Questo script guida al login e alla configurazione dei secrets (usa gh & vercel interattivi)
if ! command -v gh &>/dev/null; then
  echo "Installa GitHub CLI: https://cli.github.com/"
  exit 1
fi
if ! command -v vercel &>/dev/null; then
  echo "Installa Vercel CLI: npm i -g vercel"
  exit 1
fi
echo "1) Login GitHub (browser) se necessario"
gh auth login || true
echo "2) Login Vercel (browser) se necessario"
vercel login || true
read -p "Vuoi impostare i GitHub Secrets ora? (si/no) " SETSECRETS
if [[ "$SETSECRETS" == "si" || "$SETSECRETS" == "s" ]]; then
  read -p "NEXT_PUBLIC_SUPABASE_URL: " SUPA_URL
  read -p "NEXT_PUBLIC_SUPABASE_ANON_KEY: " SUPA_ANON
  read -p "SUPABASE_SERVICE_ROLE_KEY: " SUPA_SERVICE
  read -p "SUPABASE_PROJECT_ID: " SUPA_ID
  gh secret set NEXT_PUBLIC_SUPABASE_URL --body "$SUPA_URL"
  gh secret set NEXT_PUBLIC_SUPABASE_ANON_KEY --body "$SUPA_ANON"
  gh secret set SUPABASE_SERVICE_ROLE_KEY --body "$SUPA_SERVICE"
  gh secret set SUPABASE_PROJECT_ID --body "$SUPA_ID"
  echo "Secrets impostati."
fi
echo "3) Generazione tipi Supabase (locale)"
if [ -n "${SUPA_ID:-}" ]; then
  export SUPABASE_PROJECT_ID="$SUPA_ID"
fi
bash scripts/gen-types.sh || echo "gen-types fallito (controlla SUPABASE_PROJECT_ID)"
echo "Setup guidato completato."
SH
chmod +x scripts/setup_project.sh

# 13) components (layout, ui, basic)
mkdir -p components/layout components/auth
cat > components/layout/Navbar.tsx <<'TSX'
'use client'
import Link from "next/link";
export default function Navbar(){
  return (
    <header className="bg-white shadow">
      <div className="container mx-auto px-4 py-3 flex justify-between items-center">
        <Link href="/"><span className="font-bold text-lg">CareAutoPro</span></Link>
        <nav className="space-x-4">
          <Link href="/veicoli" className="text-slate-700">Veicoli</Link>
          <Link href="/tracking" className="text-slate-700">Tracking</Link>
          <Link href="/dashboard" className="text-slate-700">Dashboard</Link>
        </nav>
      </div>
    </header>
  );
}
TSX

cat > components/layout/Footer.tsx <<'TSX'
export default function Footer(){
  return (
    <footer className="mt-8 py-6 text-center text-sm text-slate-500">
      © {new Date().getFullYear()} CareAutoPro
    </footer>
  );
}
TSX

# 14) app router files (layout + index)
mkdir -p app/dashboard app/auth app/veicoli app/api
cat > app/layout.tsx <<'TSX'
import "./globals.css";
import Navbar from "@components/layout/Navbar";
import Footer from "@components/layout/Footer";
export const metadata = { title: "CareAutoPro" };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="it">
      <body className="min-h-screen bg-slate-50">
        <Navbar />
        <main className="container mx-auto px-4 py-6">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
TSX

cat > app/page.tsx <<'TSX'
export default function Home() {
  return (
    <section>
      <h1 className="text-3xl font-bold">CareAutoPro</h1>
      <p className="mt-2 text-slate-600">Gestisci i tuoi veicoli, traccia le sessioni e controlli di manutenzione.</p>
    </section>
  );
}
TSX

# 15) veicoli page (example)
cat > app/veicoli/page.tsx <<'TSX'
'use client'
import { useEffect, useState } from "react";
import { supabase } from "@lib/supabase/client";
import dynamic from "next/dynamic";

const DeckView = dynamic(()=>import("@components/DeckView"),{ssr:false});
const TableView = dynamic(()=>import("@components/TableView"),{ssr:false});
const DetailView = dynamic(()=>import("@components/DetailView"),{ssr:false});
const FormView = dynamic(()=>import("@components/FormView"),{ssr:false});

export default function VeicoliPage(){
  const [items,setItems]=useState<any[]>([]);
  const [selected,setSelected]=useState<any|null>(null);
  const [mode,setMode]=useState<'deck'|'table'|'form'>('deck');

  useEffect(()=>{
    (async()=>{
      try {
        const { data } = await supabase.from('veicoli').select('*').order('dataora',{ascending:false});
        setItems(data || []);
      } catch(e){}
    })();
  },[]);

  const onSave = async (v:any) => {
    await supabase.from('veicoli').insert([{ nomeveicolo: v.nomeveicolo, targa: v.targa }]);
    const { data } = await supabase.from('veicoli').select('*');
    setItems(data || []);
    setMode('deck');
  };

  return (
    <div>
      <div className="flex gap-2 mb-4">
        <button onClick={()=>setMode('deck')} className="px-3 py-1 border rounded">Deck</button>
        <button onClick={()=>setMode('table')} className="px-3 py-1 border rounded">Table</button>
        <button onClick={()=>setMode('form')} className="px-3 py-1 border rounded">Aggiungi</button>
      </div>

      {mode==='deck' && <DeckView items={items} onOpen={setSelected} />}
      {mode==='table' && <TableView items={items} onOpen={setSelected} />}
      {mode==='form' && <FormView onSave={onSave} />}

      <div className="mt-6">
        <DetailView item={selected} />
      </div>
    </div>
  );
}
TSX

# 16) components views used in veicoli
cat > components/DeckView.tsx <<'TSX'
'use client'
export default function DeckView({ items, onOpen }: any){
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {items?.map((i:any)=>(
        <div key={i.veicolo_id||i.id} className="p-4 bg-white rounded shadow">
          <div className="flex justify-between">
            <div>
              <h3 className="font-semibold">{i.nomeveicolo||i.nome}</h3>
              <div className="text-sm text-slate-500">Targa: {i.targa||i.plate}</div>
            </div>
            <button className="text-blue-600" onClick={()=>onOpen(i)}>Dettagli</button>
          </div>
          <div className="mt-2 text-xs text-slate-600">Km: {i.kmattuali ?? i.km || '--'}</div>
        </div>
      ))}
    </div>
  )
}
TSX

cat > components/TableView.tsx <<'TSX'
'use client'
export default function TableView({ items, onOpen }: any){
  return (
    <div className="overflow-auto bg-white rounded shadow">
      <table className="min-w-full">
        <thead className="bg-slate-50">
          <tr>
            <th className="px-4 py-2 text-left">Nome</th>
            <th className="px-4 py-2 text-left">Targa</th>
            <th className="px-4 py-2 text-left">Km</th>
            <th className="px-4 py-2"></th>
          </tr>
        </thead>
        <tbody>
          {items?.map((r:any)=>(
            <tr key={r.veicolo_id||r.id} className="border-t">
              <td className="px-4 py-2">{r.nomeveicolo||r.nome}</td>
              <td className="px-4 py-2">{r.targa||r.plate}</td>
              <td className="px-4 py-2">{r.kmattuali ?? r.km ?? '--'}</td>
              <td className="px-4 py-2"><button onClick={()=>onOpen(r)} className="text-blue-600">Apri</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
TSX

cat > components/DetailView.tsx <<'TSX'
'use client'
export default function DetailView({ item }: any){
  if(!item) return <div className="p-4 text-slate-500">Seleziona un veicolo</div>;
  return (
    <div className="p-4 bg-white rounded shadow">
      <h3 className="text-lg font-semibold">{item.nomeveicolo||item.nome}</h3>
      <div className="text-sm text-slate-600">Targa: {item.targa||item.plate}</div>
      <div className="mt-2">Km attuali: {item.kmattuali ?? item.km ?? '--'}</div>
    </div>
  );
}
TSX

cat > components/FormView.tsx <<'TSX'
'use client'
import { useState } from "react";
export default function FormView({ onSave, initial }: any){
  const [nome,setNome]=useState(initial?.nomeveicolo ?? initial?.nome ?? "");
  const [targa,setTarga]=useState(initial?.targa ?? initial?.plate ?? "");
  return (
    <form onSubmit={e=>{e.preventDefault(); onSave({nomeveicolo:nome,targa});}}>
      <div className="grid gap-2">
        <input className="p-2 border rounded" placeholder="Nome veicolo" value={nome} onChange={e=>setNome(e.target.value)} />
        <input className="p-2 border rounded" placeholder="Targa" value={targa} onChange={e=>setTarga(e.target.value)} />
        <div>
          <button className="px-3 py-2 bg-blue-600 text-white rounded">Salva</button>
        </div>
      </div>
    </form>
  );
}
TSX

# 17) hooks/useUser.ts
mkdir -p hooks
cat > hooks/useUser.ts <<'TS'
import { useEffect, useState } from "react";
import { supabase } from "@lib/supabase/client";

export function useUser(){
  const [user, setUser] = useState<any>(null);
  useEffect(()=>{
    supabase.auth.getUser().then(r=> setUser(r.data?.user ?? null));
    const sub = supabase.auth.onAuthStateChange((_event, session) => setUser(session?.user ?? null));
    return () => { sub.data?.subscription?.unsubscribe?.(); };
  },[]);
  return { user };
}
TS

# 18) README essenziale
cat > README.md <<'MD'
# CareAutoPro - scaffold enterprise

## Setup rapido (Codespaces)
1. Copia `.env.example` -> `.env.local` e inserisci le chiavi Supabase
2. npm install
3. export SUPABASE_PROJECT_ID=tuo_project_id
4. npm run generate-types
5. npm run dev

## Deploy su Vercel
- Configura le env su Vercel (NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_PROJECT_ID)
- Vercel eseguirà lo script prebuild che rigenera i tipi e costruisce il progetto.
MD

# 19) .env.example
cat > .env.example <<'ENV'
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_PROJECT_ID=
ENV

# 20) inizializza git
git init >/dev/null 2>&1 || true
git add .
git commit -m "Scaffold completo Next.js + Supabase (Enterprise B)" || true

# 21) fine
echo ""
echo "=========================================="
echo "GENERAZIONE COMPLETATA in: $(pwd)"
echo ""
echo "Prossimi passi consigliati:"
echo "1) Apri Codespaces terminal"
echo "2) Imposta le env in Vercel o in .env.local"
echo "3) npm install"
echo "4) export SUPABASE_PROJECT_ID=il_tuo_id"
echo "5) npm run generate-types"
echo "6) npm run dev"
echo ""
echo "Per collegare e deployare con sicurezza usa: scripts/setup_project.sh"
echo "=========================================="
