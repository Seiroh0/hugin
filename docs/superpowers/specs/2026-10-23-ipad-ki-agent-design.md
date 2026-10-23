# Design-Spec: „Hugin" – KI-Agent-App für das iPad

Datum: 2026-10-23 · Status: zur Freigabe durch den Nutzer

## 1. Ziel

Eine native iPad-App, in der ein KI-Agent im Chat Aufträge ausführt – wie Claude
Code/Codex, aber auf dem iPad. Der Agent arbeitet im MVP mit Dateien in
vom Nutzer freigegebenen Ordnern. Später steuert er weitere Apps (Phase 2)
und versteht den Bildschirm (Phase 3).

Nur für den Eigengebrauch, kein App-Store-Vertrieb.

## 2. Kontext & Entscheidungen

| Punkt | Entscheidung |
|---|---|
| Gerät | iPad Air 5 (M1), iPadOS 27.0.1 → Apple Intelligence / Foundation Models verfügbar |
| Entwicklungsrechner | Windows (kein Mac!) → Build über GitHub Actions (macOS-Runner) |
| Installation | `.ipa` per GitHub-Artifact → Windows-PC → **Sideloadly** (Apple-ID); iPad hängt im Tailscale-Netz, Transfer direkt möglich |
| Apple-Konto | Erst Gratis-Account (App läuft 7 Tage, dann neu installieren); 99 €/Jahr-Konto optional später |
| KI-Backend | Hybrid: Apple Foundation Models (on-device, offline, gratis) + Anthropic Claude API (Cloud, eigener Key) |
| App-Name | Hugin („Der Gedanke, der für dich ausfliegt.") |
| Design | Nutzer-Design verbindlich: `docs/design/DESIGN-SYSTEM.md` + 6 Boards in `docs/design/page-*.html` (Farb-/Typo-/Motion-System, Wisp-Zustände, Screens, Icon als SVG) |
| Projektordner | Alles in `E:\VSCode\Projekte\AIAgentIpad` |

## 3. Version 1 (MVP) – Dateien-Agent

### Funktionen
- **Design-System** (nach `docs/design/DESIGN-SYSTEM.md`): Basalt/Schiefer/Knochen/Asche + Glut (lokal)/Frost (Claude)/Rost (Fehler), Geist + Geist Mono, Wisp-Statuslicht mit 7 Zuständen, Motion-Tokens, Reduce-Motion-Support
- **Seitenleiste**: Wortmarke, „Neuer Auftrag", Freigaben (mit Dateizahl), **Munin · Erinnerung** (Auftrags-Historie pro Auftrag: Titel, „wann · lokal/Claude", laufender Auftrag markiert), Einstellungen
- **Start**: Composer-Card, **Botengang-Menü** (Im Haus / Nach Bedarf / Zu Claude, mit Flugbahn-Grafik iPad→Claude), Vorschläge
- **Auftragsansicht (Flugbahn)**: Timeline mit Schritt-Typen (SUCHEN/LESEN/ÜBERGABE/BERICHT …), Akteur-Farbe pro Knoten, Dauer, laufender Schritt mit Wisp, Running-Pill (Schritt X/Y · Zeit), „Anhalten", **Fundstück-Panel** (Live-Extraktion: aktuelle Datei + bisher gefundene Werte mit Akteur-Punkten), „Nächsten Auftrag vormerken"
- **Überschreiben**: Modal „WARTET AUF DICH" mit **Diff-Vorschau (alt/neu)**, Sicherungs-Hinweis mit Zeitstempel-Pfad, Bestätigung per **Halten-Knopf (1,2 s)** mit Fortschrittsring
- **Start-Sequenz**: 1,4 s App-Start-Animation (Funke → Stäbe → Lichtspur → Aufflammen → UI)
- **Chat**: Auftragstext des Nutzers groß, Antwort + Bericht
- **Ordner-Freigabe**: Nutzer wählt Ordner über den System-Dialog (security-scoped Bookmark, dauerhafter Zugriff)
- **Werkzeuge des Agenten** (nur innerhalb freigegebener Ordner):
  - Dateien listen & durchsuchen (Name + Inhalt bei Text/PDF)
  - Dateien lesen (txt, md, csv, json, PDF-Text via PDFKit)
  - Dateien erstellen & bearbeiten (Textformate)
  - Umbenennen & verschieben
  - Zusammenfassungen/Analysen mehrerer Dateien
  - **`note_finding`**: Modell meldet gefundene Werte (z. B. „Strom: 64,20 €") → Fundstück-Panel
- **Jede Aktion** erscheint als Karte in der Flugbahn (Typ, Akteur-Farbe, was wurde getan, Dauer)
- **Kein Löschen.** Überschreiben nur nach Halten-Bestätigung; vor dem
  Überschreiben legt die App automatisch eine Sicherungskopie im App-Container ab
  (Pfad-Schema: `Sicherungen/<Datum_Uhrzeit>/<Datei>`).

### Bewusste Nicht-Ziele (MVP)
- Löschen von Dateien
- Bearbeiten binärer Formate (docx, Bilder …)
- App-Steuerung über App Intents (Phase 2)
- Bildschirm lesen (Phase 3)

## 4. Architektur

```
SwiftUI Chat-UI
      │
Agent-Kern (Loop: planen → Werkzeug aufrufen → Ergebnis lesen → antworten)
   │            │
   │            └── Werkzeug-Registry: FileTools (Phase 2: IntentTools, Phase 3: ScreenTools)
   │
KI-Schicht (LlamaProvider-Interface)
   ├── AppleSystemModel  (Foundation Models, on-device)
   └── ClaudeClient      (HTTPS Messages API, Key aus Keychain)
      │
Speicher: SwiftData (Chat-Verlauf, Freigaben, Einstellungen) · Keychain (API-Key)
```

Bausteine (alle Swift 6 / SwiftUI, ein App-Target „Hugin", iPadOS 27):

1. **ChatViews** – Konversation, Aktionskarten, Eingabe, Statusanzeige
2. **AgentRunner** – der Agent-Loop; begrenzt auf max. 15 Werkzeugaufrufe
   pro Auftrag, danach Abschlussbericht
3. **FileTools** – alle Datei-Operationen als typsichere Tools für die KI
4. **ModelProvider-Protokoll** – gemeinsame Schnittstelle: `respond(prompt, tools, history)`;
   Implementierungen: `AppleSystemModel`, `ClaudeClient`
5. **SecurityStore** – Ordner-Freigaben (security-scoped Bookmarks), Keychain-Zugriff
6. **HuginStore** (SwiftData) – Verlauf + Einstellungen
7. **ModelPicker** – Wahl: Auto / Nur on-device / Nur Claude

### Hybrid-Regeln (Auto-Modus)
- Einfache Aufträge (kurzer Text, Standard-Dateioperation) → on-device
- Modell überfragt, weigert sich oder Ergebnis unbrauchbar → Eskalation an
  Claude mit sichtbarem Hinweis im Chat
- Nutzer kann im Chat jederzeit „nutz Claude" / „nutz lokal" sagen
- Kein Internet → automatisch nur on-device, mit Hinweis

## 5. Datenfluss (Beispiel)

1. Nutzer: „Such alle PDFs mit ‚Rechnung' und fass sie zusammen"
2. AgentRunner → KI plant: `searchFiles("Rechnung", "pdf")`
3. FileTools führt aus, liefert Trefferliste
4. KI: `readFile` je Treffer → eigene Zusammenfassung
5. AgentRunner rendert Aktionskarten (Suche, 3× Lesen) + Endergebnis im Chat
6. Verlauf in SwiftData

## 6. Fehlerbehandlung

| Fall | Verhalten |
|---|---|
| Kein Internet | Nur on-device, Hinweis im Chat |
| Claude-Key fehlt/ungültig | Klare Meldung + Einstellungen-Link, on-device bleibt nutzbar |
| Ordner-Freigabe abgelaufen | Dialog zur Neu-Freigabe |
| On-device-Modell überfragt | Auto-Eskalation an Claude (s. oben), sichtbar als ÜBERGABE-Knoten in der Flugbahn |
| Werkzeug-Fehler (Datei fehlt etc.) | Fehler als Beobachtung an die KI → Agent korrigiert selbst (Wisp: „Stockt"); nach 15 Aufrufen Stopp + Bericht |
| Überschreiben | Halten-Bestätigung (1,2 s) mit Diff-Vorschau + automatische Sicherungskopie |

## 7. Sicherheit & Datenschutz

- Claude-API-Key ausschließlich im Keychain, nie in Code/Repo/GitHub
- Agent arbeitet nur in freigegebenen Ordnern (Sandbox + security-scoped)
- Kein Telemetrie, kein Account-System, keine Cloud außer Claude-API-Aufrufen
- Dateiinhalte verlassen das Gerät nur bei Claude-Nutzung (on-device bleibt lokal)
- Bestätigungsgate für destruktive Schritte (Überschreiben)

## 8. Build & Verteilung (ohne eigenen Mac)

1. Code in diesem Ordner → privates/public GitHub-Repo (Empfehlung:
   **public** → macOS-CI-Minuten gratis; Repo enthält keine Secrets)
2. **GitHub Actions** (macOS-Runner): `xcodebuild` build + Unit-Tests → `.ipa` als Artifact
3. Nutzer lädt `.ipa` herunter → **Sideloadly** auf Windows signiert+installiert per USB (Apple-ID, Gratis-Account)
4. iPad im Tailscale-Netz: `.ipa`/Artifacts auch direkt übertragbar
5. Gratis-Account: App verfällt nach 7 Tagen → erneut per Sideloadly installieren (Daten bleiben)

## 9. Roadmap

- **Phase 2 – App-Steuerung**: App Intents/Shortcuts orchestrieren (Mail senden, Kalender, Notizen) nach dem Muster der Claude-iOS-App; LongRunningIntent für lange Läufe
- **Phase 3 – Screen-Verstehen**: ScreenCaptureKit (iOS 27) + OCR: „Was ist auf meinem Bildschirm?" als Kontext
- **Später evtl.**: docx-Support, Automatisierungen (Hintergrundläufe), Tailscale-Dienste im Heimnetz als Agent-Ziele

## 10. Testing

- **XCTest** auf macOS-Runner bei jedem Push (GitHub Actions):
  - FileTools gegen Temp-Ordner (alle Operationen + Fehlerfälle)
  - AgentRunner-Loop mit Fake-Provider (max-Aufruf-Limit, Eskalation)
  - SecurityStore: Bookmark-Roundtrip
- Manueller Smoke-Test nach jeder `.ipa`-Installation (Checkliste im Repo)

## 11. Offene Punkte

- Keine blockierenden. (Apple-Konto-Upgrade, public vs. private Repo: Empfehlung steht, Entscheidung bei Umsetzung.)
