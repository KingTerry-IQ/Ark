extends Control

## Two panes. BROWSE finds an item, on the Archive or already aboard.
## ITEM picks its files and opens or inscribes them. Search and OPEN work
## without a host. Inscribe and Feature wait until GodOnChain is attached.

const CFG := "user://ark.cfg"
const CHAINS := ["mon", "sol", "rh"]
const CHAIN_NAMES := {"mon": "Monad", "sol": "Solana", "rh": "Robinhood"}
const FILE_COL_NAME := 0
const FILE_COL_FORMAT := 1
const FILE_COL_SIZE := 2
const FILE_COL_STATE := 3

var chain := "mon"
var cache := ArkCache.new()
var iq: IQClient
var fetch: Fetch
var busy := false
var item: Dictionary = {}
var docs: Array = []
var page := 1
var mediatype := ""
var sort_key := "downloads"
var collection_id := ""
var collection_title := ""
var kind_slug := ""
var kind_title := ""
var show_all := false
var _trail: Array = []
var _catalog := 0
var _progress_note := ""
var _stage_lock := false
var stage_files: Array = []
var picked := {}
var file_filter: LineEdit
var file_type := ""
var file_sort := "format"
var file_sort_desc := false
var _shown_files: Array = []
var _filter_timer: Timer
var stage_note: Label
var _thumb_token := 0
var _thumb_inflight := 0
var _thumb_queue: Array = []
var _thumbs := {}

var host_label: Label
var cache_label: Label
var status_label: Label
var chain_buttons: Array = []
var tab_buttons: Array = []
var archive_view: Control
var aboard_view: Control
var stage_empty: Control
var stage_body: Control
var stage_title: Label
var stage_byline: Label
var stage_ident: Label
var stage_badges: HBoxContainer
var stage_about: Label
var stage_thumb: TextureRect
var stage_feature: Button
var file_tree: Tree
var files_empty: Label
var type_box: HFlowContainer
var derivatives_toggle: CheckButton
var select_note: Label
var quote_label: Label
var quote_others: Label
var sol_note: Label
var host_hint: Label
var open_button: Button
var inscribe_button: Button
var preview_box: Control
var preview_title: Label
var preview: RichTextLabel
var picture: TextureRect
var featured_box: HFlowContainer
var place_row: HBoxContainer
var place_label: Label
var count_label: Label
var page_label: Label
var empty_label: Label
var results_box: VBoxContainer
var results_scroll: ScrollContainer
var sort_box: OptionButton
var pager_prev: Button
var pager_next: Button
var media_buttons: Array = []
var search_box: LineEdit
var add_row: HBoxContainer
var add_box: LineEdit
var aboard_filter: LineEdit
var aboard_box: VBoxContainer
var aboard_note: Label
var found_count := -1
var _manifest: Array = []
var _kind_rows: Array = []
var _aboard_ids := {}
var _aboard_page := {}


func _ready() -> void:
	theme = ArkTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_cfg()
	fetch = Fetch.new()
	add_child(fetch)
	fetch.progressed.connect(_on_progress)
	iq = IQClient.new()
	add_child(iq)
	_build()
	_refresh_cache()
	_apply_mirror()
	_show_invitation()
	_discover()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F and key.ctrl_pressed:
		if stage_body.visible and key.shift_pressed:
			file_filter.grab_focus()
		else:
			_show_tab(0)
			search_box.grab_focus()
			search_box.select_all()
		accept_event()
	elif key.keycode == KEY_ESCAPE and preview_box.visible:
		preview_box.visible = false
		accept_event()


func _load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		chain = Costs.code(str(cfg.get_value("ark", "chain", "mon")))


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("ark", "chain", chain)
	if not cfg.has_section_key("ark", "cache_limit_bytes"):
		cfg.set_value("ark", "cache_limit_bytes", Ark.CACHE_LIMIT_DEFAULT)
	cfg.save(CFG)


func _cache_limit() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK:
		return Ark.CACHE_LIMIT_DEFAULT
	return int(cfg.get_value("ark", "cache_limit_bytes", Ark.CACHE_LIMIT_DEFAULT))


