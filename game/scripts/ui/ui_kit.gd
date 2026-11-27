class_name UI
extends RefCounted
## Shared look & small widget factories for every screen. All sizes are chosen
## for phones: big touch targets (>= 64 px high) and readable fonts.

const FONT := 24
const FONT_SMALL := 19
const FONT_BIG := 34
const ROW_H := 72

const C_BG := Color(0.07, 0.12, 0.17, 0.97)
const C_PANEL := Color(0.11, 0.18, 0.25, 1.0)
const C_ROW := Color(0.15, 0.24, 0.33, 1.0)
const C_ACCENT := Color(0.18, 0.62, 0.82)
const C_GOOD := Color(0.24, 0.72, 0.4)
const C_BAD := Color(0.82, 0.3, 0.3)
const C_GOLD := Color(1.0, 0.82, 0.3)
const C_TEXT := Color(0.94, 0.97, 1.0)
const C_DIM := Color(0.62, 0.72, 0.8)

static var _theme: Theme = null


static func style(color: Color, radius := 14, border := 0, border_color := Color.TRANSPARENT,
		margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = FONT
	t.set_color("font_color", "Label", C_TEXT)
	t.set_font_size("font_size", "Label", FONT)
	# buttons
	t.set_stylebox("normal", "Button", style(C_ACCENT, 14, 0, Color.TRANSPARENT, 16))
	t.set_stylebox("hover", "Button", style(C_ACCENT.lightened(0.12), 14, 0, Color.TRANSPARENT, 16))
	t.set_stylebox("pressed", "Button", style(C_ACCENT.darkened(0.25), 14, 0, Color.TRANSPARENT, 16))
	t.set_stylebox("disabled", "Button", style(Color(0.25, 0.3, 0.36), 14, 0, Color.TRANSPARENT, 16))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.66, 0.72))
	t.set_font_size("font_size", "Button", FONT)
	# panels
	t.set_stylebox("panel", "PanelContainer", style(C_PANEL, 18, 2, Color(0.3, 0.5, 0.65), 18))
	t.set_stylebox("panel", "Panel", style(C_PANEL, 18, 2, Color(0.3, 0.5, 0.65), 18))
	# scroll bars: wide so they can be grabbed with a finger
	var grab := style(Color(0.45, 0.65, 0.8, 0.9), 8, 0, Color.TRANSPARENT, 0)
	grab.content_margin_left = 10
	grab.content_margin_right = 10
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", style(Color(0, 0, 0, 0.25), 8, 0, Color.TRANSPARENT, 10))
	# progress bars
	t.set_stylebox("background", "ProgressBar", style(Color(0, 0, 0, 0.45), 8, 0, Color.TRANSPARENT, 4))
	t.set_stylebox("fill", "ProgressBar", style(C_GOOD, 8, 0, Color.TRANSPARENT, 4))
	# sliders
	t.set_stylebox("slider", "HSlider", style(Color(0, 0, 0, 0.45), 6, 0, Color.TRANSPARENT, 4))
	t.set_stylebox("grabber_area", "HSlider", style(C_ACCENT, 6, 0, Color.TRANSPARENT, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", style(C_ACCENT, 6, 0, Color.TRANSPARENT, 4))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


static func label(text: String, size := FONT, color := C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, cb: Callable = Callable(), enabled := true,
		min_size := Vector2(120, 60), color := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	if color != Color.TRANSPARENT:
		b.add_theme_stylebox_override("normal", style(color, 14, 0, Color.TRANSPARENT, 16))
		b.add_theme_stylebox_override("hover", style(color.lightened(0.12), 14, 0, Color.TRANSPARENT, 16))
		b.add_theme_stylebox_override("pressed", style(color.darkened(0.25), 14, 0, Color.TRANSPARENT, 16))
	if cb.is_valid():
		b.pressed.connect(func():
			Sfx.play("click", 0.6)
			cb.call())
	return b


static func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hfill() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func header(text: String) -> Label:
	var l := label(text, FONT_BIG - 6, C_GOLD)
	return l


## A list entry: a title + sub line on the left, any number of buttons on the right.
## actions: Array of [text, Callable, enabled(bool), color(optional)]
static func row(title: String, sub := "", actions: Array = [], title_color := C_TEXT,
		bg := C_ROW, icon: Control = null) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style(bg, 12, 0, Color.TRANSPARENT, 14))
	pc.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	pc.add_child(h)
	if icon != null:
		h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var t := label(title, FONT, title_color)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if sub != "":
		var s := label(sub, FONT_SMALL, C_DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	for a in actions:
		var col: Color = a[3] if a.size() > 3 else Color.TRANSPARENT
		var b := button(a[0], a[1], a[2] if a.size() > 2 else true, Vector2(110, 56), col)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	return pc


static func bar(value: float, max_value: float, color := C_GOOD, h := 18.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = max_value
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("fill", style(color, 8, 0, Color.TRANSPARENT, 4))
	return p


static func rarity_text(r: int) -> String:
	return Util.rarity_name(r)


## Rich one-line description of a fish instance for lists.
static func fish_line(f: Dictionary) -> String:
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null:
		return "?"
	var parts: Array[String] = [Util.weight_text(float(f.get("w", 0.0)))]
	if f.get("stage", "adult") == "fry":
		parts.append("fry")
	if f.get("farm", false):
		parts.append("farmed")
	parts.append(Util.rarity_name(sp.rarity))
	return " · ".join(parts)
