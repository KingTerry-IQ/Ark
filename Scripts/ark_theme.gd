## Ark's own look. Dark water, a gold chest, parchment text.
##
## The covenant chest and the boat are the same object here: a hull you can
## put something in, and a chest that keeps it. Corners stay square because
## a chest is a box. The face is IBM Plex Mono.

class_name ArkTheme
extends RefCounted

const INK := Color("07141A")
const HULL := Color("10242C")
const HULL_RAISED := Color("17333D")
const GOLD := Color("D4A656")
const GOLD_DIM := Color("8C6E3A")
const PARCHMENT := Color("E7DCC8")
const SEA := Color("7D8E86")
const WATER := Color("6EADC2")
const CLAY := Color("C45C4A")
const LAMP := Color("A8C48A")
const FOAM := Color("F3E6C8")

## Names the window already speaks. They map onto the palette above.
const MUTED := SEA
const GREY := PARCHMENT
const GREEN := LAMP
const CYAN := WATER
const YELLOW := GOLD
const AMBER := CLAY
const BLACK := INK
const WHITE := FOAM
const DARK_GREY := GOLD_DIM
const RED := CLAY
const PANEL := HULL

const FONT_PATH := "res://Assets/IBMPlexMono-Light.ttf"

const SIZE_BODY := 16
const SIZE_SMALL := 13
const SIZE_TITLE := 28
const SIZE_DISPLAY := 22


static func build() -> Theme:
	var theme := Theme.new()
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	theme.default_font_size = SIZE_BODY
	if font != null:
		theme.default_font = font
	_style_labels(theme)
	_style_buttons(theme)
	_style_inputs(theme)
	_style_panels(theme)
	_style_lists(theme)
	_style_bars(theme)
	_style_scroll(theme)
	_style_tips(theme)
	_style_windows(theme)
	return theme


static func _style_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", PARCHMENT)
	theme.set_color("default_color", "RichTextLabel", PARCHMENT)
	theme.set_constant("line_separation", "RichTextLabel", 2)


