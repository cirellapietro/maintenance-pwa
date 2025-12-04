-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.avvisi_gruppo (
  avviso_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  titolo text,
  messaggio text,
  data_ora_pubblicazione timestamp with time zone,
  inviato boolean,
  esito text,
  tipoveicolo_id uuid,
  dataora timestamp with time zone,
  data_ora_elimina timestamp with time zone,
  CONSTRAINT avvisi_gruppo_pkey PRIMARY KEY (avviso_id),
  CONSTRAINT AvvisiGruppo_tipoveicolo_id_fkey FOREIGN KEY (tipoveicolo_id) REFERENCES public.tipoveicoli(tipoveicolo_id)
);
CREATE TABLE public.coincidenza_di (
  inconcidenzadi_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  descrizione text NOT NULL,
  data_ora_elimina timestamp with time zone,
  CONSTRAINT coincidenza_di_pkey PRIMARY KEY (inconcidenzadi_id)
);
CREATE TABLE public.config (
  foglioveicoli text,
  fogliomessaggi text,
  foglioconfig text,
  foglioutenti text,
  clientsecret text,
  soggettoemail text,
  templateemail text,
  frequenzaesecuzione text,
  loglevel text,
  debug boolean,
  intervallo integer,
  unit text,
  valore text,
  inviamessaggireali boolean,
  twilioaccountsid text,
  twilioauthtoken text,
  twiliophonenumber text,
  googlechatwebhookurl text,
  telegrambottoken text,
  telegramchatid text,
  telegramchatidtest text,
  emailtest text,
  numerowhatsapptest text,
  interventistatoid text,
  orainvio text,
  batchsize integer,
  usanuovaversione boolean,
  batchthreshold integer,
  admobidpublisher text,
  admobidapp text,
  numeroorefrequenzasincronizzazionepwa integer,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  adMobEnabled boolean DEFAULT false,
  adMobAppId text,
  adMobAdUnitId text,
  adSenseEnabled boolean DEFAULT false,
  adSenseClientId text,
  adSenseAdSlot text
);
CREATE TABLE public.controlliperiodici (
  controlloperiodico_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  tipoveicolo_id uuid,
  nomecontrollo text,
  descrizione text,
  operazione_id uuid,
  incoincidenzadi uuid,
  frequenzakm integer,
  avvisokmprima integer,
  frequenzamesi integer,
  avvisogiorniprima integer,
  dakm integer,
  akm integer,
  damesi integer,
  amesi integer,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  CONSTRAINT controlliperiodici_pkey PRIMARY KEY (controlloperiodico_id),
  CONSTRAINT ControlliPeriodici_tipoveicolo_id_fkey FOREIGN KEY (tipoveicolo_id) REFERENCES public.tipoveicoli(tipoveicolo_id),
  CONSTRAINT ControlliPeriodici_operazione_id_fkey FOREIGN KEY (operazione_id) REFERENCES public.operazioni(operazione_id),
  CONSTRAINT ControlliPeriodici_incoincidenzadi_fkey FOREIGN KEY (incoincidenzadi) REFERENCES public.coincidenza_di(inconcidenzadi_id)
);
CREATE TABLE public.impostazionitracking (
  impostazione_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  utente_id uuid NOT NULL,
  veicolo_id uuid,
  tracking_automatico boolean DEFAULT true,
  salva_percorso_gps boolean DEFAULT false,
  intervallo_aggiornamento_secondi integer DEFAULT 30,
  notifica_inizio_viaggio boolean DEFAULT true,
  notifica_fine_viaggio boolean DEFAULT true,
  dataora timestamp with time zone DEFAULT now(),
  dataoraelimina timestamp with time zone,
  CONSTRAINT impostazionitracking_pkey PRIMARY KEY (impostazione_id),
  CONSTRAINT ImpostazioniTracking_utente_id_fkey FOREIGN KEY (utente_id) REFERENCES public.utenti(utente_id),
  CONSTRAINT ImpostazioniTracking_veicolo_id_fkey FOREIGN KEY (veicolo_id) REFERENCES public.veicoli(veicolo_id)
);
CREATE TABLE public.interventi (
  intervento_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  veicolo_id uuid,
  controlloperiodico_id uuid,
  interventistato_id uuid,
  descrizioneaggiuntiva text,
  kmintervento integer,
  mesi integer,
  dataoraintervento timestamp with time zone,
  dataora timestamp with time zone,
  batchid text,
  dataoraelimina timestamp with time zone,
  CONSTRAINT interventi_pkey PRIMARY KEY (intervento_id),
  CONSTRAINT Interventi_veicolo_id_fkey FOREIGN KEY (veicolo_id) REFERENCES public.veicoli(veicolo_id),
  CONSTRAINT Interventi_controlloperiodico_id_fkey FOREIGN KEY (controlloperiodico_id) REFERENCES public.controlliperiodici(controlloperiodico_id),
  CONSTRAINT Interventi_interventistato_id_fkey FOREIGN KEY (interventistato_id) REFERENCES public.interventistato(interventistato_id)
);
CREATE TABLE public.interventistato (
  interventistato_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  descrizione text NOT NULL,
  sostituzione boolean,
  rabbocco boolean,
  inversione boolean,
  ispezione boolean,
  dataoraelimina timestamp with time zone,
  CONSTRAINT interventistato_pkey PRIMARY KEY (interventistato_id)
);
CREATE TABLE public.logs (
  dataora timestamp with time zone,
  descrizione text,
  tiponotifica text,
  statoinvio text,
  messaggio text,
  destinatario text,
  batchid text,
  dataoraelimina timestamp with time zone
);
CREATE TABLE public.messaggiavviso (
  messaggio_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  veicolo_id uuid,
  utente_id uuid,
  intervento_id uuid,
  testo text,
  messaggiocomposto text,
  inviato boolean,
  statoinvio text,
  batchid text,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  CONSTRAINT messaggiavviso_pkey PRIMARY KEY (messaggio_id),
  CONSTRAINT MessaggiAvviso_veicolo_id_fkey FOREIGN KEY (veicolo_id) REFERENCES public.veicoli(veicolo_id),
  CONSTRAINT MessaggiAvviso_utente_id_fkey FOREIGN KEY (utente_id) REFERENCES public.utenti(utente_id),
  CONSTRAINT MessaggiAvviso_intervento_id_fkey FOREIGN KEY (intervento_id) REFERENCES public.interventi(intervento_id)
);
CREATE TABLE public.operations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  operazione_id uuid,
  nome character varying NOT NULL,
  descrizione text,
  stato character varying DEFAULT 'pending'::character varying,
  priorita character varying DEFAULT 'medium'::character varying,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT operations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.operazioni (
  operazione_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  descrizione text NOT NULL,
  sostituzione boolean,
  rabbocco boolean,
  inversione boolean,
  ispezione boolean,
  dataoraelimina timestamp with time zone,
  CONSTRAINT operazioni_pkey PRIMARY KEY (operazione_id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text NOT NULL UNIQUE,
  display_name text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.sessioniutilizzo (
  sessione_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  veicolo_id uuid NOT NULL,
  utente_id uuid NOT NULL,
  dataora_inizio timestamp with time zone NOT NULL,
  dataora_fine timestamp with time zone,
  km_iniziali integer,
  km_finali integer,
  km_percorsi integer,
  durata_minuti integer,
  posizione_inizio_lat numeric,
  posizione_inizio_lng numeric,
  posizione_fine_lat numeric,
  posizione_fine_lng numeric,
  sessione_attiva boolean DEFAULT true,
  note text,
  dataora timestamp with time zone DEFAULT now(),
  dataoraelimina timestamp with time zone,
  CONSTRAINT sessioniutilizzo_pkey PRIMARY KEY (sessione_id),
  CONSTRAINT SessioniUtilizzo_veicolo_id_fkey FOREIGN KEY (veicolo_id) REFERENCES public.veicoli(veicolo_id),
  CONSTRAINT SessioniUtilizzo_utente_id_fkey FOREIGN KEY (utente_id) REFERENCES public.utenti(utente_id),
  CONSTRAINT fk_sessioniutilizzo_veicolo FOREIGN KEY (veicolo_id) REFERENCES public.veicoli(veicolo_id)
);
CREATE TABLE public.test_finale (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  operazione_id uuid,
  nome text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT test_finale_pkey PRIMARY KEY (id)
);
CREATE TABLE public.test_sistema_completo (
  test_id uuid NOT NULL DEFAULT gen_random_uuid(),
  operazione_id uuid,
  nome_test text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT test_sistema_completo_pkey PRIMARY KEY (test_id)
);
CREATE TABLE public.tiponotificaavviso (
  tiponotificaavviso_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  descrizione text NOT NULL,
  dataoraelimina timestamp with time zone,
  CONSTRAINT tiponotificaavviso_pkey PRIMARY KEY (tiponotificaavviso_id)
);
CREATE TABLE public.tipoveicoli (
  tipoveicolo_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  descrizione text NOT NULL,
  dataoraelimina timestamp with time zone,
  CONSTRAINT tipoveicoli_pkey PRIMARY KEY (tipoveicolo_id)
);
CREATE TABLE public.trackinggps (
  tracking_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  sessione_id uuid NOT NULL,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  velocita numeric,
  direzione integer,
  precisione numeric,
  dataora timestamp with time zone DEFAULT now(),
  CONSTRAINT trackinggps_pkey PRIMARY KEY (tracking_id),
  CONSTRAINT TrackingGPS_sessione_id_fkey FOREIGN KEY (sessione_id) REFERENCES public.sessioniutilizzo(sessione_id)
);
CREATE TABLE public.utenti (
  utente_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nominativo text NOT NULL,
  pwd text,
  email text,
  phone text,
  tiponotificaavviso_id uuid,
  statoutente_id uuid,
  profiloutente_id uuid,
  telegramchatid text,
  abilitagps boolean,
  frequenzaoregps integer,
  dataoradisabilita timestamp with time zone,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  CONSTRAINT utenti_pkey PRIMARY KEY (utente_id),
  CONSTRAINT Utenti_tiponotificaavviso_id_fkey FOREIGN KEY (tiponotificaavviso_id) REFERENCES public.tiponotificaavviso(tiponotificaavviso_id),
  CONSTRAINT Utenti_statoutente_id_fkey FOREIGN KEY (statoutente_id) REFERENCES public.utentistato(utentestato_id),
  CONSTRAINT Utenti_profiloutente_id_fkey FOREIGN KEY (profiloutente_id) REFERENCES public.utentiprofilo(profiloutente_id)
);
CREATE TABLE public.utentiprofilo (
  profiloutente_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  profiloutente text NOT NULL,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  CONSTRAINT utentiprofilo_pkey PRIMARY KEY (profiloutente_id)
);
CREATE TABLE public.utentistato (
  utentestato_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  statoutente text NOT NULL,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  CONSTRAINT utentistato_pkey PRIMARY KEY (utentestato_id)
);
CREATE TABLE public.vehicles (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  plate text NOT NULL UNIQUE,
  make text,
  model text,
  year integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT vehicles_pkey PRIMARY KEY (id),
  CONSTRAINT vehicles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.veicoli (
  veicolo_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  utente_id uuid,
  tipoveicolo_id uuid,
  nomeveicolo text,
  targa text,
  dataimmatricolazione date,
  kmanno integer,
  kmannodataorainserimento timestamp with time zone,
  kmeffettivi integer,
  kmeffettividataorainserimento timestamp with time zone,
  kmpresunti integer,
  kmpresuntidataorainserimento timestamp with time zone,
  kmdagps integer,
  kmdagpsdataorainserimento timestamp with time zone,
  kw integer,
  cilindrata integer,
  kmattuali integer,
  kmattualidataorainserimento timestamp with time zone,
  dataora timestamp with time zone,
  dataoraelimina timestamp with time zone,
  sessione_attiva_id uuid,
  ultimo_aggiornamento_tracking timestamp with time zone,
  CONSTRAINT veicoli_pkey PRIMARY KEY (veicolo_id),
  CONSTRAINT Veicoli_utente_id_fkey FOREIGN KEY (utente_id) REFERENCES public.utenti(utente_id),
  CONSTRAINT Veicoli_tipoveicolo_id_fkey FOREIGN KEY (tipoveicolo_id) REFERENCES public.tipoveicoli(tipoveicolo_id),
  CONSTRAINT Veicoli_sessione_attiva_fkey FOREIGN KEY (sessione_attiva_id) REFERENCES public.sessioniutilizzo(sessione_id),
  CONSTRAINT fk_veicoli_sessione_attiva FOREIGN KEY (sessione_attiva_id) REFERENCES public.sessioniutilizzo(sessione_id)
);
