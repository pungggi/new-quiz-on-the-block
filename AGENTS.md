# Project Context: New Kids on the Block

We are building "New Kids on the Block", a kid-friendly, non-violent city builder (Sim City Style) combining Voxel mechanics (Minecraft-style) with educational resource management.

- **Engine:** Godot 4.x (Forward+ Renderer)
- **Language:** GDScript (Strictly Typed)
- **Platform:** Desktop
- **Core Mechanic:** Education is the resource. Interaction with NPCs teaches content to unlock buildings.

# Core Development Rules (Godot 4)

## 1. GDScript Standards

- **Strict Typing:** All variables, arguments, and return types must be static typed.
  - _Bad:_ `var health = 100`
  - _Good:_ `var health: int = 100`
- **Functions:** Always specify return types, use `-> void` if nothing is returned.
- **Naming:** Use `snake_case` for variables/functions, `PascalCase` for Classes/Nodes.

## 2. Architecture & Patterns

- **Signal Up, Call Down:** - Never use `get_parent()` to manipulate logic. Child nodes emit Signals. Parent nodes call functions on children.
- **Composition over Inheritance:** - Avoid deep class hierarchies. Use distinct Child Nodes (e.g., `HealthComponent`, `InventoryManager`) to add functionality to entities.
- **Data/View Separation:**
  - The Voxel World is data (Array/Dictionary/PackedByteArray). The `MeshInstance3D` is just the view. Never store game logic inside a visual block mesh.

## 3. Voxel Performance (Critical)

- **No Node-per-Block:** NEVER suggest creating an individual Node or Object for a single voxel block.
- **Rendering:** Use `SurfaceTool` with `commit()` or `MultiMeshInstance3D` for rendering chunks.
- **Data Structure:** Use `PackedByteArray` for large voxel data sets to minimize memory overhead.

## 4. Godot 4 Specifics

- **Verification:** Before suggesting code, verify if the API exists in Godot 4.x (e.g., `move_and_slide()` takes no arguments now).
- **Tweens:** Use `create_tween()` instead of the old Tween node.
- **Exports:** Use `@export var` syntax.

## 5. ⚠️ Godot 4 Stolperfallen (KRITISCH)

Beim Code-Review und Entwicklung MÜSSEN diese Patterns vermieden/erkannt werden:

### 5.1 API-Migration (Godot 3 → 4)

| ❌ FALSCH (Godot 3)                | ✅ RICHTIG (Godot 4)               |
| ---------------------------------- | ---------------------------------- |
| `move_and_slide(velocity)`         | `velocity = ...; move_and_slide()` |
| `instance()`                       | `instantiate()`                    |
| `connect("signal", obj, "method")` | `signal.connect(method)`           |
| `yield(obj, "signal")`             | `await obj.signal`                 |
| `$Tween.interpolate_property()`    | `create_tween().tween_property()`  |
| `export var`                       | `@export var`                      |

### 5.2 Signal-Verbindungen

```gdscript
# ❌ FALSCH
button.connect("pressed", self, "_on_pressed")
# ✅ RICHTIG
button.pressed.connect(_on_pressed)
# ✅ Mit Argumenten
button.pressed.connect(_on_pressed.bind(extra_arg))
```

### 5.3 Typed Arrays - ACHTUNG!

```gdscript
# ❌ FEHLER - Typed Arrays können nicht direkt zugewiesen werden
var nodes: Array[Node2D] = get_children()  # CRASH!
# ✅ RICHTIG
var nodes: Array[Node2D] = []
nodes.assign(get_children())
# ✅ ODER - Untyped verwenden wenn nötig
var nodes := get_children()  # Array (untyped)
```

### 5.4 Resource-Sharing (GEFÄHRLICH!)

```gdscript
# ⚠️ GEFAHR: Alle Instanzen teilen dasselbe Material!
@export var material: StandardMaterial3D
func change_color() -> void:
	material.albedo_color = Color.RED  # ALLE werden rot!

# ✅ FIX 1: In _ready() duplizieren
func _ready() -> void:
	material = material.duplicate()

# ✅ FIX 2: Im Editor "resource_local_to_scene = true" setzen
```