static func _style_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _outline(GOLD, HULL))
	theme.set_stylebox("hover", "Button", _solid(GOLD))
	theme.set_stylebox("pressed", "Button", _solid(FOAM))
	theme.set_stylebox("focus", "Button", _outline(FOAM, Color(0, 0, 0, 0)))
	theme.set_stylebox("disabled", "Button", _outline(GOLD_DIM, HULL))
	theme.set_color("font_color", "Button", GOLD)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", GOLD_DIM)

	# CheckBox falls back to Button. State every style or the label lands on
	# a solid gold fill and disappears.
	var quiet := _outline(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	theme.set_stylebox("normal", "CheckBox", quiet)
	theme.set_stylebox("hover", "CheckBox", _outline(Color(0, 0, 0, 0), HULL_RAISED))
	theme.set_stylebox("pressed", "CheckBox", _outline(Color(0, 0, 0, 0), HULL_RAISED))
	theme.set_stylebox("hover_pressed", "CheckBox", _outline(Color(0, 0, 0, 0), HULL_RAISED))
	theme.set_stylebox("focus", "CheckBox", _outline(GOLD_DIM, Color(0, 0, 0, 0)))
	theme.set_stylebox("disabled", "CheckBox", quiet)
	theme.set_color("font_color", "CheckBox", PARCHMENT)
	theme.set_color("font_hover_color", "CheckBox", GOLD)
	theme.set_color("font_pressed_color", "CheckBox", GOLD)
	theme.set_color("font_hover_pressed_color", "CheckBox", GOLD)
	theme.set_color("font_focus_color", "CheckBox", FOAM)
	theme.set_color("font_disabled_color", "CheckBox", SEA)
	theme.set_color("icon_normal_color", "CheckBox", PARCHMENT)
	theme.set_color("icon_hover_color", "CheckBox", GOLD)
	theme.set_color("icon_pressed_color", "CheckBox", GOLD)
	theme.set_color("icon_hover_pressed_color", "CheckBox", GOLD)
	theme.set_color("icon_focus_color", "CheckBox", FOAM)
	theme.set_color("icon_disabled_color", "CheckBox", SEA)


static func _style_inputs(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", _outline(GOLD_DIM, INK))
	theme.set_stylebox("focus", "LineEdit", _outline(GOLD, INK))
	theme.set_color("font_color", "LineEdit", PARCHMENT)
	theme.set_color("font_placeholder_color", "LineEdit", SEA)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", WATER)

	theme.set_stylebox("normal", "TextEdit", _outline(GOLD_DIM, INK))
	theme.set_stylebox("focus", "TextEdit", _outline(GOLD, INK))
	theme.set_stylebox("read_only", "TextEdit", _outline(GOLD_DIM, INK))
	theme.set_color("font_color", "TextEdit", PARCHMENT)
	theme.set_color("font_readonly_color", "TextEdit", PARCHMENT)
	theme.set_color("caret_color", "TextEdit", GOLD)

	theme.set_stylebox("normal", "SpinBox", _outline(GOLD_DIM, INK))
	theme.set_stylebox("normal", "OptionButton", _outline(GOLD_DIM, HULL))
	theme.set_stylebox("hover", "OptionButton", _outline(GOLD, HULL))
	theme.set_stylebox("pressed", "OptionButton", _solid(GOLD))
	theme.set_stylebox("focus", "OptionButton", _outline(GOLD, HULL))
	theme.set_color("font_color", "OptionButton", GOLD)
	theme.set_color("font_hover_color", "OptionButton", GOLD)
	theme.set_color("font_pressed_color", "OptionButton", INK)
	theme.set_color("font_focus_color", "OptionButton", FOAM)


static func _style_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "Panel", _outline(GOLD_DIM, HULL))
	theme.set_stylebox("panel", "PanelContainer", _outline(GOLD_DIM, HULL))
	theme.set_stylebox("panel", "PopupMenu", _outline(GOLD, INK))
	theme.set_color("font_color", "PopupMenu", PARCHMENT)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_accelerator_color", "PopupMenu", SEA)
	theme.set_stylebox("hover", "PopupMenu", _solid(GOLD))


static func _style_lists(theme: Theme) -> void:
	theme.set_stylebox("panel", "ItemList", _outline(GOLD_DIM, INK))
	theme.set_stylebox("hovered", "ItemList", _solid(HULL_RAISED))
	theme.set_stylebox("selected", "ItemList", _outline(GOLD, HULL))
	theme.set_stylebox("cursor", "ItemList", _outline(GOLD, Color(0, 0, 0, 0)))
	theme.set_color("font_color", "ItemList", PARCHMENT)
	theme.set_color("font_hovered_color", "ItemList", FOAM)
	theme.set_color("font_selected_color", "ItemList", GOLD)
	theme.set_constant("v_separation", "ItemList", 4)
	theme.set_constant("icon_margin", "ItemList", 8)
	theme.set_constant("line_separation", "ItemList", 2)


static func _style_bars(theme: Theme) -> void:
	var bg := _outline(GOLD_DIM, INK)
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", _solid(GOLD))
	theme.set_color("font_color", "ProgressBar", INK)
	theme.set_color("font_outline_color", "ProgressBar", INK)


static func _style_scroll(theme: Theme) -> void:
	var track := _box(GOLD_DIM, INK, 1, 1, 1)
	var grab := _box(GOLD, GOLD, 0, 0, 1)
	var grab_hot := _box(FOAM, FOAM, 0, 0, 1)
	for kind in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", kind, track)
		theme.set_stylebox("scroll_focus", kind, track)
		theme.set_stylebox("grabber", kind, grab)
		theme.set_stylebox("grabber_highlight", kind, grab_hot)
		theme.set_stylebox("grabber_pressed", kind, grab_hot)
		theme.set_stylebox("grabber_area", kind, StyleBoxEmpty.new())
		theme.set_stylebox("grabber_area_highlight", kind, StyleBoxEmpty.new())


static func _style_tips(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", _outline(GOLD, INK))
	theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	theme.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)


static func _style_windows(theme: Theme) -> void:
	theme.set_stylebox("embedded_border", "Window", _outline(GOLD, HULL))
	theme.set_stylebox("embedded_unfocused_border", "Window", _outline(GOLD_DIM, HULL))
	theme.set_color("title_color", "Window", GOLD)
	theme.set_constant("title_height", "Window", 28)
	theme.set_stylebox("panel", "AcceptDialog", _outline(GOLD, INK))


static func _outline(border: Color, fill: Color) -> StyleBoxFlat:
	return _box(border, fill, 8, 4, 1)


static func _solid(fill: Color) -> StyleBoxFlat:
	return _box(fill, fill, 8, 4, 1)


static func _box(border: Color, fill: Color, pad_x: int, pad_y: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(0)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


static func rule(colour: Color = GOLD_DIM) -> ColorRect:
	var line := ColorRect.new()
	line.color = colour
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


## A chest on a waterline, drawn in code so the chrome is not a photograph.
static func mark() -> Control:
	return Mark.new()


class Mark extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(36, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gold := ArkTheme.GOLD
		var water := ArkTheme.WATER
		draw_line(Vector2(2, 24), Vector2(34, 24), water, 1.0)
		draw_line(Vector2(8, 26), Vector2(28, 26), water, 1.0)
		draw_rect(Rect2(8, 12, 20, 10), gold, false, 1.5)
		draw_line(Vector2(8, 12), Vector2(18, 7), gold, 1.5)
		draw_line(Vector2(18, 7), Vector2(28, 12), gold, 1.5)
		draw_line(Vector2(8, 17), Vector2(28, 17), gold, 1.0)
		draw_line(Vector2(11, 11), Vector2(14, 8), gold, 1.0)
		draw_line(Vector2(14, 8), Vector2(16, 11), gold, 1.0)
		draw_line(Vector2(20, 11), Vector2(22, 8), gold, 1.0)
		draw_line(Vector2(22, 8), Vector2(25, 11), gold, 1.0)


static func title(text: String, colour: Color = GOLD) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SIZE_TITLE)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func line(text: String, colour: Color = PARCHMENT, size: int = SIZE_BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func cell(text: String, colour: Color = PARCHMENT, size: int = SIZE_SMALL) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func primary_button(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.add_theme_stylebox_override("normal", _solid(GOLD))
	b.add_theme_stylebox_override("hover", _solid(FOAM))
	b.add_theme_stylebox_override("pressed", _solid(FOAM))
	b.add_theme_stylebox_override("hover_pressed", _solid(FOAM))
	b.add_theme_stylebox_override("focus", _box(FOAM, GOLD, 8, 4, 1))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	return b


static func quiet_button(text: String, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", SIZE_SMALL)
	b.add_theme_stylebox_override("normal", _box(GOLD_DIM, INK, 6, 2, 1))
	b.add_theme_stylebox_override("hover", _box(SEA, INK, 6, 2, 1))
	b.add_theme_stylebox_override("pressed", _solid(SEA))
	b.add_theme_stylebox_override("disabled", _box(GOLD_DIM, INK, 6, 2, 1))
	b.add_theme_color_override("font_color", SEA)
	b.add_theme_color_override("font_hover_color", FOAM)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", GOLD_DIM)
	return b


## A mediatype tile: filled when it is the one in force, an outline otherwise.
static func choice(text: String, on: bool, on_pressed: Callable) -> Button:
	var b := button(text, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	paint_choice(b, on)
	return b


static func paint_choice(b: Button, on: bool) -> void:
	if b == null:
		return
	b.add_theme_font_size_override("font_size", SIZE_SMALL)
	if on:
		b.add_theme_stylebox_override("normal", _solid(GOLD))
		b.add_theme_stylebox_override("hover", _solid(FOAM))
		b.add_theme_stylebox_override("pressed", _solid(FOAM))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		return
	b.add_theme_stylebox_override("normal", _box(GOLD_DIM, INK, 8, 3, 1))
	b.add_theme_stylebox_override("hover", _box(GOLD, INK, 8, 3, 1))
	b.add_theme_stylebox_override("pressed", _solid(GOLD))
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", INK)


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	return b


static func header(text: String) -> Label:
	var label := line(text, GOLD, SIZE_SMALL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.clip_contents = true
	return p
