class_name MenuDialog
extends Control

## Shared base for every menu and dialog.
##
## One skeleton, so every menu is laid out the same way. Subclass scripts
## reach the nodes by their unique names (%Name):
##
##   Backdrop  ColorRect        dims whatever is behind
##   SafeArea  MarginContainer  keeps the panel off the window edge
##   Center    CenterContainer
##   Panel     PanelContainer   the cream card
##   VBox      VBoxContainer    Title / Subtitle / Content / Footer
##
## The base owns the behaviour every dialog needs, subclasses only fill in
## their content and react to their buttons:
##   - the panel never leaves the window: preferred_size is clamped to the
##     space the window offers, a ScrollContainer in Content does the rest
##   - the game stays paused as long as ANY dialog is open (closing the
##     settings on top of the pause menu no longer unpauses the game)
##   - ESC closes only the top-most dialog
##   - the primary button gets keyboard focus, the dialog fades in

signal closed

## Panel size when the window offers enough room. y = 0: as tall as the
## content (scrolled content included). x = 0: as wide as the content.
@export var preferred_size: Vector2 = Vector2(560.0, 0.0)

## ESC closes this dialog (only the top-most one reacts). Off for dialogs
## that must be finished, like creating the first profile.
@export var closable: bool = true

## Pauses the game while this dialog is open.
@export var pauses_game: bool = true

## Dims the background. Off for full screens such as the main menu.
@export var dim_background: bool = true

## Open dialogs, bottom-most first. ESC goes to the last one only.
static var _stack: Array[MenuDialog] = []
static var _pause_count: int = 0

var _paused_the_game: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			process_mode = Node.PROCESS_MODE_ALWAYS
			_stack.append(self)
			if pauses_game:
				_paused_the_game = true
				_pause_count += 1
			_update_pause()
		NOTIFICATION_EXIT_TREE:
			_stack.erase(self)
			if _paused_the_game:
				_paused_the_game = false
				_pause_count = maxi(_pause_count - 1, 0)
			_update_pause()
		NOTIFICATION_READY:
			# Deferred: after the subclass' _ready has built its runtime
			# content and the containers have sorted once.
			_on_ready.call_deferred()


## Paused exactly while at least one dialog wants the game paused
static func _update_pause() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.paused = _pause_count > 0


func _on_ready() -> void:
	var backdrop: ColorRect = get_node_or_null("%Backdrop") as ColorRect
	if backdrop:
		backdrop.color = UITheme.BACKDROP
		backdrop.visible = dim_background
	var center: Control = get_node_or_null("%Center")
	if center:
		center.resized.connect(_fit_panel)
	get_viewport().size_changed.connect(_fit_panel)
	var content: ScrollContainer = get_node_or_null("%Content") as ScrollContainer
	if content:
		# Content that grows or re-wraps (error label, reading level change)
		# must re-fit the panel.
		for child: Node in content.get_children():
			if child is Control:
				(child as Control).minimum_size_changed.connect(_fit_panel)
	_fit_panel()
	_focus_primary_button.call_deferred()
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)


## Size the panel: preferred_size, clamped to the space the window offers.
## With preferred_size.y = 0 the panel is as tall as its content (scrolled
## content included) and only scrolls when the window is too small. Runs
## whenever the window (and with it Center) is resized.
func _fit_panel() -> void:
	var panel: PanelContainer = get_node_or_null("%Panel")
	if panel == null:
		return
	var avail: Vector2 = _available_size()
	var wanted_height: float = preferred_size.y
	if wanted_height <= 0.0:
		wanted_height = _content_height(panel)
	var wanted: Vector2 = Vector2(
		minf(preferred_size.x, avail.x) if preferred_size.x > 0.0 else 0.0,
		minf(wanted_height, avail.y) if wanted_height > 0.0 else 0.0
	)
	if not panel.custom_minimum_size.is_equal_approx(wanted):
		panel.custom_minimum_size = wanted


## Space the panel may take: the window minus the SafeArea margins. Measured
## at the window on purpose - a container in the dialog grows with its
## content, so it can never tell us that the content is too tall.
func _available_size() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	var safe: MarginContainer = get_node_or_null("%SafeArea") as MarginContainer
	if safe:
		size -= Vector2(
			safe.get_theme_constant("margin_left") + safe.get_theme_constant("margin_right"),
			safe.get_theme_constant("margin_top") + safe.get_theme_constant("margin_bottom")
		)
	return size


## Panel height at which the scrolled content fits without scrolling
func _content_height(panel: PanelContainer) -> float:
	var content: ScrollContainer = get_node_or_null("%Content") as ScrollContainer
	if content == null or content.get_child_count() == 0:
		return 0.0
	var inner: Control = content.get_child(0) as Control
	if inner == null:
		return 0.0
	var without_scroll: float = panel.get_combined_minimum_size().y - content.get_combined_minimum_size().y
	return without_scroll + inner.get_combined_minimum_size().y


## Keyboard focus on the primary button, else on the right-most usable
## footer button, so Enter does the obvious thing.
func _focus_primary_button() -> void:
	for node: Node in find_children("*", "Button", true, false):
		var primary: Button = node as Button
		if primary and primary.theme_type_variation == &"PrimaryButton" \
				and primary.is_visible_in_tree() and not primary.disabled:
			primary.grab_focus()
			return
	# No usable primary button: the right-most footer button, nothing else
	# (never a picker chip in the content).
	var footer: Node = get_node_or_null("%Footer")
	if footer == null:
		return
	var fallback: Button = null
	for node: Node in footer.find_children("*", "Button", true, false):
		var btn: Button = node as Button
		if btn and btn.is_visible_in_tree() and not btn.disabled:
			fallback = btn
	if fallback:
		fallback.grab_focus()


func _input(event: InputEvent) -> void:
	if not closable or not is_visible_in_tree():
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _stack.is_empty() or _stack.back() != self:
		return
	if _on_escape():
		get_viewport().set_input_as_handled()


## ESC was pressed while this dialog is on top. Return true if it was used.
## Subclasses override this to close their own way.
func _on_escape() -> bool:
	_close()
	return true


func _close() -> void:
	closed.emit()
	queue_free()
