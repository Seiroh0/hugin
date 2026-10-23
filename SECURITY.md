# Sicherheitsrichtlinie / Security Policy

## Unterstützte Version

| Branch | Support |
|---|---|
| `master` | ✅ aktiv entwickelt |

Hugin ist ein privates Ein-Personen-Projekt; es gibt keine gepflegten Altvversionen.

## Schwachstelle melden

**Bitte nicht über öffentliche Issues melden.**

Nutze stattdessen **GitHub → Security → „Report a vulnerability"** (Private Vulnerability Reporting) — nur du und der Maintainer sehen die Meldung. Alternativ: Security Advisory im Repo anlegen.

Erwartung: Beschreibung + Reproduktionsschritte + betroffene Datei/Verhalten. Eine Antwort innerhalb weniger Tage ist realistisch.

## Was dazugehört

- **Pfad-Containment:** Alle Dateioperationen laufen durch `FileTools.resolve()` (lexikalischer `..`-Check **und** reale Symlink-Prüfung); der Agent kann die Freigaben nicht verlassen.
- **Kein Löschen:** Es existiert kein Lösch-Werkzeug.
- **Überschreiben:** nur mit Halten-Bestätigung (1,2 s) + automatischer Sicherungskopie; das Bestätigungsgate hängt niemals am LLM-Argument (`overwrite` wird ignoriert).
- **API-Key:** ausschließlich iOS-Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) — nie im Code, Repo oder CI-Logs.
- **Netzwerk:** nur `https://api.anthropic.com` (ATS-konform, ephemeral URLSession ohne Disk-Cache).
- **On-device:** Foundation Models verarbeiten Dateiinhalte offline — im Modus „Im Haus" verlässt nichts das Gerät.

## Automated Checks

Dieses Repository nutzt:

- GitHub **Secret Scanning + Push Protection** (blockiert versehentliche Token-Pushes)
- **Gitleaks** über die komplette Historie (siehe `security.yml`)
- **CodeQL** Code-Scanning für Swift (macOS-Runner)
- **Dependabot** für GitHub Actions
- CI-Tests auf jedem Push (`ci.yml`)

## Font-Lizenzen

Die mitgelieferten Schriftarten (Geist, Geist Mono) stehen unter der SIL Open Font License 1.1 — siehe [`docs/design/fonts/OFL-LICENSE.txt`](docs/design/fonts/OFL-LICENSE.txt).
