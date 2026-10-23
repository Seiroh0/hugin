# Hugin Design-System (aus Nutzer-Design extrahiert)

Quelle: `docs/design/page-*.html` (6 Boards, wörtlich gelesen). Dieses Dokument ist die verbindliche Referenz für alle UI-Tasks. Ausführende Agenten lesen die Boards für Details selbst.

## 1. Farben

| Name | Hex | Rolle |
|---|---|---|
| Basalt | `#0E0F12` | App-Grund (Hintergrund) |
| Schiefer | `#1D1F24` | Flächen (aktive Listen-Zeilen, Chips) |
| Seitenleiste | `#121317` | Sidebar-BG, Border rechts `#23252B` |
| Karten | `#131418` (Cards), `#16171B` (Composer/Running-Pill), `#17181C` (Dialog) | Ebenen |
| Knochen | `#ECE6D9` | Text, Primär-Buttons (BG Knochen, Text Basalt) |
| Asche | `#9A958B` | Sekundärtext, Labels |
| **Glut** | `#EE9A3C` | **lokal / on-device** (Akteur-Farbe) |
| Glut-Highlight | `#F7BE6E` | hervorgehobene Wörter, Hover |
| **Frost** | `#BEE4F0` | **Claude** (Akteur-Farbe) |
| **Rost** | `#E0613F` | Fehler/Stockt |
| Borders | `#23252B` `#2A2C33` `#3A3D45` (aufsteigend) | Konturen |
| Overlay | `rgba(6,7,9,.7)` | Modal-Backdrop |

Farb-Logik: **„Farbe sagt, wer denkt"** – Glut = iPad, Frost = Claude, Knochen = wartet auf dich, Rost = etwas hakt. Diese Zuordnung gilt überall (Wisp, Flugbahn-Knoten, Fundstück-Punkte, History-Zeilen).

## 2. Typografie

- **Geist** (OFL, Vercel): Oberfläche, Titel, Aufträge, Labels – Titel 600, Body 400/500
- **Geist Mono**: Werkzeuge, Pfade, Zeiten, Micro-Labels (11–12 px, letter-spacing .14em, UPPERCASE)
- Titel: neg. letter-spacing (−0.01 bis −0.045em)
- Bundling: beide Fonts als TTF ins App-Bundle (UIAppFonts), OFL-Lizenz beilegen (`docs/design/fonts/` Referenz, Original von Vercel GitHub für volle Familien)
- iOS-Integration: `.custom("Geist", size:)` / `.custom("GeistMono", size:)`

## 3. Wisp (Status-Licht) – 7 Zustände

Kern: kleiner Kreis mit Radial-Gradient (Core `#FFF4E0→#F7BE6E→#EE9A3C` für Glut / `#FFFFFF→#E2F4FA→#BEE4F0` für Frost) + Halo.

| Zustand | Farbe | Bewegung | Timing |
|---|---|---|---|
| Ruhe | Glut | Atmen + leichtes Treiben (drift) | 4,2 s ease-in-out ∞ |
| Denkt | Glut | schneller Puls, 4 Funken umkreisen (gegenläufig) | Puls 1,1 s, Funken 0,8–4,8 s |
| Fliegt | Glut | gleitet mit Lichtspur zum nächsten Knoten | 520 ms (.2,.8,.2,1) |
| Übergabe | Glut→Frost | Aufflammen, dann Farbwechsel | Flare 180 ms + Farbe 600 ms |
| Wartet | Knochen | Ringe laufen nach außen (2 versetzt) | 1,6 s ease-out |
| Stockt | Rost | unruhiges Flackern | 2,2 s |
| Fertig | Glut | Licht sinkt in Knoten, Punkt bleibt | 700 ms ease-in |

**Reduced Motion** (Accessibility): keine Wege/Orbits, nur Farb- und Helligkeits-Blends (240 ms). iOS: `@Environment(\.accessibilityReduceMotion)`.

## 4. Motion-Tokens (SwiftUI-Äquivalente)

| Token | Kurve | Dauer | Einsatz |
|---|---|---|---|
| Gleiten | cubicBezier(.2,.8,.2,1) ≈ `smoothEase` | 520 ms | Licht zwischen Knoten, Panels |
| Atmen | (.37,0,.63,1) | 4,2 s ∞ | Ruhe, Warten |
| Aufflammen | (.3,0,.1,1) | 180 ms | Übergabe, Senden |
| Einsinken | (.42,0,1,1) | 700 ms | Knoten fertig |
| Aufblenden | (0,0,.58,1) | 240 ms | neue Zeilen, Sheets |
| Halten-Füllung | linear | 1200 ms (Zurücksetzen 240 ms) | Bestätigen-Knopf |

