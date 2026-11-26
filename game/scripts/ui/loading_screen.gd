class_name LoadingScreen
extends Control
## Shown while the world is generated.

var _bar: ProgressBar
var _text: Label

const TIPS: Array[String] = [
	"Hold CAST to charge your throw, release to cast. Tap HOOK the moment a fish bites!",
	"Fish rarities change with the weather and time of day - night fish are worth the wait.",
	"Cooked dishes sell for far more than raw fish, and give temporary fishing buffs.",
	"Breed fish in the Hatchery: mutations can make a single fish worth a fortune.",
	"Your tanks, kitchen, factory and assistants keep working while the game is closed.",
	"Not enough room? Upgrade your backpack at the Fishing Guild.",
]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.2
	box.anchor_right = 0.8
	box.anchor_top = 0.4
	box.anchor_bottom = 0.7
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(UI.label("Loading the world...", UI.FONT_BIG, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_bar = UI.bar(0.0, 1.0, UI.C_ACCENT, 26)
	box.add_child(_bar)
	_text = UI.label("", UI.FONT_SMALL, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_text)
	var tip := UI.label(TIPS[randi() % TIPS.size()], UI.FONT, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(UI.spacer(20))
	box.add_child(tip)


func update_progress(fraction: float, text: String) -> void:
	if _bar:
		_bar.value = fraction
		_text.text = text
