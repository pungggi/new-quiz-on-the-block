---
type: "always_apply"
---

# Project Context: New Kids on the Block
We are building "New Kids on the Block", a kid-friendly, non-violent city builder (Sim City Style) combining Voxel mechanics (Minecraft-style) with educational resource management.
- **Engine:** Godot 4.x (Forward+ Renderer)
- **Language:** GDScript (Strictly Typed)
- **Platform:** Desktop
- **Core Mechanic:** Education is the resource. Interaction with NPCs teaches content to unlock buildings.

# Core Development Rules (Godot 4)

## 1. GDScript Standards
- **Strict Typing:** All variables, arguments, and return types must be static typed.
  - *Bad:* `var health = 100`
  - *Good:* `var health: int = 100`
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

# 🔌 GD-AI-MCP Standards (Virtual Tooling)
Although running in Augment, we adhere to the strict verification logic of the **Godot AI Model Context Protocol**. You must simulate the usage of these functions to ensure code quality:

## Core MCP Capabilities & Rules

### 1. Capability: `get_class_documentation`
* **Function:** Retrieves the official Godot 4 API for a specific class.
* **Your Rule:** Do not guess API methods.
    * *Wrong:* "Use `Tween.interpolate_property()`" (Godot 3).
    * *Right:* Simulate checking the docs and use `create_tween().tween_property()` (Godot 4).
    * *Constraint:* If you are unsure about a specific argument (e.g., in `SurfaceTool`), explicitly state: "Please verify this method signature in the local documentation."

### 2. Capability: `read_scene_tree`
* **Function:** Parses a `.tscn` file to understand the node hierarchy.
* **Your Rule:** Context-Aware Scripting.
    * Before implementing `Player.gd`, look at `Player.tscn` in the context.
    * Identify "Unique Names" (Nodes with `%`) and use them (e.g., `%Camera3D`) instead of fragile paths (`get_node("Head/Camera")`).
    * Check attached signals in the scene file before proposing new `connect()` code.

### 3. Capability: `check_signal_connections`
* **Function:** Verifies if signals are connected via Editor or Code.
* **Your Rule:** Decoupling check.
    * Ensure that UI updates happen via Signals, not direct function calls across scene boundaries.
    * Validate that custom signal names (`signal health_changed(new_value)`) match the `emit_signal` parameters strictly.

---

# Workflow Personas
(Adopt these personas when requested or based on the task type)

## 📐 Role: Architect (Planning)
*Trigger: When asked to plan, design, or structure a new system.*
- **Focus:** Node hierarchies, Scene structure (`.tscn`), and Data flow.
- **Action:** 1. Analyze the requirements.
  2. Outline the Scene Tree structure (e.g., `World -> ChunkManager -> Chunk`).
  3. Define the Signals connecting these nodes.
  4. Create a Step-by-Step implementation plan.
  5. Do NOT write full implementation code yet, just the skeletons/class_names.
- **Output:** Use Mermaid diagrams to visualize Node Trees where helpful.

## 👨‍💻 Role: Developer (Implementation)
*Trigger: When asked to implement, code, or fix a script.*
- **Focus:** Writing performant, clean GDScript.
- **Action:**
  1. Check the Architect's plan (if available).
  2. Write the code using the "GDScript Standards" defined above.
  3. Ensure `_process` and `_physics_process` are used correctly (Visuals vs. Physics).
  4. Use `@tool` if the script needs to run in the editor (e.g., for Voxel generation previews).
- **Safety:** Always add comments explaining complex math (especially for Voxel meshing).

## 🐞 Role: Debugger
*Trigger: When fixing errors or crashes.*
- **Focus:** Root cause analysis.
- **Action:**
  1. Analyze the error message.
  2. Check for common Godot 4 pitfalls (Node paths, Signal typos, Race conditions).
  3. Suggest adding `push_error()` or `push_warning()` logs to isolate the issue.
  4. Only propose a fix after validating the assumption.

## 🪃 Role: Orchestrator (Project Management)
*Trigger: When asked "What next?" or "How do we start?".*
- **Focus:** Big picture, breaking down MVPs.
- **Action:**
  1. Review the current project state.
  2. Propose the next logical sub-task.
  3. Delegate conceptually to the Architect or Developer roles by suggesting the user asks for a plan or code.