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
	_style_tree(theme)
	_style_split(theme)
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
	theme.set_icon("checked", "CheckBox", check_icon(1))
	theme.set_icon("unchecked", "CheckBox", check_icon(0))

	theme.set_icon("checked", "CheckButton", toggle_icon(true))
	theme.set_icon("unchecked", "CheckButton", toggle_icon(false))
	var bare := _outline(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "CheckButton", bare)
	theme.set_color("font_color", "CheckButton", SEA)
	theme.set_color("font_hover_color", "CheckButton", PARCHMENT)
	theme.set_color("font_pressed_color", "CheckButton", GOLD)
	theme.set_color("font_hover_pressed_color", "CheckButton", GOLD)
	theme.set_color("font_focus_color", "CheckButton", PARCHMENT)
	theme.set_font_size("font_size", "CheckButton", SIZE_SMALL)


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
	# Wide enough to find and grab: a 14 px lit track, a gold thumb at least
	# 32 px long on it.
	var track := _box(GOLD_DIM, HULL_RAISED, 7, 7, 1)
	var grab := _box(INK, GOLD, 6, 16, 1)
	var grab_hot := _box(INK, FOAM, 6, 16, 1)
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


## The file table. One control draws every row, so a long item list needs no paging.
static func _style_tree(theme: Theme) -> void:
	theme.set_stylebox("panel", "Tree", _box(GOLD_DIM, INK, 2, 2, 1))
	theme.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("selected", "Tree", _box(HULL_RAISED, HULL_RAISED, 0, 0, 0))
	theme.set_stylebox("selected_focus", "Tree", _box(HULL_RAISED, HULL_RAISED, 0, 0, 0))
	theme.set_stylebox("hovered", "Tree", _box(HULL, HULL, 0, 0, 0))
	theme.set_stylebox("hovered_dimmed", "Tree", _box(HULL, HULL, 0, 0, 0))
	theme.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	var head := _box(GOLD_DIM, HULL, 8, 5, 0)
	head.border_width_bottom = 1
	theme.set_stylebox("title_button_normal", "Tree", head)
	var head_hot := _box(GOLD, HULL_RAISED, 8, 5, 0)
	head_hot.border_width_bottom = 1
	theme.set_stylebox("title_button_hover", "Tree", head_hot)
	theme.set_stylebox("title_button_pressed", "Tree", head_hot)
	theme.set_color("title_button_color", "Tree", GOLD)
	theme.set_font_size("title_button_font_size", "Tree", SIZE_SMALL)
	theme.set_color("font_color", "Tree", PARCHMENT)
	theme.set_color("font_selected_color", "Tree", FOAM)
	theme.set_color("font_hovered_color", "Tree", FOAM)
	theme.set_color("guide_color", "Tree", Color(GOLD_DIM, 0.25))
	theme.set_constant("draw_guides", "Tree", 1)
	theme.set_constant("v_separation", "Tree", 6)
	theme.set_constant("h_separation", "Tree", 8)
	theme.set_constant("inner_item_margin_left", "Tree", 6)
	theme.set_constant("inner_item_margin_right", "Tree", 6)
	theme.set_icon("checked", "Tree", check_icon(1))
	theme.set_icon("unchecked", "Tree", check_icon(0))
	theme.set_icon("indeterminate", "Tree", check_icon(2))
	theme.set_icon("checked_disabled", "Tree", check_icon(1))
	theme.set_icon("unchecked_disabled", "Tree", check_icon(0))
	theme.set_icon("indeterminate_disabled", "Tree", check_icon(2))


static func _style_split(theme: Theme) -> void:
	for kind in ["HSplitContainer", "VSplitContainer", "SplitContainer"]:
		theme.set_constant("separation", kind, 10)
		theme.set_constant("minimum_grab_thickness", kind, 10)
		theme.set_constant("autohide", kind, 0)
	theme.set_icon("grabber", "HSplitContainer", grip_icon(false))
	theme.set_icon("grabber", "VSplitContainer", grip_icon(true))
	theme.set_icon("h_grabber", "SplitContainer", grip_icon(false))
	theme.set_icon("v_grabber", "SplitContainer", grip_icon(true))


## 0 clear, 1 ticked, 2 some. Square, like the rest of the chest.
static func check_icon(state: int) -> ImageTexture:
	var n := 16
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if state == 1:
		image.fill_rect(Rect2i(0, 0, n, n), GOLD)
		var tick := [
			Vector2i(3, 8), Vector2i(4, 9), Vector2i(5, 10), Vector2i(6, 11),
			Vector2i(7, 10), Vector2i(8, 9), Vector2i(9, 8), Vector2i(10, 7),
			Vector2i(11, 6), Vector2i(12, 5),
		]
		for p in tick:
			image.fill_rect(Rect2i(p.x, p.y - 1, 2, 2), INK)
		return ImageTexture.create_from_image(image)
	var edge := GOLD if state == 2 else SEA
	image.fill_rect(Rect2i(0, 0, n, n), edge)
	image.fill_rect(Rect2i(1, 1, n - 2, n - 2), INK)
	if state == 2:
		image.fill_rect(Rect2i(4, 7, n - 8, 2), GOLD)
	return ImageTexture.create_from_image(image)


static func toggle_icon(on: bool) -> ImageTexture:
	var w := 30
	var h := 16
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var edge := GOLD if on else SEA
	image.fill_rect(Rect2i(0, 0, w, h), edge)
	image.fill_rect(Rect2i(1, 1, w - 2, h - 2), INK)
	var knob_x := w - 13 if on else 3
	image.fill_rect(Rect2i(knob_x, 3, 10, h - 6), edge)
	return ImageTexture.create_from_image(image)


static func grip_icon(vertical: bool) -> ImageTexture:
	var w := 16 if vertical else 4
	var h := 4 if vertical else 16
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in 3:
		var at := 2 + i * 5
		if vertical:
			image.fill_rect(Rect2i(at, 1, 2, 2), GOLD_DIM)
		else:
			image.fill_rect(Rect2i(1, at, 2, 2), GOLD_DIM)
	return ImageTexture.create_from_image(image)


## A small outlined tag: ABOARD, CACHED, COLLECTION.
static func badge(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_stylebox_override("normal", _box(colour, Color(colour, 0.12), 5, 0, 1))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


## A flat surface for grouping inside a panel.
static func well(fill: Color = INK, pad: int = 10) -> StyleBoxFlat:
	return _box(fill, fill, pad, pad, 0)


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
	b.add_theme_stylebox_override("disabled", _box(Color(GOLD_DIM, 0.35), INK, 8, 3, 1))
	b.add_theme_color_override("font_disabled_color", Color(SEA, 0.5))
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
