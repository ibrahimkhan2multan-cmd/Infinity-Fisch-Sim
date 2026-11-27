class_name PanelBase
extends Control
## Base for every modal screen (shop, inventory, hatchery...). Provides a title
## bar with a big close button, optional tabs and a scrolling content column.
## Subclasses override `_populate(tab)` and are rebuilt automatically whenever
## the game state they depend on changes.

signal closed

var title := "Panel"
var tab_names: Array[String] = []
var tab := 0
var content: VBoxContainer
var footer: HBoxContainer

var _scroll: ScrollContainer
var _tabs_box: HBoxContainer
var _title_label: Label
var _dirty := false
var _live_timer := 0.0
## While true the panel rebuilds once a second (for countdown timers).
var live := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.theme()
	visible = false
	add_to_group("touch_blocker")


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 0.04
	panel.anchor_bottom = 0.96
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	add_child(panel)
	var root := VBoxContainer.new()
	panel.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	_title_label = UI.label(title, UI.FONT_BIG, UI.C_GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title_label)
	var close := UI.button("Close", close_panel, true, Vector2(130, 60), UI.C_BAD)
	top.add_child(close)
	_tabs_box = HBoxContainer.new()
	root.add_child(_tabs_box)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	_scroll.add_child(content)
	footer = HBoxContainer.new()
	root.add_child(footer)
	for sig in [Game.money_changed, Game.inventory_changed, Game.items_changed, Game.equipment_changed,
			Game.permits_changed, Game.facilities_changed, Game.collection_changed]:
		sig.connect(_mark_dirty)


func open_panel(start_tab := 0) -> void:
	tab = clampi(start_tab, 0, maxi(0, tab_names.size() - 1))
	_title_label.text = title
	visible = true
	refresh()
	_on_open()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_open() -> void:
	pass


func _mark_dirty(_a = null) -> void:
	if visible and not _dirty:
		_dirty = true
		_flush.call_deferred()


func _flush() -> void:
	if _dirty:
		_dirty = false
		refresh()


func _process(delta: float) -> void:
	if visible and live:
		_live_timer += delta
		if _live_timer >= 1.0:
			_live_timer = 0.0
			refresh()


## Rebuilds the tab bar and the content, keeping the scroll position.
func refresh() -> void:
	if content == null:
		return
	var keep := _scroll.scroll_vertical
	for c in _tabs_box.get_children():
		c.queue_free()
	for i in tab_names.size():
		var b := UI.button(tab_names[i], func():
			tab = i
			_scroll.scroll_vertical = 0
			refresh(), true, Vector2(150, 56))
		if i != tab:
			b.add_theme_stylebox_override("normal", UI.style(Color(0.2, 0.3, 0.4), 12, 0, Color.TRANSPARENT, 14))
		_tabs_box.add_child(b)
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	for c in footer.get_children():
		footer.remove_child(c)
		c.queue_free()
	_populate(tab)
	_scroll.set_deferred("scroll_vertical", keep)


func _populate(_tab: int) -> void:
	pass


# ---- helpers for subclasses ----------------------------------------------------

func add(node: Control) -> Control:
	content.add_child(node)
	return node


func add_header(text: String) -> void:
	content.add_child(UI.header(text))


func add_note(text: String, color := UI.C_DIM) -> void:
	var l := UI.label(text, UI.FONT_SMALL, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)


func add_row(title_text: String, sub := "", actions: Array = [], title_color := UI.C_TEXT, icon: Control = null) -> void:
	content.add_child(UI.row(title_text, sub, actions, title_color, UI.C_ROW, icon))


## Shows the result message of a system call ("" = success) as a toast.
func report(msg: String) -> void:
	if msg != "":
		Game.notify.emit(msg, "bad")
		Sfx.play("error", 0.7)
