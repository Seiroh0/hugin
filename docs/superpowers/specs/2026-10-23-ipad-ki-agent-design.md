# Design-Spec: „PadPilot" – KI-Agent-App für das iPad

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
| App-Name (Arbeitstitel) | PadPilot |
| Projektordner | Alles in `E:\VSCode\Projekte\AIAgentIpad` |

## 3. Version 1 (MVP) – Dateien-Agent

### Funktionen
- **Chat-UI** (SwiftUI): Nachrichten, Agent-Aktionsliste, Status
- **Ordner-Freigabe**: Nutzer wählt Ordner über den System-Dialog (security-scoped Bookmark, dauerhafter Zugriff)
- **Werkzeuge des Agenten** (nur innerhalb freigegebener Ordner):
  - Dateien listen & durchsuchen (Name + Inhalt bei Text/PDF)
  - Dateien lesen (txt, md, csv, json, PDF-Text via PDFKit)
  - Dateien erstellen & bearbeiten (Textformate)
  - Umbenennen & verschieben
  - Zusammenfassungen/Analysen mehrerer Dateien
- **Jede Aktion** erscheint als Karte im Chat (was wurde getan, welche Datei)
- **Kein Löschen.** Überschreiben nur nach expliziter Bestätigung; vor dem
  Überschreiben legt die App automatisch eine Sicherungskopie im App-Container ab.

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

Bausteine (alle Swift 6 / SwiftUI, ein App-Target „PadPilot", iPadOS 27):

1. **ChatViews** – Konversation, Aktionskarten, Eingabe, Statusanzeige
2. **AgentRunner** – der Agent-Loop; begrenzt auf max. 15 Werkzeugaufrufe
   pro Auftrag, danach Abschlussbericht
3. **FileTools** – alle Datei-Operationen als typsichere Tools für die KI
4. **ModelProvider-Protokoll** – gemeinsame Schnittstelle: `respond(prompt, tools, history)`;
   Implementierungen: `AppleSystemModel`, `ClaudeClient`
5. **SecurityStore** – Ordner-Freigaben (security-scoped Bookmarks), Keychain-Zugriff
6. **PadPilotStore** (SwiftData) – Verlauf + Einstellungen
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
| On-device-Modell überfragt | Auto-Eskalation an Claude (s. oben) |
| Werkzeug-Fehler (Datei fehlt etc.) | Fehler als Beobachtung an die KI → Agent korrigiert selbst; nach 15 Aufrufen Stopp + Bericht |
| Überschreiben | Bestätigungsdialog + automatische Sicherungskopie |

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