Mikro-Momente: Senden (Flare→Gleiten), Neuer Schritt (Aufblenden+Gleiten), Knoten fertig (Einsinken), Übergabe (Flare+Frost), Halten (linear 1,2 s).

## 5. Layout

### 5.1 Seitenleiste (260 px)
- Wortmarke „hugın" (30 px, 600, −0.045em; Wisp als Punkt über dem ı, orange Glow)
- Button „Neuer Auftrag" (＋, Outline `#3A3D45`, Radius 12, minH 44)
- **Freigaben**: Ordnerliste (Icon, Name, Dateizahl in Mono) + „Ordner freigeben…"
- **Munin · Erinnerung**: Auftrags-Historie (Titel + „wann · lokal/Claude"); laufender Auftrag: Zeile mit aktiven Wisp, „läuft · Claude", Schiefer-BG
- Unten: Einstellungen (Slider-Icon)

### 5.2 Start
- Schwebender Wisp (drift) + gepunktete Flugkurve (SVG)
- H1 56 px: „Was soll ich für dich **erledigen**?" („erledigen" in `#F7BE6E` mit handgezeichneter Unterstreichung, Glut)
- Mono-Sub mit 2-px-Glut-Border links: „Ich arbeite nur in deinen Freigaben. Gelöscht wird nichts."
- **Composer-Card**: `#16171B`, Border `#3A3D45`, Radius 26/26/26/6 (Sprechblase mit unten links Ecke 6), Glow-Schatten rgba(238,154,60,.04) ×6
  - Textarea 22 px „Auftrag beschreiben …"
  - Zeile: **Botengang-Knopf** (Pill, Mini-Wisp + Modus + Chevron) · „Alle Freigaben"-Chip (Ordner-Icon) · Senden (46-px-Kreis, Knochen, Pfeil hoch)
- **Botengang-Menü** (Dropdown 384 px, Card-Radius 22/22/22/6): Titel „Wie weit soll Hugin fliegen?" + Flugbahn-SVG (iPad links als kleines Rechteck, Claude rechts als gestrichelter Kreis, Bogen dazwischen; Wisp-Knoten wandert je Modus; Route einfärben Glut→Frost) + 3 Optionen:
  - **Im Haus** · nur iPad – „offline, privat, schnell. Keine Datei verlässt das iPad." (Glut)
  - **Nach Bedarf** · lokal, sonst Claude – „Hugin startet lokal und holt Claude nur dazu, wenn ein Auftrag zu schwer wird. Jede Übergabe siehst du in der Flugbahn." (Glut→Frost-Gradient)
  - **Zu Claude** · Cloud – „Hugin trägt den Auftrag direkt zu Claude. Für schwere Aufträge; nur die nötigen Dateien verlassen das iPad." (Frost)
  - Gewählt: BG `#22211F`, Border Glut; ungewählt: BG `#1B1C21`, Border `#2A2C33`; Hover: Border Glut
  - Fuß: Mono-Beschreibung des gewählten Modus
- **Vorschläge**: 3 Beispiel-Aufträge (→-Icon, Glut), Zeilen mit gestrichelten Trennern, Hover: Text `#F7BE6E` + Einzug

### 5.3 Auftragsansicht („Flugbahn")
- Header: „Auftrag · <Freigabe>" (Mono-Label) + Titel 22 px + Running-Pill (Mini-Wisp + Akteur + „Schritt 5/6 · 0:14" Mono) + „Anhalten" (Stop-Quadrat, Outline-Pill)
- Nutzer-Nachricht groß (26 px) mit Mono-Label „DU · 14:02"
- **Timeline** (ol): pro Schritt links 2-px-Connector (Glut bei lokal, Frost bei Claude, gemischt bei Übergabe), Knoten-Punkt (Kreis mit Glut-Kern; aktueller Schritt: Wisp mit Orbit-Funken + Ladebalken; Übergabe: rotierter Diamant mit Frost-Border + Glut-Fill + Glow)
  - Zeile: Mono-Label 92 px (SUCHEN/LESEN/ÜBERGABE/BERICHT/BESCHREIBUNG, Farbe = Akteur) + Beschreibung + rechts Mono-Dauer („0,4 s" / „läuft")
  - SUCHEN: Datei-Chips (Mono 12 px, Icon, Border `#2A2C33`, BG `#131418`)
  - ÜBERGABE: Erklärtext + „nur diese Datei verlässt das iPad"
  - Neuer Schritt: Aufblenden 240 ms