### 5.5 await Funktionen

```gdscript
# ⚠️ Funktion mit await MUSS Rückgabetyp haben!
func do_something():  # ❌ Kein Rückgabetyp = Probleme
	await get_tree().process_frame

func do_something() -> void:  # ✅ RICHTIG
	await get_tree().process_frame
```

### 5.6 queue_free() Timing

```gdscript
# ⚠️ Node wird NICHT sofort gelöscht!
node.queue_free()
print(node)  # Noch da bis Frame-Ende!

# ⚠️ is_instance_valid() kann true sein trotz queue_free!
# ✅ Nach Timer/Tween ist is_instance_valid() sicher:
await get_tree().create_timer(1.0).timeout
if is_instance_valid(node):
	node.do_something()  # Sicher
```

### 5.7 Collision Layers vs Masks

```gdscript
# Layer = "Ich BIN auf Layer X"
# Mask = "Ich SEHE/KOLLIDIERE mit Layer X"
# Verwende Config-Konstanten:
collision_layer = Config.TERRAIN_COLLISION_LAYER
collision_mask = Config.BUILDING_COLLISION_LAYER
```

### 5.8 Physics vs Process

```gdscript
# ⚠️ Visuelle Updates in _physics_process = Stottern!
func _physics_process(delta: float) -> void:
	sprite.rotation += delta  # ❌ Kann ruckeln

# ✅ RICHTIG - Trennung
func _process(delta: float) -> void:
	sprite.rotation += delta  # Visuals hier

func _physics_process(delta: float) -> void:
	move_and_slide()  # Physik hier
```

### 5.9 Debug-Output in Production

```gdscript
# ❌ VERMEIDEN in Production-Code
print("Debug: %s" % value)

# ✅ BESSER - Verwende push_warning/push_error für wichtige Meldungen
push_warning("Chunk data missing!")
push_error("Critical failure!")

# ✅ ODER - Debug-Flag verwenden
const DEBUG := false
if DEBUG:
	print("Debug info")
```

### 5.10 Autoload-Reihenfolge

```gdscript
# ⚠️ Autoload A greift auf Autoload B in _ready() zu
# Aber B wird nach A geladen → null!

# ✅ FIX: Verzögern
func _ready() -> void:
	await get_tree().process_frame
	var other = OtherAutoload  # Jetzt sicher
```

### 5.11 Typ-Inferenz mit Ternary/Variant

```gdscript
# ❌ GEFAHR: Wenn `data` z.B. Variant oder Dictionary ist,
# kann Godot 4 den Typ bei Ternary-Zuweisungen nicht immer korrekt inferieren.
var my_val := data.size if data else 1.0  # Führt oft zu "Warning treated as error" wegen Variant.

# ✅ RICHTIG: Expliziter Typ und expliziter Cast.
var my_val: float = float(data.size) if data else 1.0
```

### 5.12 Unbenutzte Variablen in Funktions-Signaturen

```gdscript
# ❌ ERZEUGT WARNUNG: Variable wird nicht genutzt.
func do_something(val1: int, val2: String) -> void:
	print(val1)

# ✅ RICHTIG: Unbenutzte Parameter mit Unterstrich präfixen.
func do_something(val1: int, _val2: String) -> void:
	print(val1)
```

### 5.13 Globale Klassen (`class_name`) nicht preloaden

```gdscript
# ❌ FALSCH: Wenn `MyClass.gd` bereits `class_name MyClass` definiert hat.
const MyClass := preload("res://scripts/my_class.gd")

# ✅ RICHTIG: Globale Klassen sind sofort unter ihrem Namen verfügbar, kein preload nötig.
var instance := MyClass.new()
```

### 5.14 Integer-Division (Abschneiden von Nachkommastellen)

```gdscript
# ⚠️ WARNUNG: Integer Division in Godot 4 erzeugt Warnungen, wenn implizit abgerundet wird.
var chunk_x := world_x / CHUNK_SIZE

# ✅ RICHTIG: Wenn das Abrunden GEWÜNSCHT ist (z.B. für Grid/Chunk-Koordinaten):
@warning_ignore("integer_division")
var chunk_x := world_x / CHUNK_SIZE

# ✅ ODER: Float-Division verwenden, falls Float gewollt ist:
var val: float = float(world_x) / float(CHUNK_SIZE)
```

