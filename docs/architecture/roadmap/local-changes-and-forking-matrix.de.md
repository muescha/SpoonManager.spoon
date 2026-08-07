# Lokale Änderungen & Fork — Entscheidungsmatrix

Fokussierte Priorisierung für den Themenblock „der Nutzer hat einen installierten
Spoon verändert".

**Kern-Erkenntnis:** Das ist ein 3-Wege-Diff — BASELINE (was installiert wurde)
vs. LOCAL (jetzt auf der Platte) vs. UPSTREAM (neueste Version). BASELINE→LOCAL
sind die Änderungen des Nutzers, BASELINE→UPSTREAM ist das Update. Alles hängt
daran, eine Baseline herzustellen.

**Baseline-Quellen, nach Verlässlichkeit sortiert:**

1. Pristine aus bekannter Quelle neu laden (der Adopt-Flow) — authoritativ.
2. Die eigene git-Historie des Nutzers, falls `~/.hammerspoon` getrackt ist — stark, opportunistisch.
3. Upstream-Revision per Install-Datum + Best-Content-Match rekonstruieren — mittel.

Legende: **Aufwand** S/M/L · **Nutzen** niedrig/mittel/hoch · **Fundament** = Basis, die anderes ermöglicht.

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
| 26 | Auto-GitHub-Push | Repo + Push automatisch | Zieht Token-/Auth-Verwaltung & nach-außen-Aktionen rein. Stattdessen: fertigen Befehl generieren, Nutzer pusht selbst. | Nein |
| 27 | Blind-Detect | ohne Baseline & Quelle | Änderungen ohne jeden Vergleichspunkt erkennen — logisch unmöglich. Immer über Adopt (19) lösen. | Nein |

## Erste Welle

Zuerst 17 und 18 bauen (das Fundament: Backup-Sicherheit + Fingerprint-Baseline),
dann der Trenn-Kern 19–21. Punkte 22–25 sind die nächste Stufe; 26–27 sind
außerhalb des Scopes.
