# Ideen-Roadmap

Eine Übersicht aller für SpoonManager gesammelten Ideen — durchnummeriert, mit
Aufwand- und Nutzenschätzung und einem Verdict, ob sich die Umsetzung lohnt. Sie
fasst die geplanten Notizen unter `../planned/` zusammen; nichts davon ist bisher
implementiert.

Legende:

- **Aufwand** — S klein, M mittel, L groß.
- **Nutzen** — niedrig, mittel, hoch.
- **Fundament** — eine Basis, die andere Arbeit ermöglicht.
- **Verdict** — Ja (bauen), Später, Optional, Nein (außerhalb Scope).

## A. Struktur & Hosting

Siehe `../planned/repository-structure-and-hosting.md`.

| # | Idee | Stichwort | Beschreibung | Aufwand | Nutzen | Verdict |
|---|------|-----------|--------------|:-------:|:------:|---------|
| 01 | Repo-Split | Zwei Repos | Tool (`spoonmanager`) und Community-Katalog (`spoonify`) getrennt — PR-Ströme kollidieren nie. | S | Hoch | Ja · Fundament |
| 02 | Struktur-Umbau | Monorepo | `Source/SpoonManager.spoon`, `Spoons/*.zip`, Release-ZIP fürs Bootstrap. Spiegelt Hammerspoon/Spoons. | M | Mittel | Ja · Fundament |
| 03 | Root-Manifest | Auto-Discovery | `spoonify.json` im Repo-Root als feste Fundstelle — wie `package.json`. | S | Mittel | Ja · Fundament |
| 04 | Pages-Hosting | GitHub Pages | `website/` via Actions deployen — kostenlos, keine Domain nötig. | S | Mittel | Ja · Fundament |
| 05 | Eigene Domain | .de-Domain | ~3,71 €/Jahr, CNAME auf Pages. Nett, aber nicht nötig — jederzeit nachrüstbar. | S | Niedrig | Optional |

## B. Discovery & Distribution

Siehe `../planned/discovery-website-and-gui.md`.

| # | Idee | Stichwort | Beschreibung | Aufwand | Nutzen | Verdict |
|---|------|-----------|--------------|:-------:|:------:|---------|
| 06 | Katalog-Repo | spoonify-Index | Zentraler Index vieler Manifeste, per Pull-Request kuratiert. | M | Hoch | Ja |
| 07 | Schema-Validierung | CI-Gate | JSON-Schema + Action prüft jeden PR: gültig, nur erlaubte Quellen, keine lokalen Pfade. | M | Hoch | Ja |
| 08 | Such-Website | brew.sh-Style | Statische Seite + JSON-Feed, Client-Suche (Fuse.js). Kein Backend, keine laufenden Kosten. | M | Hoch | Ja |
| 09 | Copy-Snippets | JSON / Lua | Config-JSON oder Builder-Lua je Treffer kopieren — aus dem Schema generiert (kein Drift). | S | Hoch | Ja |
| 10 | One-Click-Import | hammerspoon:// | URL-Schema via `hs.urlevent` → Ein-Klick-Install. Bestätigungsdialog Pflicht (RCE-Risiko). | M | Hoch | Ja |
| 11 | In-App-GUI | chooser / webview | Suchen und installieren direkt in Hammerspoon. Reicher, aber größeres Stück Arbeit. | L | Mittel | Später |
| 12 | Webview-Reuse | Seite = GUI | Gehostete Website in `hs.webview` laden → UI nicht doppelt bauen. Install via URL-Schema. | S | Mittel | Ja |
| 13 | Kein-init.lua-Install | GUI ohne Code | Installierte Spoons beim Start aus dem Registry laden — Nutzer fasst `init.lua` nie an. | M | Hoch | Ja |

## C. Zustand & Registry

Siehe `../planned/registry-history-status.md`.