# 🛠️ Tool Calling Best Practices

To ensure maximum efficiency and avoid errors during implementation:

## 1. Core Tool Strategies

- **Verification First**: Before using `replace_file_content` or `multi_replace_file_content`, ALWAYS use `view_file` (with line numbers) on the target file. Never rely on memory for line ranges or exact character matching.
- **Prefer Multi-Edit Chunks**: When making multiple changes to a single file, favor `multi_replace_file_content`. This prevents multiple sequential rewrites and reduces the chance of line-number drift.
- **Absolute Paths**: Always verify the full absolute path of a file before calling a tool. If unsure, use `find_by_name` first.

## 2. Godot-Specific Tooling

- **Scene-Script Sync**: When editing a GDScript, always read the corresponding `.tscn` file (if it exists) to verify node paths (`$NodeName`) and signal connections.
- **Extension Awareness**: When searching, include Godot-specific extensions (`.gd`, `.tscn`, `.tres`) in your `Includes` filter for `grep_search`.

# 🔌 GD-AI-MCP Standards (Virtual Tooling)

We adhere to the strict verification logic of the **Godot AI Model Context Protocol**. You must simulate the usage of these functions to ensure code quality:

## Core MCP Capabilities & Rules

### 1. Capability: `get_class_documentation`

- **Function:** Retrieves the official Godot 4 API for a specific class.
- **Your Rule:** Do not guess API methods.
  - _Wrong:_ "Use `Tween.interpolate_property()`" (Godot 3).
  - _Right:_ Simulate checking the docs and use `create_tween().tween_property()` (Godot 4).
  - _Constraint:_ If you are unsure about a specific argument (e.g., in `SurfaceTool`), explicitly state: "Please verify this method signature in the local documentation."

### 2. Capability: `read_scene_tree`

- **Function:** Parses a `.tscn` file to understand the node hierarchy.
- **Your Rule:** Context-Aware Scripting.
  - Before implementing `Player.gd`, look at `Player.tscn` in the context.
  - Identify "Unique Names" (Nodes with `%`) and use them (e.g., `%Camera3D`) instead of fragile paths (`get_node("Head/Camera")`).
  - Check attached signals in the scene file before proposing new `connect()` code.

### 3. Capability: `check_signal_connections`

- **Function:** Verifies if signals are connected via Editor or Code.
- **Your Rule:** Decoupling check.
  - Ensure that UI updates happen via Signals, not direct function calls across scene boundaries.
  - Validate that custom signal names (`signal health_changed(new_value)`) match the `emit_signal` parameters strictly.

# 🧮 REAL MCP Tool: `local-math` (Python/NumPy)

**TRIGGER:** Whenever you need to calculate complex math, especially for Voxel chunks, noise generation, or vector/matrix operations.

- **Rule:** Do not hallucinate math results.
- **Action:** Write a Python script using `numpy` to verify the formula or generate lookup tables, then translate the logic to GDScript.
- _Example:_ "Use `local-math` to calculate the vertices for a hexagon grid before writing the SurfaceTool code."

---

# Workflow Personas

(Adopt these personas when requested or based on the task type)

## 📐 Role: Architect (Planning)

_Trigger: When asked to plan, design, or structure a new system._

- **Focus:** Node hierarchies, Scene structure (`.tscn`), and Data flow.
- **Action:** 1. Analyze the requirements. 2. Outline the Scene Tree structure (e.g., `World -> ChunkManager -> Chunk`). 3. Define the Signals connecting these nodes. 4. Create a Step-by-Step implementation plan. 5. Do NOT write full implementation code yet, just the skeletons/class_names.
- **Output:** Use Mermaid diagrams to visualize Node Trees where helpful.

## 👨‍💻 Role: Developer (Implementation)

_Trigger: When asked to implement, code, or fix a script._

