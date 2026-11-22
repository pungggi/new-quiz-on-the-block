# Recherche: Best Practices für Godot & GDAI MCP im KI-gestützten Workflow

**Stand:** 2026-11-22
**Zielgruppe:** Entwicklung von "New Kids on the Block" (Godot 4.7.2, Forward+, GDScript strict typed)
**Methode:** Tiefenrecherche gegen Primärquellen (offizielle Godot-Docs, GDAI-MCP-Dokumentation, MCP-Spezifikation, OWASP, Vergleichstests)

---

## 1. Kernaussage in Kürze

- **Der Loop zählt, nicht das Modell:** Jeder KI-gestützte Godot-Workflow ist derselbe 4-Stufen-Loop: Intent → Edit → Run → Feedback. Die beiden schwachen Ränder sind Kontext (die KI sieht das Projekt nicht) und Feedback (der Mensch ist der Test-Runner).
- **GDAI MCP schließt den Kontextrand:** Es gibt der KI die echte Szene, den Baum, die Fehler und Screenshots statt geratener Node-Pfade.
- **Der Feedbackrand muss man aktiv schließen:** Erst wenn die KI selbst `play_scene` ausführt, `get_godot_errors` liest und Screenshots auswertet, wird aus "Code geschrieben" "Feature funktioniert".
- **Godot-3-Drift ist das Dominant-Fehlerbild:** Die häufigsten KI-Fehler sind umbenannte Klassen und geänderte Signaturen, nicht falsche Spiellogik.
- **Sicherheit ist nicht optional:** GDAI MCP läuft als Editor-Plugin mit vollem Projektrecht, inklusive `execute_editor_script`. Least Privilege, Tool-Disable-Flags und Human-in-the-Loop sind Pflicht, nicht Nice-to-have.