- Unten: **Queue-Bar** „Nächsten Auftrag schon vormerken …" (Card-Stil, Knochen-Sende-Kreis)
- **Fundstück-Aside** (290 px, `#111216`): Datei-Kopf + Extraktions-Karte (Radius 6/18/18/18, inset-Top-Glut-Shadow, Mono, hervorgehobene Summe in Frost-Box) + „BISHER GEFUNDEN"-Liste mit Akteur-Punkten (Glut=lokal gelesen, Frost=Claude gelesen) + Laufende Summe. Legende: „Punktfarbe = wer es gelesen hat."

### 5.4 Überschreiben-Dialog (Modal)
- Backdrop rgba(6,7,9,.7); Card 620 px `#17181C`, Radius 28, Shadow 0 40 120
- Kopf: Wisp „Wartet" (Knochen-Ringe) + Mono „WARTET AUF DICH"
- Titel 28 px „<Datei> überschreiben?" + Sub: „Die Datei gibt es schon in <Freigabe>. Hugin möchte sie durch die neue Fassung ersetzen."
- **Diff-Vorschau** (Mono 13, BG `#0F1013`, Radius 14): Zeilen mit Vorzeichen; entfernt = Rost-Tint, hinzugefügt = Frost-Tint
- Backup-Box (Schiefer, Archiv-Icon): „Vorher wird eine Sicherung angelegt" + Mono-Pfad `Sicherungen/<Datum_Uhrzeit>/<Datei>`
- Buttons: „Abbrechen" (Outline) + **„Zum Überschreiben halten"**: 1,2 s halten; Fortschrittsring (42 px SVG, dasharray 106.81) + oranger Füllbalken von links; Label „Weiter halten …" → „Überschrieben · Sicherung angelegt ✓"; Loslassen setzt sanft zurück (240 ms); danach „Nochmal zeigen"
- Keyboard: Space/Enter halten; `touch-action: none` (iOS: Long-Press-Gesture)

### 5.5 App-Icon (1024²)
SVG liegt in `page-b7cb6c52…html`: BG-Gradient `#1D1E23→#0A0B0D` (rx 230), Filmkorn 7 %, zwei abgerundete Stäbe (72×552, x=318/634, y=236, rx 36, Stahl-Gradient `#383B42→#1F2126` mit Kante `#50535B`), aufsteigende Lichtspur (Pfad `M352.7 648.5 L653.1 360.2 A26 26 0 0 1 686.9 399.8 L355.3 651.5 Z`, Glut-Gradient → `#FFD9A0`, doppelt mit Blur 18), Glow-Kreise + Kern `#FFF8EC` bei (670,380). Varianten: Dunkel (Standard), Hell (`#F4EFE4→#E2DACA`, Stäbe `#CBC1AE`, Spur `#D47A22`, Kern `#FFF4E2`), Getönt (Grau + Weiß). Tagline: „Der Gedanke, der für dich ausfliegt."

## 6. Komponenten (SwiftUI-Zielstruktur)

1. `WispView` (state: actor + zustand) – Kern+Halo, Animationen nach §3, ReduceMotion
2. `SidebarView` – Wortmarke, Neuer Auftrag, Freigaben (Name+Zahl), Munin-Historie (inkl. laufend), Einstellungen
3. `ComposerCard` + `BotengangMenu` (Moduswahl mit Flugbahn-SVG)
4. `StartView` – Wisp, H1, Composer, Vorschläge
5. `OrderView` – Header (Running-Pill, Anhalten), Nutzer-Nachricht, `FlugbahnTimeline` (StepNode je ActionCard-Typ), Queue-Bar
6. `StepNode` (kind, actor, dauer, läuft) – Connector, Knoten, Chips, Übergabe-Diamant
7. `FundstueckView` – P2 (braucht Findings-Stream aus Agent-Loop)
8. `ConfirmOverwriteDialog` – Wisp wartet, DiffView, Backup-Box, `HoldToConfirmButton` (1,2 s)
9. `DiffView` – einfacher Zeilen-Diff (alt vs. neu)
10. `HuginTheme` – Farben, Fonts, Radien, Schatten, Motion-Tokens als Swift-Konstanten

## 7. Accessibility & Regeln

- Min-Touch 44 px überall, Fokus-Ringe (Knochen), `prefers-reduced-motion` → nur Blends
- Keine reinen Farbcodes ohne Text: Übergabe hat immer Erklärtext; Punktfarben haben Legende
- Deutsch, Du-Form; Mono-Labels UPPERCASE