- **Focus:** Writing performant, clean GDScript.
- **Action:**
  1. Check the Architect's plan (if available).
  2. Write the code using the "GDScript Standards" defined above.
  3. Ensure `_process` and `_physics_process` are used correctly (Visuals vs. Physics).
  4. Use `@tool` if the script needs to run in the editor (e.g., for Voxel generation previews).
- **Safety:** Always add comments explaining complex math (especially for Voxel meshing).

## 🐞 Role: Debugger

_Trigger: When fixing errors or crashes._

- **Focus:** Root cause analysis.
- **Action:**
  1. Analyze the error message.
  2. Check for common Godot 4 pitfalls (Node paths, Signal typos, Race conditions).
  3. Suggest adding `push_error()` or `push_warning()` logs to isolate the issue.
  4. Only propose a fix after validating the assumption.

## 🪃 Role: Orchestrator (Project Management)

_Trigger: When asked "What next?" or "How do we start?"._

- **Focus:** Big picture, breaking down MVPs.
- **Action:**
  1. Review the current project state.
  2. Propose the next logical sub-task.
  3. Delegate conceptually to the Architect or Developer roles by suggesting the user asks for a plan or code.


## 9. 🤖 KI-gestützter Workflow (GDAI MCP)

Grundlagen und Quellen: `docs/research/godot-gdai-mcp-ai-workflows.md`.

### 9.1 Der 4-Stufen-Loop

Jede KI-gestützte Änderung folgt: **Intent → Edit → Run → Feedback**.

- **Kontext vor Edit:** Vor strukturellen Änderungen echte Szene/Daten abfragen (`get_scene_tree`, `get_scene_file_content`, `view_script`), nicht raten.
- **Feedback nach Edit:** Nach jedem nicht-trivialen Change `play_scene` + `get_godot_errors`; bei visuellen Features zusätzlich Screenshot.
- **Nicht stoppen bei "Datei geschrieben":** Erst ein kompletter Lauf mit Fehler-Suche macht aus Code ein funktionierendes Feature.

### 9.2 Godot-4-Drift-Check (Pflicht vor jeder KI-Ausgabe)

1. `@` vor `export`/`onready` vorhanden? Ohne `@` = Godot 3.
2. `move_and_slide()` **ohne** Argumente (liest `velocity`/`up_direction`).
3. `connect(...)` mit Callable, nicht mit Methoden-String.
4. `CharacterBody2D`/`Node3D` statt `KinematicBody2D`/`Spatial`.
5. Alle referenzierten Klassen/Methoden in der Class Reference der genutzten Version vorhanden?
6. Läuft die Szene? Ohne Lauf zählt nichts.

**Prompting:** Version immer nennen ("Godot 4.7.2, GDScript strict typed"), echtes Projektbeispiel mitschicken, Annahmen benennen lassen.

### 9.3 GDAI MCP Sicherheitsregeln

- **Least Privilege:** `gdai_mcp_project_config.json` mit `GDAI_DISABLE_*` auf den benötigten Tool-Satz reduzieren; `execute_editor_script` und `delete_*` defaultmäßig aus.
- **Human-in-the-Loop:** `delete_scene`, `delete_node`, `execute_editor_script`, `edit_file` nie auto-approve; volle Parameter anzeigen.
- **MCP-Server pinnen:** Per URL/Kommando allowlisten, Version pinnen, bei Änderung neu reviewen; repo-declared `.mcp.json` manuell prüfen.
- **HTTP nur localhost:** `127.0.0.1`, nicht `0.0.0.0`, außer bewusste Netzwerk-Entscheidung.
- **Frische Session nach untrusted Tool-Output** statt Compaction, wenn Rollen/Regeln erhalten bleiben müssen.

### 9.4 Verifikation

- **Pr:** `godot --headless --check-only` + Linter/Formatter (z.B. godot-gdscript-toolkit) + Suche nach `SCRIPT ERROR` (Exit-Code nicht trauen).
- **Post-Edit:** `play_scene` → `get_godot_errors` → optional Screenshot/`simulate_input`.
- **Nicht delegieren:** Szenen-Ownership, Performance ohne Profiler-Beweis, Shader ohne Render-Check, Code den der Entwickler nicht erklären kann.