**Quellen:** [Summer Engine: Godot AI Workflow 2026](https://www.summerengine.com/blog/godot-agentic-coding), [GDAI MCP Doku](https://gdaimcp.com/docs/), [OWASP MCP Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html)

---

## 2. Der 4-Stufen-Loop: Warum Kontext und Feedback entscheiden

Jedes AI-Workflow in der Spieleentwicklung zerfällt in vier Stufen:

1. **Intent:** Die Änderung beschreiben ("Dash für den Spieler", "Warum setzt sich der Score bei Szenenwechsel zurück?").
2. **Edit:** Die KI schreibt/ändert GDScript, Nodes, Input-Actions, Ressourcen.
3. **Run:** Jemand drückt Play. Der Sprung fühlt sich schwammig an, eine Nullreferenz crasht in Welle 3, der Dash klemmt an Wänden.
4. **Feedback:** Das Ergebnis des Runs wird zum nächsten Intent.

**Warum das zählt:** Die meisten Godot-Bugs sind Runtime-Bugs, keine Linter-Fehler. Timing, Physik, Signal-Reihenfolge, Nullreferenzen auf freigegebene Nodes, Werte die sich falsch anfühlen statt falsch zu parsen. Der relevante Fehler erscheint im laufenden Spiel, nicht in der Datei.

**Konsequenz für den Workflow:**

- **Kontextrand:** Ohne Zugriff auf die echte Szene erfindet die KI `$Player/Sprite2D`, obwohl der Node `PlayerSprite` heißt. GDAI MCP's `get_scene_tree`, `get_scene_file_content` und `view_script` liefern die reale Struktur.
- **Feedbackrand:** Ohne `play_scene` + `get_godot_errors` + Screenshots ist die KI "fast autocomplete with extra steps" und der Mensch schließt jede Iteration von Hand.

**Quelle:** [Summer Engine: The Godot AI Workflow in 2026](https://www.summerengine.com/blog/godot-agentic-coding)

---

## 3. GDAI MCP: Fähigkeiten und Grenzen

### 3.1 Was GDAI MCP ist

- MCP-Server für **Godot 4.2+**, der dem AI-Client (Claude, Cursor, VS Code, Codex, Open WebUI) Kontrolle über den Godot-Editor gibt.
- **Closed Source, $19 einmalig**, ~31 Tools (kleinere Auswahl als z.B. Godot MCP Pro mit 187).
- Läuft als **Editor-Plugin unter `res://addons/gdai-mcp-plugin-godot/`** plus Python-Server (`gdai_mcp_server.py`, gestartet via `uv`).
- **Streamable HTTP** (ab v0.3.3, `http://127.0.0.1:9090/mcp`) oder stdio-Transport.
- Empfohlene Editor-Einstellungen: `Auto Reload Scripts on External Change` und `Auto Reload and Parse Scripts on Save`.

**Quellen:** [GDAI Introduction](https://gdaimcp.com/docs/), [GDAI Installation](https://gdaimcp.com/docs/installation)

### 3.2 Tool-Kategorien (Auszug, vollständig in der [Tool-Liste](https://gdaimcp.com/docs/supported-tools))

| Kategorie | Relevante Tools | Nutzen im AI-Workflow |
|---|---|---|
| **Projekt** | `get_project_info`, `get_filesystem_tree`, `search_files`, `uid_to_project_path`, `project_path_to_uid` | Kontextrand: die KI versteht die echte Projektstruktur und UID-Referenzen |
| **Szene** | `get_scene_tree`, `get_scene_file_content`, `create_scene`, `add_scene`, `play_scene`, `stop_running_scene` | Kontext + Feedbackrand: echte Node-Hierarchie lesen, Spiel starten/stoppen |
| **Node** | `add_node`, `delete_node`, `duplicate_node`, `move_node`, `update_property`, `add_resource`, `set_anchor_preset/Values` | Strukturelle Änderungen ohne Rätselraten |
| **Script** | `view_script`, `create_script`, `attach_script`, `edit_file` | Gezielte Code-Änderungen am realen File |
| **Editor** | `get_godot_errors`, `get_editor_screenshot`, `get_running_scene_screenshot`, `execute_editor_script`, `clear_output_logs` | **Feedbackrand:** Fehler lesen, Editor/Spiel visuell prüfen, Editor-Scripte ausführen |

### 3.3 Konfiguration und Granularität

- **Ports:** `GDAI_MCP_SERVER_PORT` (Default 3571), `GDAI_RUNTIME_SERVER_PORT` (Default 3572, z.B. für `simulate_input`), konfiguriert in `gdai_mcp_project_config.json` (via "Override Config" in der GDAI-MCP-Tab).
- **Tool-Disable-Flags:** Jedes Tool kann per `GDAI_DISABLE_<TOOLNAME>: "YES"` abgeschaltet werden. Das ist der Low-Level-Mechanismus für Least Privilege.
- **Nach Config-Änderung:** Godot-Editor neu starten und die aktualisierte MCP-Server-JSON aus der GDAI-MCP-Tab kopieren.

**Quelle:** [GDAI Configuration](https://gdaimcp.com/docs/configuration)

### 3.4 Grenzen und Risiken

- **`execute_editor_script` führt beliebiges GDScript im Editor aus** mit vollen Projektrechten. Das ist mächtig (z.B. Batch-Refactors) und gefährlich (Prompt-Injection → Datei-/Prozesszugriff).
- **`edit_file` ist ein Find-and-Replace ohne Undo-Garantie.** Im Gegensatz zum manuellen Editor-Ctrl+Z muss die KI Änderungen selbst nachvollziehbar machen (Diff vorher/nachher).
- **Screenshots sind visuelles Feedback, kein Beweis für Spielmechanik.** Ein hübsches Bild sagt nichts darüber, ob der Dash klemmt. Gameplay-Verifikation braucht zusätzlich Input-Simulation und Log-Auswertung.
- **HTTP-Transport hat keinen eingebauten Login.** Die GDAI-Doku warnt ausdrücklich: nur in vertrauenswürdigen Netzwerken nutzen; `0.0.0.0` nur mit bewusster Entscheidung.

**Quellen:** [GDAI Supported Tools](https://gdaimcp.com/docs/supported-tools), [GDAI Installation (HTTP-Hinweis)](https://gdaimcp.com/docs/installation)

---

## 4. Godot-4-Drift: Das Dominant-Fehlerbild bei KI-Ausgabe

LLMs sind mit Godot 3 trainiert; Godot 4 hat einen großen Teil umbenannt. Das Ergebnis: flüssig klingender Code, der nicht kompiliert oder falsch läuft.

### 4.1 Die sechs "ein Blick"-Checks gegen Godot-3-Output

1. Steht `@` vor `export` und `onready`? Ohne `@` ist es Godot 3.
2. Hat `move_and_slide()` Argumente? In Godot 4: **keine** (liest `velocity`/`up_direction` als Properties).
3. Enthält ein `connect(`-Aufruf einen Methodennamen als String? Godot 4: `pressed.connect(_on_pressed)`, kein String.
4. Endet der Klassenname mit `Body2D` wo `CharacterBody2D` gemeint ist, oder fehlt das `3D`-Suffix?
5. Existieren alle referenzierten Klassen/Methoden in der Class Reference der **tatsächlich genutzten** Godot-Version?
6. Läuft die Szene? Ohne Lauf zählt nichts.

### 4.2 Die häufigsten Renames (Auszug)

| Godot 3 (stale) | Godot 4 |
|---|---|
| `KinematicBody2D` | `CharacterBody2D` |
| `Spatial` | `Node3D` |
| `Position2D` | `Marker2D` |
| `change_scene()` | `change_scene_to_file()` |
| `instance()` | `instantiate()` |
| `connect("hit", self, "_on_hit")` | `hit.connect(_on_hit)` |
| `yield()` | `await` |
| `File` / `Directory` | `FileAccess` / `DirAccess` |

### 4.3 Prompting, das Drift unterdrückt

- **Version pinnen:** "Godot 4.7, GDScript mit Type Hints" direkt in die Anfrage.
- **API-Shape erzwingen:** "CharacterBody2D-Skript mit `velocity`-Property und `move_and_slide()` ohne Argumente."
- **Echtes Projektbeispiel mitschicken:** Ein bestehendes Skript mit `@export` und typisierten Signaturen zeigt Stil und Naming.
- **Annahmen benennen lassen:** "Nenne deine Annahmen zu Szene und Engine-Version" macht falsche Annahmen früh sichtbar.

**Quellen:** [GodotLearning: Can AI Write GDScript?](https://godotlearning.com/blog/ai-write-gdscript-llm-godot), [GodotLearning: AI Workflow](https://godotlearning.com/ai-workflow)

---

## 5. Offizielle Godot-Best-Practices als Agent-Regeln

Diese Regeln gehören in `AGENTS.md`, damit die KI nicht gegen die Engine-Konventionen arbeitet.

### 5.1 Szenen & Kopplung (Scene Organization)

- **Scenes möglichst ohne Abhängigkeiten designen:** Alles Nötige innerhalb der Szene halten.
- **Dependency Injection über den Parent:** Eltern initialisieren Kinder via Signal, Methode, Callable-Property, Node-Referenz oder NodePath.
- **Signale "up", Aufrufe "down":** Kind emittiert, Parent reagiert; Parent ruft Kind-Methoden zum Starten von Verhalten.
- **Loose coupling:** Geschwister-Knoten kennen sich nicht direkt; ein common ancestor vermittelt.
- **`_get_configuration_warnings()`** nutzen, um Abhängigkeiten im Editor selbst-dokumentierend zu machen statt via externer Doku.

**Quelle:** [Godot Best Practices: Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)

### 5.2 Autoloads vs. reguläre Nodes

- **Autoloads vermeiden, wenn möglich:** Globaler Zustand erschwert Debugging und Resource-Allocation.
- **Stattdessen:** `static func` + `class_name` für Bibliotheken, `static var` (ab 4.1) für geteilte Variablen, Szenen verwalten ihren eigenen State.
- **Autoloads sind ok** für breit-scoped Systeme (Quest-, Dialog-Systeme), die ihren eigenen State verwalten und nicht in fremde Daten eingreifen.
- **Autoload ≠ Singleton:** Kopien sind erlaubt; nur automatisch als Root-Child geladen.

**Quelle:** [Godot Best Practices: Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html)

### 5.3 GDScript Style & Static Typing

- **Strict Typing:** Variablen, Argumente, Rückgaben typisieren; `-> void` bei Nichts-Rückgabe.
- **Signale typisieren:** `func _on_area_2d_body_entered(body: PhysicsBody2D) -> void`.
- **Formatting:** Tabs (keine Spaces), LF, UTF-8 ohne BOM, Zeilen < 100 Zeichen (Ziel < 80), Trailing Commas in Arrays/Dicts/Enums, zwei Leerzeilen um Funktionen/Klassen.
- **Boolean-Operatoren:** `and`/`or`/`not` statt `&&`/`||`/`!`.
- **Ein Statement pro Zeile** (Ausnahme: Ternary).
- **Code-Reihenfolge** (Classname, Extends, Signals, Enums, Exports, Vars, Onready, ...): konsistent halten, damit Auto-Formatter und Menschen lesbar bleiben.

**Quellen:** [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)

---

## 6. MCP-Sicherheit: Was für GDAI MCP konkret gilt

MCP erweitert die Angriffsfläche: Die LLM entscheidet selbst, welches Tool mit welchen Parametern aufgerufen wird, mit den Rechten des Entwicklers.

### 6.1 Die relevanten Risiken (OWASP)

- **Tool Poisoning:** Versteckte Anweisungen in Tool-Beschreibungen/Parametern, die das Modell steuern, aber der Mensch nicht sieht.
- **Rug Pull:** Ein Server ändert Tool-Definitionen nach initialer Freigabe.
- **Tool Shadowing / Cross-Origin Escalation:** Ein bösartiger Server manipuliert das Verhalten gegenüber *anderen* vertrauten Servern.
- **Confused Deputy:** Der Server führt Aktionen mit eigenen (breiten) Rechten aus, nicht mit denen des anfragenden Users.
- **Over-Scoped Tokens / Excessive Permissions:** Zu breite Rechte pro Server.
- **Supply Chain:** Ungeprüfte Community-Server aus README/Registry.
- **Sandbox Escapes:** Lokale MCP-Server mit vollem Host-Zugriff.

**Quelle:** [OWASP MCP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html)

### 6.2 Konkrete GDAI-MCP-Maßnahmen

- **Least Privilege über `GDAI_DISABLE_*`:** Nur die Tools freigeben, die der Workflow braucht. Für "nur Code lesen und fixen": `get_*`, `view_script`, `edit_file`, `get_godot_errors` reichen. `execute_editor_script` und `delete_*` erst freigeben, wenn der Use-Case feststeht.
- **Human-in-the-Loop für destruktive Aktionen:** `delete_scene`, `delete_node`, `execute_editor_script`, `edit_file` nie auto-approve; volle Parameter anzeigen, nicht nur den Tool-Namen.
- **Server-Definition pinnen:** MCP-Server per URL/Kommando in der Allowlist führen, Version pinnen, bei Änderung neu reviewen.
- **Repo-declared Config hinter Workspace-Trust:** Eine mitgelieferte `.mcp.json`/`.vscode/mcp.json` im Repo startet Server mit den Rechten des Entwicklers. Immer manuell prüfen.
- **HTTP nur localhost/vertrauenswürdig:** `127.0.0.1` statt `0.0.0.0`, außer bewusste Docker/Netzwerk-Entscheidung; dann Token/Netzwerk-Isolation ergänzen.
- **Tool-Schema als Injectionsurface behandeln:** Nicht nur `description`, sondern `inputSchema`/`annotations` reviewen; ein geflipptes `readOnlyHint`/`destructiveHint` ändert das Freigabeverhalten ohne sichtbare Textänderung.
- **Nach untrusted Content frische Session:** Tool-Ergebnisse können gefälschte Anweisungen enthalten, die in den Session-Summary überleben.
- **Sandbox/Egress:** MCP-Server-Prozesse mit minimalen FS-/Netzwerk-Rechten laufen lassen, wo der Client das unterstützt.

**Quellen:** [OWASP MCP Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html), [MCP Security Best Practices (2026-07-28)](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices), [Pixee: Secure AI Coding Agents (Nov 2026)](https://www.pixee.ai/blog/secure-ai-coding-agents)

---

## 7. Verifikation: Der Loop muss messbar schließen

### 7.1 Statische Checks (vor dem Run)

- `godot --headless --check-only --script <file>`: Nur parsen und beenden. **Achtung:** Zeigt nicht unbedingt die im Editor gesetzten GDScript-Warnungen (Forum-Bericht, Godot 4.6), und `--script` lädt laut Issue #78587 nicht immer Autoloads.
- **Exit-Code nicht trauen:** In Tests auf 4.7.2 endete ein Script-Error mit Exit-Code 0. Immer nach `SCRIPT ERROR` im Output suchen.
- **Formatter/Linter:** [scony/godot-gdscript-toolkit](https://github.com/scony/godot-gdscript-toolkit/) (Parser, Linter, Formatter) oder Asset-Library-Linter wie "Godot Gdscript Linter" für Quality-Checks jenseits des Parsers.
- **CI:** Headless-Import + Headless-Lauf + Fehler-Scan (Beispiel-Workflow: `chickensoft-games/setup-godot`, Import-Cache, Validierung).

**Quellen:** [Godot Command Line Tutorial](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html), [Voyager: Godot MCP comparison](https://voyager.so/blog/godot-mcp), [Godot Forum: CLI GDScript Warnings](https://forum.godotengine.org/t/cli-showing-gdscript-warnings/132160)

### 7.2 Runtime-Checks (der eigentliche Loop)

1. `play_scene` starten.
2. `get_godot_errors` lesen (Script-Errors, Debugger, Output).
3. `get_running_scene_screenshot` für visuellen Zustand.
4. Bei Bedarf `simulate_input` für konkrete Eingaben.
5. Ergebnis als nächster Intent; **nicht** bei "Datei geschrieben" stoppen.

**Faustregel:** Aus "the code is written" wird "the feature works" erst nach mindestens einem kompletten Run mit Fehler-Suche.

---

## 8. Politische/ökologische Einordnung

- **Godots AI-Policy betrifft nur Engine-Contributions:** Die Foundation verlangt menschlich authored Code für PRs am Engine-Repository, verbietet autonome Agent-Nutzung/Vibe-Coding dort und verlangt Offenlegung von AI-Anteilen. **Das gilt nicht für Spiele, die mit Godot gebaut werden.** Für "New Kids on the Block" ist der Workflow also uneingeschränkt zulässig.
- **Warum die Policy existiert (fürs eigene Team als Analogie):** Review-Last, Verantwortung für Code, Barrieren gegen Low-Effort-Slop. Übertragbar: Der Mensch muss jede KI-Änderung erklären und tragen können.

**Quelle:** [Godot: Changes to our Contribution Policies](https://godotengine.org/article/contribution-policy-2026/)

---

## 9. Konkrete Empfehlungen für dieses Projekt

### 9.1 Tooling-Setup

- **GDAI MCP als Kontext+Feedback-Server** installieren (`addons/gdai-mcp-plugin-godot`, `uv`, MCP-Client-Config aus der GDAI-Tab).
- **Editor-Einstellungen:** `Auto Reload Scripts on External Change` + `Auto Reload and Parse Scripts on Save` aktivieren.
- **Ports:** Defaults (3571/3572) beibehalten, nur bei Konflikt in `gdai_mcp_project_config.json` ändern; nach Änderung Editor neu starten.
- **Tool-Allowlist:** `gdai_mcp_project_config.json` mit `GDAI_DISABLE_*` auf den tatsächlich benötigten Satz reduzieren; `execute_editor_script` und `delete_*` defaultmäßig aus, gezielt freischalten.

### 9.2 Workflow-Regeln (in AGENTS.md)

- **Version immer nennen:** "Godot 4.7.2, GDScript strict typed" in jeder Anfrage.
- **Vier-Check-Scan** auf jeden KI-Code-Block anwenden (§4.1).
- **Kontext vor Edit:** Vor strukturellen Änderungen `get_scene_tree`/`get_scene_file_content` abfragen, nicht raten.
- **Feedback nach Edit:** Nach jedem nicht-trivialen Change `play_scene` + `get_godot_errors`; bei visuellen Features zusätzlich Screenshot.
- **Kleine, reviewbare Changes:** Nicht die ganze Architektur auf einen Schlag; jeder Change muss erklärbar bleiben.
- **Nicht delegieren:** Szenen-Ownership (wer hält State), Performance-Änderungen ohne Profiler-Beweis, Shader ohne Kompilat/Render-Check, Code den der Entwickler nicht erklären kann.

### 9.3 Sicherheits-Regeln

- MCP-Server **per URL/Kommando allowlisten und pinnen**, nie nur nach Name.
- **Repo-declared MCP-Config** (`.mcp.json` etc.) manuell prüfen, nicht blind trauen.
- **Destruktive Tools** (`delete_*`, `execute_editor_script`, `edit_file`) mit Human-in-the-Loop, volle Parameter sichtbar.
- **HTTP-Transport** nur auf `127.0.0.1`; `0.0.0.0` nur mit bewusster Netzwerk-Entscheidung.
- **Nach untrusted Tool-Output frische Session** statt Compaction, wenn Rollen/Regeln erhalten bleiben müssen.

### 9.4 Verifikations-Pipeline

- **Pr:** `godot --headless --check-only` + GDLint/gdformat + Suche nach `SCRIPT ERROR` (Exit-Code nicht trauen).
- **Post-Edit:** `play_scene` → `get_godot_errors` → optional Screenshot/`simulate_input`.
- **CI:** Headless-Import + Headless-Lauf + Fehler-Scan in der Pipeline.

---

## 10. Quellenverzeichnis (Primärquellen)

| Quelle | URL | Typ |
|---|---|---|
| GDAI MCP Introduction | https://gdaimcp.com/docs/ | Offizielle Tool-Doku |
| GDAI MCP Supported Tools | https://gdaimcp.com/docs/supported-tools | Offizielle Tool-Liste |
| GDAI MCP Installation | https://gdaimcp.com/docs/installation | Offizielle Setup-Doku |
| GDAI MCP Configuration | https://gdaimcp.com/docs/configuration | Offizielle Config-Doku |
| Godot: Scene organization | https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html | Offizielle Engine-Docs |
| Godot: Autoloads versus regular nodes | https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html | Offizielle Engine-Docs |
| Godot: GDScript Style Guide | https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html | Offizielle Engine-Docs |
| Godot: Static typing | https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html | Offizielle Engine-Docs |
| Godot: Command Line Tutorial | https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html | Offizielle Engine-Docs |
| Godot: Contribution Policy 2026 | https://godotengine.org/article/contribution-policy-2026/ | Offizielle Foundation-Policy |
| MCP: Security Best Practices (2026-07-28) | https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices | Offizielle MCP-Spezifikation |
| OWASP: MCP Security Cheat Sheet | https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html | Sicherheits-Standard |
| Pixee: Secure AI Coding Agents | https://www.pixee.ai/blog/secure-ai-coding-agents | Security-Best-Practices (Nov 2026) |
| Summer Engine: Godot AI Workflow 2026 | https://www.summerengine.com/blog/godot-agentic-coding | Workflow-Analyse |
| Voyager: Godot MCP comparison | https://voyager.so/blog/godot-mcp | Vergleichstest (Nov 2026, Godot 4.7.2) |
| GodotLearning: Can AI Write GDScript? | https://godotlearning.com/blog/ai-write-gdscript-llm-godot | Fehlerbild-Analyse |
| GodotLearning: AI Workflow | https://godotlearning.com/ai-workflow | Workflow-Stufen |
| Godot Forum: AI-assisted code generation | https://forum.godotengine.org/t/what-are-the-best-practices-for-combining-godot-with-ai-assisted-code-generation/110307 | Community-Diskussion |
| scony/godot-gdscript-toolkit | https://github.com/scony/godot-gdscript-toolkit/ | Linter/Formatter-Tooling |
