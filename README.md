# GVP MVP - Schritt 1: Datenbankfundament

Dieser Stand enthält noch kein Frontend. Er definiert das PostgreSQL/Supabase-Schema und erzeugt aus der Master-Arbeitsmappe reproduzierbare Seed-Daten.

## Struktur
- `data/GVP_Masterdaten_final.xlsx` - lokale Importquelle (nicht für ein öffentliches Repository vorgesehen)
- `scripts/import_master.py` - prüft und transformiert die Masterdatei
- `supabase/migrations/202609300001_initial_schema.sql` - Datenmodell, Indizes, Grants und RLS
- `supabase/seed.sql` - aus der Masterdatei erzeugte Stammdaten

## Voraussetzung
Für die vollständig lokale Supabase-Umgebung werden Node.js/npm, Docker und die Supabase CLI benötigt.

## Lokaler Ablauf
1. Im Projektordner Supabase initialisieren: `npx supabase init` (nur falls noch keine `supabase/config.toml` vorhanden ist).
2. Seed neu aus Excel erzeugen: `python scripts/import_master.py data/GVP_Masterdaten_final.xlsx --out supabase/seed.sql`
3. Lokalen Supabase-Stack starten: `npx supabase start`
4. Schema und Seed reproduzierbar anwenden: `npx supabase db reset`

## Sicherheitsprinzip
- GVP-Stammdaten sind für authentifizierte Clients lesbar, aber nicht beschreibbar.
- Der Veranstaltungsmodus nutzt später anonyme Supabase-Authentifizierung. Diese Benutzer laufen technisch unter der Rolle `authenticated`.
- Neue Aufgaben dürfen ausschließlich mit `source = 'Veranstaltung'` angelegt werden.
- Erfassungssitzungen dürfen nur für `auth.uid()` angelegt/gelesen/geändert werden.
- Fachliche Beziehungen dürfen nur über eine eigene Erfassungssitzung angelegt werden.
- Es gibt keine Tabelle für Namen, E-Mail, Telefonnummern oder Dienstorte.
- Service-Role/Secret Keys gehören niemals ins Frontend.

## Noch nicht Bestandteil dieses Schritts
React-Frontend, Netzwerkvisualisierung, Event-Workflow und der produktive Cloud-Deploy folgen erst nach erfolgreichem Datenbanktest.
