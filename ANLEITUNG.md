# Pingpaar online stellen (GitHub Pages + Supabase)

Dauer: etwa 15–20 Minuten. Kosten: 0 €. Du brauchst nur einen Computer mit Browser.

**Was in diesem Ordner ist**

| Datei | Wofür |
|---|---|
| `index.html` | die App |
| `config.js` | hier trägst du deine Supabase-Daten ein (Schritt 2) |
| `supabase.sql` | baut die Datenbank auf (Schritt 1) |
| `vendor/` | Bibliotheken für Datenbank und 3D, bitte mit hochladen |
| `manifest.webmanifest`, `icon-*.png`, `apple-touch-icon.png` | App-Symbol, wenn man Pingpaar zum Home-Bildschirm hinzufügt |

---

## Schritt 1: Datenbank bei Supabase anlegen

1. Geh auf **supabase.com** und erstelle ein kostenloses Konto.
2. Klick auf **New project**.
   - **Name:** `pingpaar`
   - **Database Password:** ein sicheres Passwort ausdenken und notieren
   - **Region:** **Central EU (Frankfurt)**, damit alle Daten in der EU liegen
   - Klick auf **Create new project** und warte ca. 1–2 Minuten.
3. Links im Menü: **SQL Editor** → **New query**.
4. Öffne die Datei `supabase.sql` mit einem Texteditor, markiere alles, kopiere es und füge es in Supabase ein.
5. Klick auf **Run**. Unten sollte „Success“ stehen.

## Schritt 2: Schlüssel in `config.js` eintragen

1. In Supabase links unten: **Project Settings** (Zahnrad) → **API** bzw. **Data API** / **API Keys**.
2. Kopiere die **Project URL** (sieht aus wie `https://abcdefgh.supabase.co`).
3. Kopiere den **anon public** Schlüssel. In neueren Projekten heißt er **publishable key**.
4. Öffne `config.js` mit einem Texteditor und trag beides zwischen die Anführungszeichen ein:

```js
window.PINGPAAR_CONFIG = {
  supabaseUrl: 'https://abcdefgh.supabase.co',
  supabaseKey: 'eyJhbGciOi…'
};
```

5. Speichern.

> Der anon- bzw. publishable-Schlüssel darf öffentlich sein, die Zugriffsregeln aus Schritt 1 schützen eure Daten.
> Trag **niemals** den `service_role`- bzw. `secret`-Schlüssel ein.

## Schritt 3: Webseite auf GitHub Pages hochladen

1. Geh auf **github.com** und erstelle ein kostenloses Konto. Dein Benutzername steht später in der Adresse, z. B. `vivian`.
2. Oben rechts **+** → **New repository**.
   - **Repository name:** `pingpaar`
   - **Public** auswählen (GitHub Pages ist für öffentliche Repos kostenlos)
   - **Create repository**
3. Auf der neuen Seite: Link **uploading an existing file** anklicken.
4. Öffne den Pingpaar-Ordner auf deinem Computer, markiere **alle Dateien und den Ordner `vendor`** und zieh sie in das Browserfenster.
5. Unten auf **Commit changes** klicken.
6. Oben **Settings** → links **Pages**.
   - Unter **Build and deployment** → **Source:** „Deploy from a branch“
   - **Branch:** `main`, Ordner `/ (root)` → **Save**
7. Nach 1–2 Minuten steht oben auf der Pages-Seite deine Adresse, z. B.
   **`https://vivian.github.io/pingpaar/`**

## Schritt 4: Adresse in Supabase eintragen

Damit die Links in den E-Mails (Konto bestätigen, Passwort vergessen) zurück zu deiner Seite führen:

1. Supabase → **Authentication** → **URL Configuration**.
2. **Site URL:** deine GitHub-Adresse, z. B. `https://vivian.github.io/pingpaar/`
3. Unter **Redirect URLs** → **Add URL** → dieselbe Adresse noch mal eintragen → speichern.

## Schritt 5: Ausprobieren

1. Öffne deine Adresse auf dem Handy und erstelle ein Konto.
2. Bestätige die E-Mail, die Supabase dir schickt (auch im Spam schauen).
3. Starte euer Paar, lass Kiesel schlüpfen und schick deinem Partner die Einladung.
4. Dein Partner öffnet den Link, erstellt ein Konto, und ihr seid verbunden.

**Wie eine App aufs Handy legen:**
- iPhone (Safari): Teilen-Symbol → **Zum Home-Bildschirm**
- Android (Chrome): Menü ⋮ → **Zum Startbildschirm hinzufügen**

---

## Gut zu wissen

- **E-Mails:** Der kostenlose Supabase-Mailversand schickt nur wenige E-Mails pro Stunde. Für euch zwei reicht das. Wenn mehr Leute die App nutzen sollen, unter **Authentication → Emails → SMTP Settings** einen eigenen Mailanbieter eintragen.
- **E-Mail-Texte auf Deutsch:** Unter **Authentication → Emails → Templates** kannst du die Texte der Bestätigungs-E-Mails anpassen.
- **Pause bei Nichtnutzung:** Kostenlose Supabase-Projekte werden nach etwa einer Woche ohne Nutzung pausiert. Im Supabase-Dashboard mit einem Klick wieder aktivieren. Wenn ihr die App regelmäßig nutzt, passiert das nicht.
- **Änderungen hochladen:** Neue Version einer Datei auf GitHub einfach wieder über **Add file → Upload files** hochladen. Die Seite aktualisiert sich nach 1–2 Minuten.
- **Wenn andere Leute die App nutzen sollen:** Dann braucht die Seite in Deutschland ein Impressum und eine Datenschutzerklärung. Für euch zwei privat ist das nicht nötig.

## Was die App kann

- Echte Konten mit E-Mail und Passwort, Passwort vergessen, Konto löschen
- Paar starten und Partner per Link oder Code einladen
- Alles wird live geteilt: Stimmung, Herzen und Kuss zurück, Kennenlern-Fragen, Kiesel, Foodspots, Wünsche, Erinnerungen, Kalender, Serie und Tagesaufgabe
- Private Kalender sieht nur ihr selbst, auch technisch: Die Datenbank gibt sie dem Partner nicht heraus
- Daten in Frankfurt (EU), verschlüsselt gespeichert und übertragen

**Was es noch nicht gibt:** Push-Benachrichtigungen bei geschlossener App, echte Widgets und GPS-Entfernung. Dafür braucht es die spätere Handy-App.