| # | Idee | Stichwort | Beschreibung | Aufwand | Nutzen | Verdict |
|---|------|-----------|--------------|:-------:|:------:|---------|
| 14 | Installed-Registry | Was ist installiert | Persistenter „letzter erfolgreicher Stand" — Basis für Diff, GUI, Status und Kein-init.lua. | M | Hoch | Ja · Fundament |
| 15 | History-Log | Versuche | Versuche/Fehler getrennt vom Installstand protokollieren — für Timeline und Troubleshooting. | M | Mittel | Später |
| 16 | Status-View | Statusobjekt | Abgeleitete Sicht (installed / loaded / localChanges / updateAvailable) — eine View, nicht die Wahrheit. | S | Mittel | Später |

## D. Lokale Änderungen & Fork

Siehe `../planned/local-changes-and-forking.md`. Eine fokussierte
Entscheidungsmatrix für diesen Block liegt zusätzlich als eigenständiges
Deliverable vor (Markdown und HTML, Englisch und Deutsch).

| # | Idee | Stichwort | Beschreibung | Aufwand | Nutzen | Verdict |
|---|------|-----------|--------------|:-------:|:------:|---------|
| 17 | Backup + Fresh-Diff | Sicher & simpel | Vor jedem Update sichern, dann gegen Frisch-Install diffen. Pragmatischer Default — zuerst bauen. | S | Hoch | Ja · Fundament |
| 18 | Fingerprint | Baseline @ Install | Hash je Datei + `sourceRevision` speichern → „lokal verändert: ja/nein". Basis für den 3-Wege-Diff. | S | Hoch | Ja · Fundament |
| 19 | Adopt-Flow | Nachträglich übernehmen | Bei manuell installierten Spoons: Quelle nennen → Baseline anlegen + Erst-Diff. Löst das Kernproblem. | M | Hoch | Ja |
| 20 | 3-Wege-Diff | Edit vs. Update | Baseline / Local / Upstream trennen → „meine Änderung" vs. „Update" vs. „Konflikt". | M | Hoch | Ja |
| 21 | Änderungs-Schutz | Bewusst überspringen | Update zeigt Diff statt blind zu skippen — der Nutzer entscheidet informiert. | S | Mittel | Ja |
| 22 | User-Git-History | Config in git | Falls `~/.hammerspoon` git-getrackt ist: vorhandene Historie als starke Baseline nutzen. | M | Mittel | Optional |
| 23 | History-Rekonstruktion | Stand zum Datum | Upstream-Revision per Install-Datum + Best-Content-Match finden. Robust, aber Kür. | L | Mittel | Später |
| 24 | Git-Backing | git unter der Haube | Spoon als git-Repo, pristine als erster Commit → diff/merge/Konflikte gratis. Schwerer — abwägen. | L | Mittel | Später |
| 25 | Fork-Helfer | Eigener Spoon | Edits als Commits, Quelle auf Fork umbiegen. Rename `Tool→MeinTool` nur best-effort + Push-Befehl generieren. | M | Mittel | Später |

## Verworfen / außerhalb Scope

| # | Idee | Stichwort | Warum nicht | Verdict |
|---|------|-----------|-------------|---------|
| 26 | Auto-GitHub-Push | Repo + Push automatisch | Zieht Token-/Auth-Verwaltung und nach-außen-Aktionen rein. Stattdessen: fertigen Befehl generieren, Nutzer pusht selbst. | Nein |
| 27 | Blind-Detect | ohne Baseline & Quelle | Änderungen ohne jeden Vergleichspunkt erkennen — logisch unmöglich. Immer über Adopt (19) lösen. | Nein |

## Zusammenfassung

Aktive Ideen: 25 — 17 Ja, 6 Später, 2 Optional. Verworfen: 2.

Empfohlene erste Welle: die Fundament-Ideen (01–04, 14, 17, 18) schalten fast
alles andere frei. Danach der Discovery-Kern (06–10) und der Local-Changes-Kern
(19–21).