func _build() -> void:
	var wash := ColorRect.new()
	wash.color = ArkTheme.INK
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 10
	root.offset_right = -16
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(_top_bar())
	root.add_child(ArkTheme.rule(ArkTheme.GOLD_DIM))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var browse := _browse_pane()
	browse.size_flags_stretch_ratio = 1.0
	browse.custom_minimum_size = Vector2(440, 0)
	split.add_child(browse)
	var stage := _stage_pane()
	stage.size_flags_stretch_ratio = 1.25
	stage.custom_minimum_size = Vector2(560, 0)
	split.add_child(stage)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)
	status_label = ArkTheme.cell("Search the Archive. Pick an item. Choose its files.", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	foot.add_child(status_label)
	var keys := ArkTheme.cell("Ctrl+F search   Ctrl+Shift+F filter files   double-click a file to open it", ArkTheme.GOLD_DIM, ArkTheme.SIZE_SMALL)
	keys.size_flags_horizontal = Control.SIZE_SHRINK_END
	keys.clip_text = false
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(keys)


func _top_bar() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var mark := ArkTheme.mark()
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(mark)
	var word := ArkTheme.title("ARK")
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(word)
	var tag := ArkTheme.cell("Internet Archive, kept on chain", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tag)

	var chains := HBoxContainer.new()
	chains.add_theme_constant_override("separation", 0)
	chains.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(chains)
	chains.add_child(_spaced(ArkTheme.cell("CHAIN", ArkTheme.GOLD_DIM, ArkTheme.SIZE_SMALL), 8))
	for at in CHAINS.size():
		var code: String = CHAINS[at]
		var b := ArkTheme.choice(code.to_upper(), code == chain, _on_chain.bind(at))
		b.tooltip_text = "%s · fees in %s" % [CHAIN_NAMES[code], Costs.token(code)]
		chains.add_child(b)
		chain_buttons.append(b)

	host_label = ArkTheme.badge("HOST …", ArkTheme.SEA)
	host_label.add_theme_font_size_override("font_size", ArkTheme.SIZE_SMALL)
	top.add_child(host_label)

	cache_label = ArkTheme.cell("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	cache_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cache_label.clip_text = false
	cache_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	cache_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cache_label.tooltip_text = "Files opened or staged for inscription are kept on this machine."
	cache_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(cache_label)
	var clear_all := ArkTheme.quiet_button("CLEAR CACHE", _clear_all)
	clear_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clear_all.tooltip_text = "Delete every cached file on this machine. The chain is not touched."
	top.add_child(clear_all)
	return top


func _spaced(control: Control, right: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_right", right)
	margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(control)
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return margin


func _pane_box(pane: PanelContainer) -> VBoxContainer:
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 6)
	pane.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inner.add_child(box)
	return box


func _browse_pane() -> Control:
	var pane := ArkTheme.panel()
	var box := _pane_box(pane)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	box.add_child(tabs)
	for at in 2:
		var label := "ARCHIVE" if at == 0 else "ABOARD"
		var b := ArkTheme.choice(label, at == 0, _show_tab.bind(at))
		b.custom_minimum_size = Vector2(120, 30)
		tabs.add_child(b)
		tab_buttons.append(b)
	tab_buttons[0].tooltip_text = "Search and browse the Internet Archive."
	tab_buttons[1].tooltip_text = "What the selected chain already holds."
	archive_view = _archive_view()
	box.add_child(archive_view)
	aboard_view = _aboard_view()
	aboard_view.visible = false
	box.add_child(aboard_view)
	return pane


func _show_tab(at: int) -> void:
	archive_view.visible = at == 0
	aboard_view.visible = at == 1
	for i in tab_buttons.size():
		ArkTheme.paint_choice(tab_buttons[i], i == at)


func _archive_view() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search titles, creators, collections"
	search_box.custom_minimum_size = Vector2(0, 36)
	search_box.clear_button_enabled = true
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_submitted.connect(func(_t: String) -> void: _search_fresh())
	row.add_child(search_box)
	var go := ArkTheme.primary_button("SEARCH", _search_fresh)
	go.custom_minimum_size = Vector2(96, 0)
	row.add_child(go)
	var media := HFlowContainer.new()
	media.add_theme_constant_override("h_separation", 4)
	media.add_theme_constant_override("v_separation", 4)
	media.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(media)
	for pair in Archive.MEDIATYPES:
		var chip := _media_chip(str(pair[0]), str(pair[1]))
		media.add_child(chip)
		media_buttons.append({"kind": str(pair[0]), "button": chip})
	featured_box = HFlowContainer.new()
	featured_box.add_theme_constant_override("h_separation", 4)
	featured_box.add_theme_constant_override("v_separation", 4)
	featured_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	featured_box.visible = false
	box.add_child(featured_box)

	place_row = HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 8)
	place_row.visible = false
	box.add_child(place_row)
	var back := ArkTheme.quiet_button("‹ BACK", _back)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place_row.add_child(back)
	place_label = ArkTheme.cell("", ArkTheme.GOLD, ArkTheme.SIZE_BODY)
	place_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place_row.add_child(place_label)
	var feature := ArkTheme.quiet_button("FEATURE", _feature_current)
	feature.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feature.tooltip_text = "Put this collection on the featured band so others help finish it."
	place_row.add_child(feature)
	var check := ArkTheme.quiet_button("CHECK", _check_current)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.tooltip_text = "Count how much of this collection is aboard."
	place_row.add_child(check)
	add_row = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	add_row.visible = false
	box.add_child(add_row)
	add_box = LineEdit.new()
	add_box.placeholder_text = "Add an identifier to this shelf"
	add_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_box.text_submitted.connect(func(_text: String) -> void: _add_to_kind())
	add_row.add_child(add_box)
	var add := ArkTheme.quiet_button("ADD", _add_to_kind)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_row.add_child(add)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	meta.visible = false
	box.add_child(meta)
	count_label = ArkTheme.cell("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(count_label)
	sort_box = OptionButton.new()
	sort_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort_box.add_theme_font_size_override("font_size", ArkTheme.SIZE_SMALL)
	sort_box.tooltip_text = "Sort results"
	for label in ["Relevance", "Most downloaded", "Newest published", "Newest archived", "Title A–Z"]:
		sort_box.add_item(label)
	sort_box.selected = 1
	sort_box.item_selected.connect(_on_sort)
	meta.add_child(sort_box)
	pager_prev = ArkTheme.quiet_button("‹", _page_prev)
	pager_prev.custom_minimum_size = Vector2(28, 0)
	pager_prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(pager_prev)
	page_label = ArkTheme.cell("", ArkTheme.PARCHMENT, ArkTheme.SIZE_SMALL)
	page_label.clip_text = false
	page_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(page_label)
	pager_next = ArkTheme.quiet_button("›", _page_next)
	pager_next.custom_minimum_size = Vector2(28, 0)
	pager_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(pager_next)

	empty_label = ArkTheme.line("", ArkTheme.SEA, ArkTheme.SIZE_BODY)
	empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.visible = false
	box.add_child(empty_label)
	results_scroll = ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.visible = false
	box.add_child(results_scroll)
	results_box = VBoxContainer.new()
	results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_box.add_theme_constant_override("separation", 0)
	results_scroll.add_child(results_box)
	return box


func _aboard_view() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	aboard_note = ArkTheme.line(
		"The cabinet is the manifest on the selected chain. It fills when a host is attached.",
		ArkTheme.SEA,
		ArkTheme.SIZE_SMALL
	)
	aboard_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(aboard_note)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	box.add_child(tools)
	aboard_filter = LineEdit.new()
	aboard_filter.placeholder_text = "Filter the cabinet"
	aboard_filter.clear_button_enabled = true
	aboard_filter.custom_minimum_size = Vector2(0, 36)
	aboard_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aboard_filter.text_changed.connect(func(_text: String) -> void:
		_aboard_page.clear()
		_paint_aboard()
	)
	tools.add_child(aboard_filter)
	var repair := ArkTheme.quiet_button("REPAIR", _repair_aboard)
	repair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	repair.tooltip_text = "Add manifest rows for item tables that are complete but unlisted."
	tools.add_child(repair)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	aboard_box = VBoxContainer.new()
	aboard_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aboard_box.add_theme_constant_override("separation", 0)
	scroll.add_child(aboard_box)
	return box


func _stage_pane() -> Control:
	var pane := ArkTheme.panel()
	var holder := _pane_box(pane)
	stage_empty = _stage_welcome()
	holder.add_child(stage_empty)
	stage_body = VBoxContainer.new()
	stage_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_body.add_theme_constant_override("separation", 10)
	stage_body.visible = false
	holder.add_child(stage_body)
	var box := stage_body

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ArkTheme.well(ArkTheme.HULL_RAISED, 0))
	frame.custom_minimum_size = Vector2(128, 96)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(frame)
	stage_thumb = TextureRect.new()
	stage_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(stage_thumb)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	head.add_child(words)
	stage_title = ArkTheme.line("", ArkTheme.FOAM, ArkTheme.SIZE_DISPLAY)
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_title.max_lines_visible = 2
	stage_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(stage_title)
	stage_byline = ArkTheme.cell("", ArkTheme.WATER, ArkTheme.SIZE_SMALL)
	words.add_child(stage_byline)
	var ident_row := HBoxContainer.new()
	ident_row.add_theme_constant_override("separation", 6)
	words.add_child(ident_row)
	stage_badges = HBoxContainer.new()
	stage_badges.add_theme_constant_override("separation", 6)
	ident_row.add_child(stage_badges)
	stage_ident = ArkTheme.cell("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	stage_ident.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ident_row.add_child(stage_ident)
	stage_about = ArkTheme.line("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	stage_about.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_about.max_lines_visible = 2
	stage_about.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(stage_about)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	head.add_child(side)
	var web := ArkTheme.quiet_button("ARCHIVE.ORG ↗", _open_details)
	web.tooltip_text = "Open this item's page on archive.org"
	side.add_child(web)
	stage_feature = ArkTheme.quiet_button("FEATURE", _feature_item)
	stage_feature.tooltip_text = "Feature this item so others help bring all of it aboard."
	side.add_child(stage_feature)
	var forget := ArkTheme.quiet_button("CLEAR CACHE", _clear_item)
	forget.tooltip_text = "Delete this item's cached files on this machine. The chain is not touched."
	side.add_child(forget)

	box.add_child(ArkTheme.rule(ArkTheme.GOLD_DIM))

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	box.add_child(tools)
	file_filter = LineEdit.new()
	file_filter.placeholder_text = "Filter files by name"
	file_filter.clear_button_enabled = true
	file_filter.custom_minimum_size = Vector2(0, 32)
	file_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_filter.text_changed.connect(func(_text: String) -> void: _filter_timer.start())
	tools.add_child(file_filter)
	_filter_timer = Timer.new()
	_filter_timer.one_shot = true
	_filter_timer.wait_time = 0.15
	_filter_timer.timeout.connect(_on_file_filter)
	add_child(_filter_timer)
	derivatives_toggle = CheckButton.new()
	derivatives_toggle.text = "Derivatives"
	derivatives_toggle.focus_mode = Control.FOCUS_NONE
	derivatives_toggle.tooltip_text = "Also list files the Archive generated from the originals: thumbnails, transcodes, metadata."
	derivatives_toggle.toggled.connect(_toggle_derivatives)
	tools.add_child(derivatives_toggle)

	var picks := HBoxContainer.new()
	picks.add_theme_constant_override("separation", 6)
	box.add_child(picks)
	type_box = HFlowContainer.new()
	type_box.add_theme_constant_override("h_separation", 4)
	type_box.add_theme_constant_override("v_separation", 4)
	type_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picks.add_child(type_box)
	var all := ArkTheme.quiet_button("SELECT SHOWN", _select_shown.bind(true))
	all.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	all.tooltip_text = "Tick every file the filter and type currently show."
	picks.add_child(all)
	var none := ArkTheme.quiet_button("CLEAR", _select_none)
	none.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	none.tooltip_text = "Untick every file."
	picks.add_child(none)

	file_tree = Tree.new()
	file_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	file_tree.columns = 4
	file_tree.hide_root = true
	file_tree.column_titles_visible = true
	file_tree.select_mode = Tree.SELECT_ROW
	file_tree.allow_reselect = true
	file_tree.set_column_expand(FILE_COL_NAME, true)
	file_tree.set_column_clip_content(FILE_COL_NAME, true)
	for col in [FILE_COL_FORMAT, FILE_COL_SIZE, FILE_COL_STATE]:
		file_tree.set_column_expand(col, false)
	file_tree.set_column_custom_minimum_width(FILE_COL_FORMAT, 140)
	file_tree.set_column_custom_minimum_width(FILE_COL_SIZE, 116)
	file_tree.set_column_custom_minimum_width(FILE_COL_STATE, 72)
	file_tree.set_column_title_alignment(FILE_COL_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	file_tree.item_edited.connect(_on_file_edited)
	file_tree.item_activated.connect(_on_file_activated)
	file_tree.column_title_clicked.connect(_on_file_sort)
	box.add_child(file_tree)
	_paint_file_titles()
	files_empty = ArkTheme.line("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	files_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	files_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	files_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	files_empty.visible = false
	file_tree.add_child(files_empty)

	preview_box = _preview_drawer()
	box.add_child(preview_box)

	box.add_child(_action_bar())
	return pane


func _stage_welcome() -> Control:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var big := ArkTheme.mark()
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(big)
	box.add_child(ArkTheme.line("No item open", ArkTheme.GOLD, ArkTheme.SIZE_DISPLAY))
	var steps := [
		["1", "Find it", "Search the Archive, open a collection, or browse what is already aboard."],
		["2", "Pick the files", "Click an item. Filter by name or type, tick what to keep."],
		["3", "Open or inscribe", "OPEN reads it on this machine. INSCRIBE writes it to the chain."],
	]
	for step in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var n := ArkTheme.badge(str(step[0]), ArkTheme.GOLD)
		n.add_theme_font_size_override("font_size", ArkTheme.SIZE_BODY)
		n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(n)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 2)
		row.add_child(words)
		var head := ArkTheme.line(str(step[1]), ArkTheme.PARCHMENT, ArkTheme.SIZE_BODY)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.add_child(head)
		var tip := ArkTheme.line(str(step[2]), ArkTheme.SEA, ArkTheme.SIZE_SMALL)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.add_child(tip)
	return center


func _preview_drawer() -> Control:
	var drawer := PanelContainer.new()
	drawer.add_theme_stylebox_override("panel", ArkTheme.well(ArkTheme.INK, 8))
	drawer.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	drawer.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	preview_title = ArkTheme.cell("", ArkTheme.GOLD, ArkTheme.SIZE_SMALL)
	preview_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(preview_title)
	head.add_child(ArkTheme.quiet_button("CLOSE", func() -> void: drawer.visible = false))
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(0, 200)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.visible = false
	box.add_child(picture)
	preview = RichTextLabel.new()
	preview.custom_minimum_size = Vector2(0, 200)
	preview.scroll_active = true
	preview.selection_enabled = true
	preview.visible = false
	box.add_child(preview)
	return drawer


func _action_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", ArkTheme.well(ArkTheme.HULL_RAISED, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	var picked_box := VBoxContainer.new()
	picked_box.add_theme_constant_override("separation", 2)
	picked_box.custom_minimum_size = Vector2(190, 0)
	row.add_child(picked_box)
	select_note = ArkTheme.cell("Nothing selected", ArkTheme.PARCHMENT, ArkTheme.SIZE_BODY)
	picked_box.add_child(select_note)
	stage_note = ArkTheme.cell("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	picked_box.add_child(stage_note)
	var cost_box := VBoxContainer.new()
	cost_box.add_theme_constant_override("separation", 2)
	cost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cost_box)
	quote_label = ArkTheme.cell("", ArkTheme.GOLD, ArkTheme.SIZE_BODY)
	quote_label.tooltip_text = "Estimated fees to write the selected files, their item card and manifest row."
	quote_label.mouse_filter = Control.MOUSE_FILTER_PASS
	cost_box.add_child(quote_label)
	quote_others = ArkTheme.line("", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	quote_others.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_box.add_child(quote_others)
	sol_note = ArkTheme.line(
		"Solana's approval chunks at 3400 bytes. The write path chunks at 850, so the real fee runs higher.",
		ArkTheme.CLAY,
		ArkTheme.SIZE_SMALL
	)
	sol_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sol_note.visible = false
	cost_box.add_child(sol_note)
	host_hint = ArkTheme.line("No host attached. Launch Ark from GodOnChain to inscribe.", ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	host_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	host_hint.visible = false
	cost_box.add_child(host_hint)
	open_button = ArkTheme.button("OPEN", _open_checked)
	open_button.custom_minimum_size = Vector2(96, 40)
	open_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_button.tooltip_text = "Download the selected files to this machine and open them."
	row.add_child(open_button)
	inscribe_button = ArkTheme.primary_button("INSCRIBE", _inscribe_checked)
	inscribe_button.custom_minimum_size = Vector2(128, 40)
	inscribe_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inscribe_button.tooltip_text = "Write the selected files to the chain. You approve each write in GodOnChain."
	row.add_child(inscribe_button)
	_sync_actions()
	return bar


func _sync_actions() -> void:
	if open_button == null:
		return
	var count := _selected_files().size()
	var none := item.is_empty() or count == 0
	open_button.disabled = none
	inscribe_button.disabled = none
	var hosted := iq != null and iq.is_available()
	host_hint.visible = not hosted and not item.is_empty()


func _on_chain(index: int) -> void:
	chain = CHAINS[index]
	for at in chain_buttons.size():
		ArkTheme.paint_choice(chain_buttons[at], at == index)
	_save_cfg()
	sol_note.visible = chain == "sol"
	_quote()
	await _refresh_board()


func _discover() -> void:
	var ok: bool = await iq.discover()
	var colour := ArkTheme.GREEN if ok else ArkTheme.SEA
	if ok:
		host_label.text = "● %s" % iq.app_label
		host_label.tooltip_text = "GodOnChain is attached. Inscribe, Feature and read-back are available."
	else:
		host_label.text = "○ NO HOST · BROWSE ONLY"
		host_label.tooltip_text = "Search and OPEN work now. Launch Ark from GodOnChain to inscribe."
	host_label.mouse_filter = Control.MOUSE_FILTER_PASS
	host_label.add_theme_color_override("font_color", colour)
	host_label.add_theme_stylebox_override("normal", ArkTheme._box(colour, Color(colour, 0.1), 8, 3, 1))
	_sync_actions()
	await _refresh_board()


func _search_fresh() -> void:
	if not kind_slug.is_empty():
		kind_slug = ""
		kind_title = ""
		_paint_place()
	page = 1
	await _run_search()


func _run_search() -> void:
	if busy or not kind_slug.is_empty():
		return
	var query := Archive.search_query(search_box.text, mediatype, collection_id)
	_catalog += 1
	var token := _catalog
	fetch.cancel()
	if query.is_empty():
		_progress_note = ""
		_show_invitation()
		return
	var waiting := "Opening %s" % collection_title if not collection_id.is_empty() else "Searching"
	_show_tab(0)
	_show_wait(waiting)
	await get_tree().process_frame
	if token != _catalog:
		return
	_progress_note = waiting
	var body := await _get_text(Archive.search_url(query, page, Archive.PAGE_ROWS, sort_key))
	if token != _catalog:
		return
	_progress_note = ""
	if body.is_empty():
		empty_label.text = "The Archive did not answer."
		_status("Search failed. %s" % fetch.last_error)
		return
	_status("Reading the page…")
	await get_tree().process_frame
	if token != _catalog:
		return
	var parsed := Archive.parse_search(body)
	var found := int(parsed.get("num_found", 0))
	var window := Archive.page_window(page, Archive.PAGE_ROWS, found)
	page = int(window.get("page", 1))
	docs = parsed.get("docs", [])
	_paint_hits(found, window)
	_status(Archive.result_count(window, found))


func _show_wait(text: String) -> void:
	_thumb_token += 1
	_clear_results()
	results_scroll.visible = false
	_meta().visible = false
	empty_label.visible = true
	empty_label.text = text + "…"
	_status(empty_label.text)


func _show_invitation() -> void:
	docs = []
	_thumb_token += 1
	_clear_results()
	_meta().visible = false
	results_scroll.visible = false
	empty_label.visible = true
	empty_label.text = "Search by title, creator or collection.\nOr pick a mediatype above to browse the most downloaded."
	_status("Search the Archive. A mediatype narrows it.")


func _paint_hits(found: int, window: Dictionary) -> void:
	_clear_results()
	var meta := _meta()
	meta.visible = true
	var counted := Archive.result_count(window, found).split("  ·  ")
	count_label.text = counted[0]
	count_label.tooltip_text = "Only the " + counted[1] + "." if counted.size() > 1 else ""
	count_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var pages := int(window.get("pages", 0))
	pager_prev.disabled = page <= 1
	pager_next.disabled = pages == 0 or page >= pages
	page_label.visible = pages > 1
	page_label.text = "%s / %s" % [Archive.grouped(page), Archive.grouped(pages)]
	pager_prev.visible = pages > 1
	pager_next.visible = pages > 1
	found_count = found
	empty_label.visible = found <= 0
	empty_label.text = "Nothing matches this search."
	if sort_box != null:
		sort_box.visible = true
	results_scroll.visible = found > 0
	results_scroll.scroll_vertical = 0
	var thumbs: Array = []
	for doc in docs:
		if not doc is Dictionary:
			continue
		var hit := Archive.present_hit(doc)
		var built := _hit_row(hit)
		results_box.add_child(built["row"])
		thumbs.append({"id": str(hit.get("identifier", "")), "rect": built["thumb"]})
	_queue_thumbs(thumbs)


func _clear_results() -> void:
	for child in results_box.get_children():
		child.queue_free()


func _meta() -> HBoxContainer:
	return count_label.get_parent() as HBoxContainer


func _media_chip(kind: String, label: String) -> Button:
	return ArkTheme.choice(label, kind == mediatype, func() -> void: await _set_mediatype(kind))


func _set_mediatype(kind: String) -> void:
	if busy or kind == mediatype:
		return
	mediatype = kind
	for entry in media_buttons:
		ArkTheme.paint_choice(entry["button"], str(entry["kind"]) == mediatype)
	page = 1
	await _run_search()


func _on_sort(index: int) -> void:
	var keys := PackedStringArray(["relevance", "downloads", "published", "archived", "title"])
	if index < 0 or index >= keys.size():
		return
	var next := keys[index]
	if next == sort_key:
		return
	sort_key = next
	page = 1
	await _run_search()


func _page_prev() -> void:
	if busy or page <= 1:
		return
	page -= 1
	await _run_search()


func _page_next() -> void:
	if busy:
		return
	page += 1
	await _run_search()


func _open_hit(hit: Dictionary) -> void:
	if busy:
		return
	if str(hit.get("mediatype", "")) == "collection":
		await _enter_collection(hit)
		return
	await _load_item(str(hit.get("identifier", "")))


func _enter_collection(hit: Dictionary) -> void:
	if busy:
		return
	var identifier := str(hit.get("identifier", "")).strip_edges()
	if identifier.is_empty():
		return
	_trail.append(_capture())
	kind_slug = ""
	kind_title = ""
	collection_id = identifier
	collection_title = str(hit.get("title", identifier))
	mediatype = ""
	page = 1
	search_box.text = ""
	for entry in media_buttons:
		ArkTheme.paint_choice(entry["button"], str(entry["kind"]) == mediatype)
	_paint_place()
	await _run_search()


func _back() -> void:
	if busy:
		return
	_catalog += 1
	fetch.cancel()
	_progress_note = ""
	if _trail.is_empty():
		collection_id = ""
		collection_title = ""
		kind_slug = ""
		kind_title = ""
		_paint_place()
		_show_invitation()
		return
	var prev: Dictionary = _trail.pop_back()
	search_box.text = str(prev.get("text", ""))
	mediatype = str(prev.get("mediatype", ""))
	sort_key = str(prev.get("sort", "downloads"))
	page = int(prev.get("page", 1))
	collection_id = str(prev.get("collection_id", ""))
	collection_title = str(prev.get("collection_title", ""))
	kind_slug = str(prev.get("kind_slug", ""))
	kind_title = str(prev.get("kind_title", ""))
	_sync_sort()
	for entry in media_buttons:
		ArkTheme.paint_choice(entry["button"], str(entry["kind"]) == mediatype)
	_paint_place()
	if not kind_slug.is_empty():
		_paint_kind()
		return
	if collection_id.is_empty() and search_box.text.strip_edges().is_empty() and mediatype.is_empty():
		_show_invitation()
		return
	await _run_search()


func _capture() -> Dictionary:
	return {
		"text": search_box.text,
		"mediatype": mediatype,
		"sort": sort_key,
		"page": page,
		"collection_id": collection_id,
		"collection_title": collection_title,
		"kind_slug": kind_slug,
		"kind_title": kind_title,
	}


func _paint_place() -> void:
	var on_kind := not kind_slug.is_empty()
	var inside := on_kind or not collection_id.is_empty()
	place_row.visible = inside
	if add_row != null:
		add_row.visible = on_kind
	place_label.text = kind_title if on_kind else collection_title
	search_box.placeholder_text = (
		"Search this collection" if not on_kind and not collection_id.is_empty()
		else "Search titles, creators, collections"
	)


func _sync_sort() -> void:
	var keys := PackedStringArray(["relevance", "downloads", "published", "archived", "title"])
	var index := keys.find(sort_key)
	if index < 0:
		index = 1
		sort_key = "downloads"
	sort_box.selected = index


func _featured_chip(label: String, title: String, ia: String, slug: String) -> Button:
	var shown := label if not label.is_empty() else title
	return ArkTheme.choice(shown, false, func() -> void:
		if not ia.is_empty():
			await _enter_collection({"identifier": ia, "title": title, "mediatype": "collection"})
		else:
			await _open_kind(slug, title, true)
	)


## A clickable list row. It stays lit while its item is the one open.
func _clickable_row(ident: String, on_click: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("ident", ident)
	panel.set_meta("hot", false)
	_paint_row(panel)
	panel.mouse_entered.connect(func() -> void:
		panel.set_meta("hot", true)
		_paint_row(panel)
	)
	panel.mouse_exited.connect(func() -> void:
		panel.set_meta("hot", false)
		_paint_row(panel)
	)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				panel.accept_event()
				await on_click.call()
	)
	return panel


func _paint_row(panel: PanelContainer) -> void:
	var staged := not item.is_empty() and str(panel.get_meta("ident", "")) == str(item.get("identifier", ""))
	panel.add_theme_stylebox_override("panel", _row_box(bool(panel.get_meta("hot", false)), staged))


func _paint_rows() -> void:
	for list in [results_box, aboard_box]:
		if list == null:
			continue
		for child in list.get_children():
			if child is PanelContainer and child.has_meta("ident"):
				_paint_row(child)


func _hit_row(hit: Dictionary) -> Dictionary:
	var ident := str(hit.get("identifier", ""))
	var panel := _clickable_row(ident, func() -> void: await _open_hit(hit))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(80, 60)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var wash := ColorRect.new()
	wash.color = ArkTheme.HULL_RAISED
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(wash)
	var thumb := TextureRect.new()
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(thumb)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)
	var title := Label.new()
	title.text = str(hit.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", ArkTheme.SIZE_BODY)
	title.add_theme_color_override("font_color", ArkTheme.PARCHMENT)
	words.add_child(title)
	var tags := HBoxContainer.new()
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.add_theme_constant_override("separation", 6)
	words.add_child(tags)
	if str(hit.get("mediatype", "")) == "collection":
		tags.add_child(ArkTheme.badge("COLLECTION ›", ArkTheme.WATER))
	if _aboard_ids.has(ident):
		tags.add_child(ArkTheme.badge("ABOARD", ArkTheme.LAMP))
	var by := ArkTheme.cell(Archive.byline(hit), ArkTheme.WATER, ArkTheme.SIZE_SMALL)
	by.mouse_filter = Control.MOUSE_FILTER_IGNORE
	by.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tags.add_child(by)
	var blurb := str(hit.get("description", ""))
	if not blurb.is_empty():
		var about := Label.new()
		about.text = blurb
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.max_lines_visible = 2
		about.mouse_filter = Control.MOUSE_FILTER_IGNORE
		about.add_theme_font_size_override("font_size", ArkTheme.SIZE_SMALL)
		about.add_theme_color_override("font_color", ArkTheme.SEA)
		words.add_child(about)
	return {"row": panel, "thumb": thumb}


func _row_box(hot: bool, staged: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ArkTheme.HULL_RAISED if hot or staged else Color(0, 0, 0, 0)
	box.draw_center = hot or staged
	box.set_corner_radius_all(0)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.border_color = ArkTheme.GOLD if hot or staged else Color(ArkTheme.GOLD_DIM, 0.45)
	box.border_width_bottom = 1
	if hot or staged:
		box.border_width_left = 3
		box.content_margin_left = 6
	return box


func _queue_thumbs(pairs: Array) -> void:
	_thumb_token += 1
	var token := _thumb_token
	_thumb_queue.clear()
	for pair in pairs:
		var id := str(pair.get("id", ""))
		var rect: TextureRect = pair.get("rect")
		if id.is_empty() or rect == null:
			continue
		if _thumbs.has(id):
			rect.texture = _thumbs[id]
			continue
		_thumb_queue.append({"id": id, "rect": rect, "token": token})
	_pump_thumbs()


func _pump_thumbs() -> void:
	while _thumb_inflight < 4 and not _thumb_queue.is_empty():
		var job: Dictionary = _thumb_queue.pop_front()
		if int(job.get("token", -1)) != _thumb_token:
			continue
		_thumb_inflight += 1
		_fetch_thumb(job)


func _fetch_thumb(job: Dictionary) -> void:
	var http := HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_thumb_inflight = maxi(_thumb_inflight - 1, 0)
		if int(job.get("token", -1)) == _thumb_token and result == HTTPRequest.RESULT_SUCCESS and code == 200 and not body.is_empty():
			var image := Image.new()
			if Archive.decode_image(body, image):
				var texture := ImageTexture.create_from_image(image)
				var id := str(job.get("id", ""))
				_thumbs[id] = texture
				if _thumbs.size() > 80:
					_thumbs.clear()
					_thumbs[id] = texture
				var rect: TextureRect = job.get("rect")
				if is_instance_valid(rect):
					rect.texture = texture
		if is_instance_valid(http):
			http.queue_free()
		_pump_thumbs()
	)
	var err := http.request(
		Archive.thumb_url(str(job.get("id", ""))),
		["User-Agent: %s" % Archive.USER_AGENT]
	)
	if err != OK:
		_thumb_inflight = maxi(_thumb_inflight - 1, 0)
		http.queue_free()
		_pump_thumbs()


func _load_item(identifier: String) -> void:
	if busy or identifier.is_empty():
		return
	_catalog += 1
	fetch.cancel()
	busy = true
	_progress_note = "Reading %s" % identifier
	_status(_progress_note)
	var body := await _get_text(Archive.metadata_url(identifier))
	_progress_note = ""
	if body.is_empty():
		busy = false
		if fetch.last_error != "Cancelled.":
			_status("Metadata failed.")
		return
	_status("Reading the file list…")
	await get_tree().process_frame
	var parsed := Archive.parse_metadata(body)
	if (parsed.get("files", []) as Array).is_empty() and str(parsed.get("title", "")).is_empty():
		busy = false
		_status("The Archive has no item called %s, or it is dark." % identifier)
		return
	item = parsed
	item["from_chain"] = false
	if str(item.get("identifier", "")).is_empty():
		item["identifier"] = identifier
	_fill_stage()
	busy = false
	_status("Staged %s. %s files." % [identifier, Archive.grouped(stage_files.size())])


func _fill_stage() -> void:
	var identifier := str(item.get("identifier", ""))
	# A refill of the same item (the derivatives toggle) keeps what was ticked.
	var kept := {}
	var same := identifier == str(stage_body.get_meta("ident", ""))
	if same:
		for file in _selected_files():
			kept[str((file as Dictionary).get("name", ""))] = true
	stage_body.set_meta("ident", identifier)
	stage_empty.visible = false
	stage_body.visible = true
	_paint_item_head()
	if not same:
		preview_box.visible = false
	var from_chain := bool(item.get("from_chain", false))
	derivatives_toggle.visible = not from_chain
	var hidden: Callable = Archive.is_hidden_file
	if from_chain or show_all:
		hidden = func(_file: Dictionary) -> bool: return false
	var files: Array = item.get("files", [])
	# Derivatives can be shown and ticked. They are not selected up front.
	var checked_hidden: Callable = hidden if from_chain else Archive.is_hidden_file
	var checked := Ark.default_checked(files, checked_hidden)
	var visible: Array = []
	for file in files:
		if file is Dictionary and not hidden.call(file):
			visible.append(file)
	stage_files = Archive.arrange_files(visible)
	picked = {}
	for at in stage_files.size():
		var name := str((stage_files[at] as Dictionary).get("name", ""))
		picked[at] = kept.has(name) if same else checked.has(name)
	_stage_lock = true
	if not same:
		file_filter.text = ""
		file_type = ""
	_stage_lock = false
	_paint_types()
	_paint_stage_files()
	_paint_rows()
	_quote()


func _paint_item_head() -> void:
	var identifier := str(item.get("identifier", ""))
	var title := str(item.get("title", "")).strip_edges()
	stage_title.text = title if not title.is_empty() else identifier
	stage_title.tooltip_text = stage_title.text
	var parts := PackedStringArray()
	for key in ["creator", "date"]:
		var value := str(item.get(key, "")).strip_edges()
		if not value.is_empty():
			parts.append(value)
	var kind := Archive.mediatype_label(str(item.get("mediatype", "")))
	if not kind.is_empty():
		parts.append(kind)
	var size := int(str(item.get("item_size", "0")))
	if size > 0:
		parts.append(_human_bytes(size))
	stage_byline.text = " · ".join(parts)
	stage_ident.text = identifier
	stage_ident.tooltip_text = identifier
	for child in stage_badges.get_children():
		child.queue_free()
	if bool(item.get("from_chain", false)):
		stage_badges.add_child(ArkTheme.badge("READ FROM %s" % chain.to_upper(), ArkTheme.LAMP))
	elif _aboard_ids.has(identifier):
		stage_badges.add_child(ArkTheme.badge("ABOARD %s" % chain.to_upper(), ArkTheme.LAMP))
	stage_badges.visible = bool(item.get("from_chain", false)) or _aboard_ids.has(identifier)
	stage_about.text = Archive.plain_text(str(item.get("description", "")))
	stage_about.visible = not stage_about.text.is_empty()
	stage_about.tooltip_text = stage_about.text.substr(0, 1200)
	stage_feature.visible = not identifier.is_empty()
	stage_thumb.texture = _thumbs.get(identifier, null)
	if stage_thumb.texture == null and not identifier.is_empty():
		_fetch_head_thumb(identifier)


func _fetch_head_thumb(identifier: String) -> void:
	var http := HTTPRequest.new()
	http.timeout = 12
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var image := Image.new()
			if Archive.decode_image(body, image):
				var texture := ImageTexture.create_from_image(image)
				_thumbs[identifier] = texture
				if str(item.get("identifier", "")) == identifier:
					stage_thumb.texture = texture
		http.queue_free()
	)
	if http.request(Archive.thumb_url(identifier), ["User-Agent: %s" % Archive.USER_AGENT]) != OK:
		http.queue_free()


func _open_details() -> void:
	var identifier := str(item.get("identifier", ""))
	if not identifier.is_empty():
		OS.shell_open("https://archive.org/details/" + identifier.uri_encode())


## One chip per format, largest first, each with its count.
func _paint_types() -> void:
	for child in type_box.get_children():
		child.queue_free()
	var counts := {}
	for file in stage_files:
		var section := Archive.file_section(file)
		counts[section] = int(counts.get(section, 0)) + 1
	var order: Array = counts.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		if counts[a] != counts[b]:
			return counts[a] > counts[b]
		return a.nocasecmp_to(b) < 0
	)
	if not file_type.is_empty() and not counts.has(file_type):
		file_type = ""
	type_box.add_child(_type_chip("", "All  %s" % Archive.grouped(stage_files.size())))
	if order.size() < 2:
		return
	for section in order:
		type_box.add_child(_type_chip(str(section), "%s  %s" % [section, Archive.grouped(int(counts[section]))]))


func _type_chip(section: String, label: String) -> Button:
	var chip := ArkTheme.choice(label, section == file_type, func() -> void:
		file_type = section
		for child in type_box.get_children():
			ArkTheme.paint_choice(child as Button, str(child.get_meta("section", "")) == file_type)
		_paint_stage_files()
	)
	chip.set_meta("section", section)
	return chip


func _on_file_filter() -> void:
	if _stage_lock:
		return
	_paint_stage_files()


func _paint_file_titles() -> void:
	var titles := {FILE_COL_NAME: "Name", FILE_COL_FORMAT: "Format", FILE_COL_SIZE: "Size", FILE_COL_STATE: ""}
	var keys := {FILE_COL_NAME: "name", FILE_COL_FORMAT: "format", FILE_COL_SIZE: "size"}
	for col in titles:
		var text := str(titles[col])
		if keys.get(col, "") == file_sort:
			text += "  ↓" if file_sort_desc else "  ↑"
		file_tree.set_column_title(col, text)


func _on_file_sort(column: int, _mouse_button: int) -> void:
	var keys := {FILE_COL_NAME: "name", FILE_COL_FORMAT: "format", FILE_COL_SIZE: "size"}
	if not keys.has(column):
		return
	var next := str(keys[column])
	if next == file_sort:
		file_sort_desc = not file_sort_desc
	else:
		file_sort = next
		file_sort_desc = next == "size"
	_paint_file_titles()
	_paint_stage_files()


## Rebuilds the table from stage_files, the filter, the type chip and the sort.
## picked stays keyed by stage_files index, so a filter never loses a tick.
func _paint_stage_files() -> void:
	file_tree.clear()
	var root := file_tree.create_item()
	var needle := file_filter.text.strip_edges().to_lower()
	var matched: Array = []
	for index in stage_files.size():
		var file: Dictionary = stage_files[index]
		if not file_type.is_empty() and Archive.file_section(file) != file_type:
			continue
		if not needle.is_empty() and str(file.get("name", "")).to_lower().find(needle) < 0:
			continue
		matched.append(index)
	if file_sort == "name":
		matched.sort_custom(func(a: int, b: int) -> bool:
			return str(stage_files[a].get("name", "")).get_file().nocasecmp_to(str(stage_files[b].get("name", "")).get_file()) < 0
		)
	elif file_sort == "size":
		matched.sort_custom(func(a: int, b: int) -> bool:
			return Ark.file_bytes(stage_files[a]) < Ark.file_bytes(stage_files[b])
		)
	if file_sort_desc:
		matched.reverse()
	_shown_files = matched
	var identifier := str(item.get("identifier", ""))
	var from_chain := bool(item.get("from_chain", false))
	for at in matched:
		var file: Dictionary = stage_files[at]
		var name := str(file.get("name", ""))
		var row := file_tree.create_item(root)
		row.set_cell_mode(FILE_COL_NAME, TreeItem.CELL_MODE_CHECK)
		row.set_editable(FILE_COL_NAME, true)
		row.set_checked(FILE_COL_NAME, bool(picked.get(at, false)))
		row.set_text(FILE_COL_NAME, name)
		row.set_tooltip_text(FILE_COL_NAME, name)
		row.set_metadata(FILE_COL_NAME, at)
		row.set_text(FILE_COL_FORMAT, Archive.file_section(file))
		row.set_custom_color(FILE_COL_FORMAT, ArkTheme.SEA)
		row.set_tooltip_text(FILE_COL_FORMAT, Archive.file_section(file))
		row.set_text(FILE_COL_SIZE, _human_bytes(Ark.file_bytes(file)))
		row.set_text_alignment(FILE_COL_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
		row.set_custom_color(FILE_COL_SIZE, ArkTheme.SEA)
		if from_chain:
			row.set_text(FILE_COL_STATE, "aboard")
			row.set_custom_color(FILE_COL_STATE, ArkTheme.LAMP)
		elif not cache.sha_for(identifier, name).is_empty():
			row.set_text(FILE_COL_STATE, "cached")
			row.set_custom_color(FILE_COL_STATE, ArkTheme.WATER)
			row.set_tooltip_text(FILE_COL_STATE, "Already on this machine. OPEN is instant.")
	files_empty.visible = matched.is_empty()
	if stage_files.is_empty():
		files_empty.text = "This item lists no original files.\nTurn on Derivatives to see what the Archive generated." if not show_all else "This item lists no files."
	else:
		files_empty.text = "No files match this filter."
	_paint_stage_note()


func _on_file_edited() -> void:
	var row := file_tree.get_edited()
	if row == null:
		return
	picked[int(row.get_metadata(FILE_COL_NAME))] = row.is_checked(FILE_COL_NAME)
	_paint_stage_note()
	_quote()


func _on_file_activated() -> void:
	var row := file_tree.get_selected()
	if row == null or busy:
		return
	var at := int(row.get_metadata(FILE_COL_NAME))
	if at < 0 or at >= stage_files.size():
		return
	busy = true
	await _open_file(stage_files[at])
	busy = false
	_refresh_cache()


func _select_shown(on: bool) -> void:
	for at in _shown_files:
		picked[at] = on
	_sync_ticks()


func _select_none() -> void:
	for at in picked:
		picked[at] = false
	_sync_ticks()


func _sync_ticks() -> void:
	var root := file_tree.get_root()
	if root != null:
		for row in root.get_children():
			row.set_checked(FILE_COL_NAME, bool(picked.get(int(row.get_metadata(FILE_COL_NAME)), false)))
	_paint_stage_note()
	_quote()


func _paint_stage_note() -> void:
	if stage_note == null:
		return
	var chosen := _selected_files()
	var raw := 0
	for file in chosen:
		raw += Ark.file_bytes(file)
	if chosen.is_empty():
		select_note.text = "Nothing selected"
		select_note.add_theme_color_override("font_color", ArkTheme.SEA)
	else:
		select_note.text = "%s file%s · %s" % [
			Archive.grouped(chosen.size()),
			"" if chosen.size() == 1 else "s",
			_human_bytes(raw),
		]
		select_note.add_theme_color_override("font_color", ArkTheme.FOAM)
	var text := "of %s" % Archive.grouped(stage_files.size())
	if _shown_files.size() != stage_files.size():
		text += " · %s shown" % Archive.grouped(_shown_files.size())
	stage_note.text = text
	_sync_actions()


func _selected_files() -> Array:
	var chosen: Array = []
	for index in stage_files.size():
		if bool(picked.get(index, false)):
			chosen.append(stage_files[index])
	return chosen


func _quote() -> void:
	if item.is_empty():
		quote_label.text = ""
		return
	var raws: Array = []
	var file_rows: Array = []
	var index := 0
	for file in stage_files:
		if not bool(picked.get(index, false)):
			index += 1
			continue
		var size := Ark.file_bytes(file)
		var parts := Ark.part_count(size)
		file_rows.append(Ark.file_row(str(item.get("identifier", "")), index, file, "", parts))
		for part in parts:
			raws.append(Ark.part_raw(size, part))
		index += 1
	if raws.is_empty():
		quote_label.text = "Tick files for a fee estimate"
		quote_label.add_theme_color_override("font_color", ArkTheme.SEA)
		quote_others.text = ""
		sol_note.visible = false
		return
	var spec := {
		"create_table": true,
		"meta_row": Ark.card_row(item),
		"file_rows": file_rows,
		"blob_raws": raws,
		"manifest_row": Ark.manifest_row(item, 0),
	}
	var active := _active_kind()
	if not active.is_empty():
		var slug := str(active.get("slug", ""))
		var ident := str(item.get("identifier", ""))
		if not Ark.row_has_id(_kind_rows, Ark.member_id(slug, ident)):
			spec["kind_member_rows"] = [Ark.kind_member_row(slug, str(active.get("title", slug)), ident)]
	quote_label.text = "%s  on %s" % [Costs.amount(chain, Costs.quote_item(chain, spec)), CHAIN_NAMES[chain]]
	quote_label.add_theme_color_override("font_color", ArkTheme.GOLD)
	var others := PackedStringArray()
	for code in CHAINS:
		if code != chain:
			others.append("%s %s" % [code.to_upper(), Costs.amount(code, Costs.quote_item(code, spec))])
	quote_others.text = "Elsewhere: " + "   ".join(others)
	sol_note.visible = chain == "sol"


func _open_checked() -> void:
	if busy or item.is_empty():
		return
	var chosen := _selected_files()
	if chosen.is_empty():
		_status("Select a file to open.")
		return
	busy = true
	for file in chosen:
		var ok: bool = await _open_file(file)
		if not ok:
			break
	busy = false
	_refresh_cache()


func _open_file(file: Dictionary) -> bool:
	var name := str(file.get("name", ""))
	var identifier := str(item.get("identifier", ""))
	var already := not cache.sha_for(identifier, name).is_empty()
	var sha := await _ensure_cached(file, true)
	if sha.is_empty():
		return false
	if not already:
		for sibling in Archive.subtitle_siblings(name, item.get("files", [])):
			await _cache_sibling(sibling, sha, identifier)
	cache.evict(_cache_limit(), sha)
	return _launch(sha, name)


func _ensure_cached(file: Dictionary, prefer_chain: bool = false) -> String:
	var identifier := str(item.get("identifier", ""))
	var name := str(file.get("name", ""))
	var chain_sha := str(file.get("sha256", "")).strip_edges().to_lower()
	if not chain_sha.is_empty() and cache.has_sha(chain_sha):
		cache.touch(chain_sha)
		return chain_sha
	var sha := cache.sha_for(identifier, name)
	if not sha.is_empty() and (chain_sha.is_empty() or sha == chain_sha):
		cache.touch(sha)
		return sha
	# OPEN of an aboard file reassembles the chain. Inscribe still fetches
	# the Archive, because a missing part cannot be rebuilt from the chain.
	if prefer_chain and bool(item.get("from_chain", false)):
		return await _read_back(file)
	var staged := "user://staging".path_join(name.get_file())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://staging"))
	_progress_note = "Downloading %s" % name
	_status(_progress_note)
	var ok: bool = await fetch.download(Archive.download_url(identifier, name), staged)
	_progress_note = ""
	if not ok:
		_status("Download failed. %s" % fetch.last_error)
		return ""
	if not Archive.hashes_match(staged, str(file.get("md5", "")), str(file.get("sha1", ""))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
		_status("Hash mismatch. Nothing was cached.")
		return ""
	sha = Ark.sha256_file(staged)
	if cache.remember_path(sha, name, identifier, staged).is_empty():
		_status("Could not cache %s" % name)
		return ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
	return sha


func _read_back(file: Dictionary) -> String:
	var identifier := str(item.get("identifier", ""))
	var name := str(file.get("name", ""))
	if iq == null or not iq.is_available():
		_status("Reading this back needs GodOnChain.")
		return ""
	var staged := "user://staging".path_join(name.get_file())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://staging"))
	_status("Reading %s back from the chain." % name)
	var cabinet := Cabinet.new(iq, chain)
	var got: Dictionary = await cabinet.reassemble(identifier, name, staged)
	if not bool(got.get("ok", false)):
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "Read-back failed.")
		return ""
	var sha := str(got.get("sha", ""))
	if cache.remember_path(sha, name, identifier, staged).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
		_status("Could not cache %s." % name)
		return ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
	return sha


func _cache_sibling(file: Dictionary, video_sha: String, identifier: String) -> void:
	var name := str(file.get("name", ""))
	var staged := "user://staging".path_join(name.get_file())
	var chain_sha := str(file.get("sha256", "")).strip_edges().to_lower()
	if bool(item.get("from_chain", false)) and not chain_sha.is_empty() and iq != null and iq.is_available():
		if cache.has_sha(chain_sha):
			var existing := cache.path_of(chain_sha)
			if not existing.is_empty() and not cache.remember_path(chain_sha, name, identifier, existing, video_sha).is_empty():
				return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://staging"))
		var got: Dictionary = await Cabinet.new(iq, chain).reassemble(identifier, name, staged)
		if bool(got.get("ok", false)):
			cache.remember_path(str(got.get("sha", "")), name, identifier, staged, video_sha)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
			return
		if FileAccess.file_exists(staged):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
	var ok: bool = await fetch.download(Archive.download_url(identifier, name), staged)
	if not ok:
		return
	if not Archive.hashes_match(staged, str(file.get("md5", "")), str(file.get("sha1", ""))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
		return
	var sha := Ark.sha256_file(staged)
	cache.remember_path(sha, name, identifier, staged, video_sha)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))


func _launch(sha: String, name: String) -> bool:
	var absolute := cache.absolute_of(sha)
	var kind := Archive.open_kind(name)
	_show_preview(kind, absolute, name)
	if kind == "folder":
		OS.shell_show_in_file_manager(absolute)
		_status("No player for this file. Showing it in the folder.")
		return true
	var err := OS.shell_open(absolute)
	if err != OK:
		OS.shell_show_in_file_manager(absolute)
		_status("This machine has no association for that file. Showing it in the folder.")
		return true
	_status("Opened %s" % name)
	return true


func _show_preview(kind: String, absolute: String, name: String = "") -> void:
	picture.visible = false
	preview.visible = false
	if kind == "image":
		var image := Image.new()
		if image.load(absolute) == OK:
			picture.texture = ImageTexture.create_from_image(image)
			picture.visible = true
	elif kind == "text":
		var file := FileAccess.open(absolute, FileAccess.READ)
		if file != null and file.get_length() < 262144:
			preview.text = file.get_as_text()
			preview.visible = true
			file.close()
	preview_title.text = "PREVIEW  " + name.get_file()
	preview_box.visible = picture.visible or preview.visible


func _inscribe_checked() -> void:
	if busy or item.is_empty():
		return
	if iq == null or not iq.is_available():
		_status("Inscribe needs GodOnChain running, with this app launched by it.")
		return
	var cabinet := Cabinet.new(iq, chain)
	if not await cabinet.is_kindled():
		_status("This chain has not been kindled.")
		return
	var chosen := _selected_files()
	var raw := 0
	for file in chosen:
		raw += Ark.file_bytes(file)
	if chosen.is_empty():
		_status("Select a file to inscribe.")
		return
	busy = true
	var proceed: bool = await _confirm(
		"Inscribe onto %s" % chain.to_upper(),
		"This selection is %s files, %s. Anyone can continue this table. It is created with an empty writer list, and that cannot be tightened later. The bytes stay on the chain." % [Archive.grouped(chosen.size()), _human_bytes(raw)],
		"INSCRIBE"
	)
	if not proceed:
		busy = false
		_status("Inscribe cancelled.")
		return
	if raw > Ark.SELECT_ALL_LIMIT:
		var again: bool = await _confirm(
			"This selection is over 100 MiB",
			"The quote above is what the host will ask you to approve, one write at a time. Rows already aboard are skipped.",
			"INSCRIBE ANYWAY"
		)
		if not again:
			busy = false
			_status("Inscribe cancelled.")
			return
	var paths := {}
	for file in chosen:
		var sha := await _ensure_cached(file)
		if sha.is_empty():
			busy = false
			return
		paths[str(file.get("name", ""))] = cache.path_of(sha)
	var kinds: Array = []
	var active := _active_kind()
	if not active.is_empty():
		kinds.append(active)
	var wrote: bool = await cabinet.inscribe(
		item,
		chosen,
		paths,
		func(text: String) -> void: _status(text),
		kinds
	)
	busy = false
	_refresh_cache()
	if not wrote:
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "Inscribe failed.")
		return
	var repaired: int = await cabinet.repair()
	await _refresh_board()
	if repaired < 0:
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "Repair failed.")
		return
	if repaired > 0:
		_status("Aboard: %s. Repair added %d." % [str(item.get("identifier", "")), repaired])


func _confirm(title: String, body: String, ok_text: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = body
	dialog.dialog_autowrap = true
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = "LEAVE IT"
	dialog.theme = theme
	dialog.min_size = Vector2(520, 180)
	add_child(dialog)
	dialog.popup_centered()
	var accepted := false
	var settled := false
	dialog.confirmed.connect(func() -> void:
		accepted = true
		settled = true
	)
	dialog.canceled.connect(func() -> void:
		settled = true
	)
	while not settled:
		await get_tree().process_frame
	dialog.queue_free()
	return accepted


func _apply_mirror() -> void:
	_manifest = Ark.load_mirror(Ark.MANIFEST_MIRROR)
	_kind_rows = Ark.load_mirror(Ark.KINDS_MIRROR)
	_paint_aboard()
	_paint_featured(Ark.featured_band(_kind_rows), _kind_rows)
	if aboard_note == null:
		return
	if _manifest.is_empty():
		aboard_note.text = "The cabinet is the manifest on the selected chain. It fills when a host is attached."
	else:
		aboard_note.text = "Last manifest on this machine. A host refreshes it."


func _refresh_board() -> void:
	_apply_mirror()
	if iq == null or not iq.is_available():
		return
	var cabinet := Cabinet.new(iq, chain)
	_manifest = await cabinet.manifest_rows()
	_kind_rows = await cabinet.kind_rows()
	Ark.save_mirror(Ark.MANIFEST_MIRROR, _manifest)
	Ark.save_mirror(Ark.KINDS_MIRROR, _kind_rows)
	_paint_aboard()
	_paint_featured(Ark.featured_band(_kind_rows), _kind_rows)
	if _aboard_ids.is_empty():
		aboard_note.text = "Nothing aboard on %s yet." % chain.to_upper()
	else:
		aboard_note.text = "%d aboard on %s." % [_aboard_ids.size(), chain.to_upper()]
	if not kind_slug.is_empty():
		_paint_kind()
	elif found_count >= 0 and results_scroll != null and results_scroll.visible:
		_paint_hits(found_count, Archive.page_window(page, Archive.PAGE_ROWS, found_count))


func _paint_aboard() -> void:
	if aboard_box == null:
		return
	for child in aboard_box.get_children():
		aboard_box.remove_child(child)
		child.free()
	_aboard_ids = {}
	for row in _manifest:
		if not row is Dictionary:
			continue
		var ident := str(row.get("identifier", "")).strip_edges()
		if ident.is_empty():
			ident = str(row.get("id", "")).strip_edges()
		if not ident.is_empty():
			_aboard_ids[ident] = true
	if tab_buttons.size() > 1:
		tab_buttons[1].text = "ABOARD  %s" % Archive.grouped(_aboard_ids.size()) if not _aboard_ids.is_empty() else "ABOARD"
	var query := aboard_filter.text if aboard_filter != null else ""
	var groups := Ark.aboard_filter(Ark.aboard_groups(_manifest, _kind_rows), query)
	if groups.is_empty():
		var empty := ArkTheme.line(
			"Nothing in the cabinet matches." if not query.is_empty()
			else "Nothing aboard yet.\nInscribe an item and it lands here.",
			ArkTheme.SEA,
			ArkTheme.SIZE_SMALL
		)
		empty.custom_minimum_size = Vector2(0, 120)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		aboard_box.add_child(empty)
		return
	var first := true
	for group in groups:
		var heading := ArkTheme.cell(str(group.get("heading", "")).to_upper(), ArkTheme.GOLD, ArkTheme.SIZE_SMALL)
		var gap := MarginContainer.new()
		gap.add_theme_constant_override("margin_top", 0 if first else 14)
		gap.add_theme_constant_override("margin_bottom", 4)
		gap.add_child(heading)
		aboard_box.add_child(gap)
		first = false
		var items: Array = group.get("items", [])
		var key := str(group.get("key", ""))
		var window := Ark.aboard_page(items, int(_aboard_page.get(key, 1)))
		_aboard_page[key] = int(window.get("page", 1))
		for entry in window.get("items", []):
			aboard_box.add_child(_aboard_row(entry))
		var pages := int(window.get("pages", 1))
		if pages > 1:
			aboard_box.add_child(_aboard_pager(key, int(window.get("page", 1)), pages))


func _aboard_pager(key: String, page_no: int, pages: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var prev := ArkTheme.quiet_button("PREV", func() -> void: _aboard_turn(key, -1))
	prev.disabled = page_no <= 1
	var next := ArkTheme.quiet_button("NEXT", func() -> void: _aboard_turn(key, 1))
	next.disabled = page_no >= pages
	row.add_child(prev)
	row.add_child(ArkTheme.cell("%d / %d" % [page_no, pages], ArkTheme.SEA))
	row.add_child(next)
	return row


func _aboard_turn(key: String, delta: int) -> void:
	_aboard_page[key] = int(_aboard_page.get(key, 1)) + delta
	_paint_aboard()


func _aboard_row(entry: Dictionary) -> Control:
	var ident := str(entry.get("identifier", ""))
	var panel := _clickable_row(ident, func() -> void: await _open_aboard(entry))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var title := ArkTheme.cell(str(entry.get("title", "")), ArkTheme.PARCHMENT, ArkTheme.SIZE_BODY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(title)
	var parts := PackedStringArray([ident])
	var kind := Archive.mediatype_label(str(entry.get("mediatype", "")))
	if not kind.is_empty():
		parts.append(kind)
	var bytes := int(str(entry.get("bytes", "0")))
	if bytes > 0:
		parts.append(_human_bytes(bytes))
	var sub := ArkTheme.cell(" · ".join(parts), ArkTheme.SEA, ArkTheme.SIZE_SMALL)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(sub)
	var aboard := bool(entry.get("aboard", false))
	var tag := ArkTheme.badge("ABOARD" if aboard else "NOT YET", ArkTheme.LAMP if aboard else ArkTheme.SEA)
	row.add_child(tag)
	return panel


func _open_aboard(entry: Dictionary) -> void:
	var ident := str(entry.get("identifier", ""))
	if ident.is_empty() or busy:
		return
	if not bool(entry.get("aboard", false)):
		await _load_item(ident)
		return
	if iq == null or not iq.is_available():
		_status("Reading this back needs GodOnChain.")
		return
	busy = true
	_status("Reading %s from the chain." % ident)
	var cabinet := Cabinet.new(iq, chain)
	var files: Array = await cabinet.file_list(ident)
	busy = false
	if files.is_empty():
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "No files aboard for %s." % ident)
		return
	item = {
		"identifier": ident,
		"title": str(entry.get("title", ident)),
		"mediatype": str(entry.get("mediatype", "")),
		"files": files,
		"from_chain": true,
		"collections": [],
	}
	_fill_stage()
	_status("Aboard %s. %d files. OPEN reads them back." % [ident, stage_files.size()])


func _repair_aboard() -> void:
	if busy:
		return
	if iq == null or not iq.is_available():
		_status("Repair needs GodOnChain.")
		return
	busy = true
	_status("Checking item tables against the manifest.")
	var cabinet := Cabinet.new(iq, chain)
	var added: int = await cabinet.repair()
	busy = false
	if added < 0:
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "Repair failed.")
		return
	_status("Repair added %d." % added)
	await _refresh_board()


func _paint_featured(band: Array, kinds: Array) -> void:
	if featured_box == null:
		return
	for child in featured_box.get_children():
		child.queue_free()
	if band.is_empty():
		featured_box.visible = false
		return
	featured_box.visible = true
	var heading := ArkTheme.line("Featured", ArkTheme.WATER, ArkTheme.SIZE_SMALL)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	featured_box.add_child(heading)
	var ia_of := {}
	for row in kinds:
		if row is Dictionary:
			ia_of[str((row as Dictionary).get("id", ""))] = str((row as Dictionary).get("ia", ""))
	for entry in band:
		var slug := str(entry.get("slug", ""))
		var title := str(entry.get("title", ""))
		if title.is_empty():
			title = slug
		var ia := str(ia_of.get(slug, ""))
		var members := Ark.merge_ids(Ark.kind_members(kinds, slug), Ark.load_walk(slug).get("members", []))
		var aboard := 0
		for ident in members:
			if _aboard_ids.has(ident):
				aboard += 1
		var files := Ark.walk_file_counts(Ark.load_walk(slug))
		var label := Ark.effort_label(
			title,
			aboard,
			members.size(),
			int(files.get("aboard", 0)),
			int(files.get("total", 0)),
			bool(files.get("known", false))
		)
		featured_box.add_child(_featured_chip(label, title, ia, slug))


func _toggle_derivatives(on: bool) -> void:
	show_all = on
	if not item.is_empty():
		_fill_stage()


func _active_kind() -> Dictionary:
	if not kind_slug.is_empty():
		var title := kind_title if not kind_title.is_empty() else kind_slug
		return {"slug": kind_slug, "title": title}
	if collection_id.is_empty():
		return {}
	var header := Ark.kind_for_ia(_kind_rows, collection_id)
	if header.is_empty():
		return {}
	var slug := str(header.get("id", ""))
	var title := str(header.get("title", slug))
	return {"slug": slug, "title": title}


func _open_kind(slug: String, title: String, and_check: bool) -> void:
	if busy or slug.is_empty():
		return
	_trail.append(_capture())
	kind_slug = slug
	kind_title = title if not title.is_empty() else slug
	collection_id = ""
	collection_title = ""
	search_box.text = ""
	_paint_place()
	_paint_kind()
	if and_check:
		await _check_current()


func _paint_kind() -> void:
	docs = []
	_thumb_token += 1
	_clear_results()
	var meta := _meta()
	meta.visible = true
	if sort_box != null:
		sort_box.visible = false
	var members := Ark.kind_members(_kind_rows, kind_slug)
	count_label.text = "%d on this shelf" % members.size()
	pager_prev.visible = false
	pager_next.visible = false
	page_label.visible = false
	empty_label.visible = members.is_empty()
	empty_label.text = "This shelf is empty. Add an identifier."
	results_scroll.visible = not members.is_empty()
	results_scroll.scroll_vertical = 0
	for ident in members:
		results_box.add_child(_aboard_row({
			"identifier": ident,
			"title": ident,
			"aboard": _aboard_ids.has(ident),
		}))


func _create_kind() -> void:
	if busy:
		return
	if iq == null or not iq.is_available():
		_status("A kind needs GodOnChain.")
		return
	var form := await _ask_kind()
	if form.is_empty():
		return
	var title := str(form.get("title", "")).strip_edges()
	var ia := str(form.get("ia", "")).strip_edges()
	if title.is_empty():
		_status("A kind needs a title.")
		return
	var slug := Ark.slug_for(title, ia)
	var members: PackedStringArray = form.get("members", PackedStringArray())
	var rows := 1 + members.size()
	var proceed: bool = await _confirm(
		"File this kind",
		"This writes %d small row%s on %s. The host will ask for each. Anyone can add to the shelf later."
		% [rows, "" if rows == 1 else "s", chain.to_upper()],
		"FILE IT"
	)
	if not proceed:
		_status("Kind cancelled.")
		return
	busy = true
	var cabinet := Cabinet.new(iq, chain)
	if not await cabinet.ensure_kind(slug, title, ia):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The shelf was not filed.")
		return
	for ident in members:
		if not await cabinet.add_member(slug, title, ident):
			busy = false
			_status(cabinet.last_error if not cabinet.last_error.is_empty() else "A member was not filed.")
			return
	await cabinet.published()
	busy = false
	await _refresh_board()
	_status("Filed %s." % title)
	await _open_kind(slug, title, false)


func _ask_kind() -> Dictionary:
	var dialog := ConfirmationDialog.new()
	dialog.title = "New kind"
	dialog.dialog_text = ""
	dialog.ok_button_text = "FILE IT"
	dialog.cancel_button_text = "LEAVE IT"
	dialog.theme = theme
	dialog.min_size = Vector2(520, 380)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 280)
	box.add_theme_constant_override("separation", 6)
	dialog.add_child(box)
	var title_edit := LineEdit.new()
	title_edit.placeholder_text = "Title"
	var ia_edit := LineEdit.new()
	ia_edit.placeholder_text = "Collection id, if this shelf is one"
	var members := TextEdit.new()
	members.placeholder_text = "One item identifier per line"
	members.custom_minimum_size = Vector2(0, 160)
	members.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(title_edit)
	box.add_child(ia_edit)
	box.add_child(members)
	add_child(dialog)
	dialog.popup_centered()
	var accepted := false
	var settled := false
	dialog.confirmed.connect(func() -> void:
		accepted = true
		settled = true
	)
	dialog.canceled.connect(func() -> void:
		settled = true
	)
	while not settled:
		await get_tree().process_frame
	var result := {}
	if accepted:
		result = {
			"title": title_edit.text.strip_edges(),
			"ia": ia_edit.text.strip_edges(),
			"members": Ark.identifiers_of(members.text),
		}
	dialog.queue_free()
	return result


## An Archive item such as the TempleOS channel archive is one table of files,
## not a collection. Featuring it files a shelf whose only member is that item.
## The identifier picks the slug and is not stored as a collection id, so a
## later CHECK counts this item's files instead of scraping a collection.
func _feature_item() -> void:
	if busy or item.is_empty():
		return
	if iq == null or not iq.is_available():
		_status("Featuring an effort needs GodOnChain.")
		return
	var ident := str(item.get("identifier", "")).strip_edges()
	if ident.is_empty():
		return
	var title := str(item.get("title", "")).strip_edges()
	if title.is_empty():
		title = ident
	var slug := Ark.slug_for(title, ident)
	var header := Ark.kind_header(_kind_rows, slug)
	var create := header.is_empty()
	var listed := Ark.kind_members(_kind_rows, slug).has(ident)
	if not create:
		var existing := str(header.get("title", "")).strip_edges()
		if not existing.is_empty():
			title = existing
	if listed and Ark.latest_state(_kind_rows, slug) == "featured":
		_status("Already featured.")
		return
	var body := "This writes a small mark on %s. The host will ask. Anyone can feature or finish the shelf later." % title
	if create:
		body = "This files %s as an effort and puts this item on the shelf, then writes a featured mark. The host will ask for each row." % title
	elif not listed:
		body = "This adds this item to %s and writes a featured mark. The host will ask." % title
	var proceed: bool = await _confirm("Feature this item", body, "FEATURE")
	if not proceed:
		_status("Feature cancelled.")
		return
	busy = true
	var cabinet := Cabinet.new(iq, chain)
	if create and not await cabinet.ensure_kind(slug, title, ""):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The shelf was not filed.")
		return
	if not listed and not await cabinet.add_member(slug, title, ident):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The item was not filed.")
		return
	if not await cabinet.write_mark(slug, title, "featured"):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The mark was not written.")
		return
	await cabinet.published()
	busy = false
	await _refresh_board()
	_status("Featured %s." % title)


func _feature_current() -> void:
	if busy:
		return
	if iq == null or not iq.is_available():
		_status("Featuring an effort needs GodOnChain.")
		return
	var slug := ""
	var title := ""
	var ia := ""
	var create := false
	if not kind_slug.is_empty():
		slug = kind_slug
		title = kind_title if not kind_title.is_empty() else kind_slug
	elif not collection_id.is_empty():
		var existing := Ark.kind_for_ia(_kind_rows, collection_id)
		if existing.is_empty():
			title = collection_title if not collection_title.is_empty() else collection_id
			ia = collection_id
			slug = Ark.slug_for(title, ia)
			create = true
		else:
			slug = str(existing.get("id", ""))
			title = str(existing.get("title", ""))
			if title.is_empty():
				title = collection_title
	else:
		_status("Open a collection or a kind to feature it.")
		return
	if Ark.latest_state(_kind_rows, slug) == "featured" and not create:
		_status("Already featured.")
		return
	var proceed: bool = await _confirm(
		"Feature this effort",
		"This writes a small mark on %s. The host will ask. Anyone can feature or finish the shelf later." % title,
		"FEATURE"
	)
	if not proceed:
		_status("Feature cancelled.")
		return
	busy = true
	var cabinet := Cabinet.new(iq, chain)
	if create and not await cabinet.ensure_kind(slug, title, ia):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The shelf was not filed.")
		return
	if not await cabinet.write_mark(slug, title, "featured"):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The mark was not written.")
		return
	await cabinet.published()
	busy = false
	await _refresh_board()
	_status("Featured %s." % title)


func _check_current() -> void:
	if busy:
		return
	var kind := _active_kind()
	if kind.is_empty():
		_status("Open a collection or a kind to check it.")
		return
	if iq == null or not iq.is_available():
		_status("Checking files needs GodOnChain.")
		return
	var slug := str(kind.get("slug", ""))
	var title := str(kind.get("title", slug))
	var header := Ark.kind_header(_kind_rows, slug)
	var ia := str(header.get("ia", "")).strip_edges()
	if ia.is_empty() and not collection_id.is_empty() and slug == Ark.slug_for(title, collection_id):
		ia = collection_id
	var explicit := Ark.kind_members(_kind_rows, slug)
	if ia.is_empty() and explicit.is_empty():
		_status("This shelf has no items to check.")
		return
	busy = true
	var state := Ark.load_walk(slug)
	var reachable := true
	if not ia.is_empty() and not bool(state.get("finished", false)):
		_status("Walking %s." % ia)
		var body := await _get_text(Archive.scrape_url(Archive.member_query(ia), str(state.get("cursor", ""))))
		var page := Archive.parse_scrape(body)
		if not bool(page.get("ok", false)):
			busy = false
			_status("The Archive did not answer. The effort stays featured.")
			return
		var found: PackedStringArray = page.get("items", PackedStringArray())
		state = Ark.walk_add(state, found, str(page.get("cursor", "")), bool(page.get("finished", false)))
	var members := explicit
	if not ia.is_empty():
		members = Ark.merge_ids(explicit, state.get("members", []))
		if bool(state.get("finished", false)) and members.is_empty():
			busy = false
			Ark.save_walk(slug, state)
			_status("The Archive lists no items here. The effort stays featured.")
			return
	else:
		state["finished"] = true
	var complete: Dictionary = state.get("complete", {})
	if not complete is Dictionary:
		complete = {}
	var files: Dictionary = state.get("files", {})
	if not files is Dictionary:
		files = {}
	var cabinet := Cabinet.new(iq, chain)
	for ident in members:
		if bool(complete.get(ident, false)):
			continue
		_status("Checking %s." % ident)
		var meta_body := await _get_text(Archive.metadata_url(ident))
		if meta_body.is_empty():
			reachable = false
			break
		var meta := Archive.parse_metadata(meta_body)
		var names := PackedStringArray()
		for file in Archive.originals(meta.get("files", [])):
			var name := str(file.get("name", "")).strip_edges()
			if not name.is_empty():
				names.append(name)
		var tally := Ark.file_tally(await cabinet.item_rows(ident), names)
		complete[ident] = bool(tally.get("complete", false))
		files[ident] = {"aboard": int(tally.get("aboard", 0)), "total": int(tally.get("total", 0))}
	state["complete"] = complete
	state["files"] = files
	Ark.save_walk(slug, state)
	var counts := Ark.walk_file_counts(state)
	if not reachable:
		busy = false
		await _refresh_board()
		_status("The Archive did not answer. The effort stays featured.")
		return
	if not Ark.should_finish(members, complete, true, bool(state.get("finished", false))):
		busy = false
		await _refresh_board()
		var note := "Checked %s. %d/%d aboard." % [title, _aboard_items(members, complete), members.size()]
		if bool(counts.get("known", false)):
			note += " %d/%d files." % [int(counts.get("aboard", 0)), int(counts.get("total", 0))]
		if not ia.is_empty() and not bool(state.get("finished", false)):
			note += " CHECK continues the walk."
		_status(note)
		return
	var proceed: bool = await _confirm(
		"Mark this effort done",
		"Every current member's original files are aboard. This writes one small row and takes %s off the featured band. The host will ask." % title,
		"MARK DONE"
	)
	if not proceed:
		busy = false
		_status("Left %s featured." % title)
		return
	if not await cabinet.write_mark(slug, title, "done"):
		busy = false
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The mark was not written. It stays featured.")
		return
	await cabinet.published()
	busy = false
	await _refresh_board()
	_status("%s is done." % title)


func _aboard_items(members: PackedStringArray, complete: Dictionary) -> int:
	var aboard := 0
	for ident in members:
		if bool(complete.get(ident, false)):
			aboard += 1
	return aboard


func _add_to_kind() -> void:
	if busy or kind_slug.is_empty() or add_box == null:
		return
	var ident := add_box.text.strip_edges()
	if ident.is_empty():
		return
	if iq == null or not iq.is_available():
		_status("Adding to a shelf needs GodOnChain.")
		return
	var title := kind_title if not kind_title.is_empty() else kind_slug
	var proceed: bool = await _confirm(
		"Add %s" % ident,
		"This writes one small member row on %s. The host will ask. Anyone can keep adding to this shelf." % title,
		"ADD"
	)
	if not proceed:
		_status("Add cancelled.")
		return
	busy = true
	var cabinet := Cabinet.new(iq, chain)
	var wrote: bool = await cabinet.add_member(kind_slug, title, ident)
	if wrote:
		await cabinet.published()
	busy = false
	if not wrote:
		_status(cabinet.last_error if not cabinet.last_error.is_empty() else "The member was not filed.")
		return
	add_box.text = ""
	await _refresh_board()
	_status("Filed %s on %s." % [ident, title])


func _clear_item() -> void:
	var identifier := str(item.get("identifier", ""))
	if identifier.is_empty():
		return
	cache.clear_item(identifier)
	_refresh_cache()
	_status("Cleared the cache for %s. The chain was not touched." % identifier)


func _clear_all() -> void:
	cache.clear_all()
	_refresh_cache()
	_status("Cache cleared. The chain was not touched.")


func _refresh_cache() -> void:
	cache_label.text = "CACHE  %s" % _human_bytes(cache.total_bytes())
	_paint_file_states()


## The state column only. A full repaint would drop the scroll position.
func _paint_file_states() -> void:
	if file_tree == null or file_tree.get_root() == null or bool(item.get("from_chain", false)):
		return
	var identifier := str(item.get("identifier", ""))
	for row in file_tree.get_root().get_children():
		var at := int(row.get_metadata(FILE_COL_NAME))
		var name := str((stage_files[at] as Dictionary).get("name", ""))
		var cached := not cache.sha_for(identifier, name).is_empty()
		row.set_text(FILE_COL_STATE, "cached" if cached else "")
		row.set_custom_color(FILE_COL_STATE, ArkTheme.WATER)
		row.set_tooltip_text(FILE_COL_STATE, "Already on this machine. OPEN is instant." if cached else "")


func _on_progress(received: int) -> void:
	var prefix := _progress_note if not _progress_note.is_empty() else "Downloading"
	_status("%s…  %s" % [prefix, _human_bytes(received)])


func _get_text(url: String) -> String:
	var dest := "user://staging/response.json"
	var absolute := ProjectSettings.globalize_path(dest)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://staging"))
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(absolute)
	var ok: bool = await fetch.download(url, dest)
	if not ok:
		return ""
	var body := FileAccess.get_file_as_string(dest)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
	return body


func _status(text: String) -> void:
	status_label.text = text


func _human_bytes(n: int) -> String:
	if n < 1024:
		return "%d B" % n
	if n < 1024 * 1024:
		return "%.1f KB" % (float(n) / 1024.0)
	if n < 1024 * 1024 * 1024:
		return "%.1f MB" % (float(n) / (1024.0 * 1024.0))
	return "%.2f GB" % (float(n) / (1024.0 * 1024.0 * 1024.0))
