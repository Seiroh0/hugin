# Hugin
KI-Datei-Agent fürs iPad (Details: docs/superpowers/specs/…-design.md)

## Installation (ohne Mac)
1. **GitHub-Repo anlegen** (public empfohlen – macOS-CI gratis, keine Secrets im Repo) und pushen:
   `git remote add origin <REPO-URL>` → `git push -u origin master`
2. **CI abwarten**: GitHub-Repo → Tab „Actions“ → neuesten Lauf anklicken → ganz unten unter „Artifacts“ `Hugin-unsigned.ipa` herunterladen (ggf. über Tailscale auf den PC holen)
3. **Sideloadly** (sideloadly.io, Windows) installieren; iTunes-Treiber mitinstallieren lassen. Sideloadly ist ein Tool, das Apps ohne App-Store aufs iPad bringt – die Apple-ID braucht es nur zum Signieren der App auf deinem PC
4. iPad per **USB** an den PC, Sideloadly starten: IPA wählen → Apple-ID eintragen → Install
5. iPad: **Einstellungen → Allgemein → VPN & Geräteverwaltung** → Apple-ID-Profil → **Vertrauen**
6. App starten → Einstellungen → Claude-API-Key eintragen, Ordner freigeben

**Gratis-Apple-ID:** App läuft 7 Tage, dann Schritt 4 wiederholen (Daten bleiben).
**Nur zur eigenen Nutzung** – kein App-Store-Vertrieb.

**Hinweis:** Ein öffentliches Repo macht auch die Dokumentation (Spec/Plan) öffentlich – wer das nicht möchte, wählt ein privates Repo (macOS-CI-Minuten sind dann begrenzt).
