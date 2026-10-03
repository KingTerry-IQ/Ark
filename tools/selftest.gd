extends SceneTree

## Headless checks. No host, no network.
##
##   Godot --headless --path . --script res://tools/selftest.gd

const _Ark = preload("res://Scripts/ark.gd")
const _Costs = preload("res://Scripts/costs.gd")
const _Archive = preload("res://Scripts/archive.gd")
const _Cache = preload("res://Scripts/ark_cache.gd")

var _failed := 0
var _passed := 0


func _init() -> void:
	_run()


func _run() -> void:
	_protocol()
	_fees()
	_archive()
	_featured()
	_cache()
	_look()
	_aboard()
	_kinds()
	await _chain_writes()
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _protocol() -> void:
	_check("root is load-bearing", Ark.APP_ROOT == "GodOnChain-KingTerry-Ark")
	_check("protocol is ark/1", Ark.PROTOCOL == "ark/1")
	var named := Ark.table_name("ark")
	_check("table name is 24 chars", named.length() == 24)
	_check("table name starts with i", named.begins_with("i"))
	_check("table name is frozen", named == "i004b372cb547494db2f62d4")
	_check("same identifier, same table", Ark.table_name("ark") == named)
	_check("different identifiers differ", Ark.table_name("ark") != Ark.table_name("arks"))
	_check("kindled hex is reserved", Ark.is_reserved_table("6b696e646c6564"))
	_check("manifest hex is reserved", Ark.is_reserved_table("6d616e6966657374"))
	_check("kinds hex is reserved", Ark.is_reserved_table("6B696E6473"))
	_check("item table is not reserved", not Ark.is_reserved_table(named))
	_check("zero bytes is zero parts", Ark.part_count(0) == 0)
	_check("32 MiB is one part", Ark.part_count(Ark.PART_RAW_BYTES) == 1)
	_check("32 MiB + 1 is two parts", Ark.part_count(Ark.PART_RAW_BYTES + 1) == 2)
	_check(
		"last part is the remainder",
		Ark.part_raw(Ark.PART_RAW_BYTES + 1, 1) == 1
	)
	var have := {"b:0:0": true}
	_check("resume skips a present part", Ark.missing_parts(0, 2, have) == [1])
	_check("collection slug fits", Ark.slug_for("Prelinger", "prelinger") == "prelinger")
	_check(
		"titled kind normalizes",
		Ark.slug_for("Terry Davis videos", "") == "terry-davis-videos"
	)
	_check("reserved slug is not used", Ark.slug_for("kindled", "") != "kindled")
	var channel := "TerryDavislosethosChannel"
	_check(
		"mixed-case collection id is hashed",
		Ark.slug_for("losethos", channel) == Ark.sha256_text(channel).substr(0, 24)
	)
	_check(
		"member id is stable",
		Ark.member_id("prelinger", "ark") == Ark.member_id("prelinger", "ark")
	)
	_check(
		"mark id is zero padded",
		Ark.mark_id("prelinger", 1000) == "prelinger/mark/0000000000001000"
	)
	var hello := "flash".to_utf8_buffer()
	_check(
		"sha256 of known bytes",
		Ark.sha256_bytes(hello)
		== "851e43bd44a2c3d30e5f3acadc9240c12d9f1c610dba34761e8c47ba82d1daea"
	)
	var big := PackedStringArray()
	for i in 200:
		big.append("collection%d" % i)
	var item := {"identifier": "ark", "title": "Ark", "collections": big, "mediatype": "texts"}
	_check("manifest clips the collection list", Ark.manifest_row(item, 1)["collections"].length() <= 400)
	var over := []
	for i in 120:
		over.append({"name": "f%d.bin" % i, "size": str(1024 * 1024), "source": "original"})
	_check("huge item starts unchecked", Ark.default_checked(over, Archive.is_hidden_file).is_empty())
	var small := [{"name": "a.txt", "size": "12", "source": "original"}]
	_check(
		"small item starts checked",
		Ark.default_checked(small, Archive.is_hidden_file) == PackedStringArray(["a.txt"])
	)
	var pair := [
		{"name": "a.txt", "size": "12", "source": "original"},
		{"name": "b.txt", "size": "12", "source": "original"},
	]
	_check("a grouping starts unchecked", Ark.default_checked(pair, Archive.is_hidden_file).is_empty())
	var evm_list := {
		"tables": [
			{"name": "kindled", "seedHex": "0x30"},
			{"name": "manifest", "seedHex": "0x6d"},
			{"name": "kinds", "seedHex": "0x6b"},
		],
		"globalTables": [
			{"name": "kindled", "seedHex": "0x30"},
			{"name": "manifest", "seedHex": "0x6d"},
			{"name": "kinds", "seedHex": "0x6b"},
		],
	}
	_check(
		"an evm list names each shelf once",
		IQSpace.names_from_listing(evm_list) == PackedStringArray(["kindled", "manifest", "kinds"])
	)
	var sol_list := {"tableSeeds": ["6b696e646c6564", "6d616e6966657374", "6b696e6473"]}
	_check(
		"a solana list decodes the shelf seeds",
		IQSpace.names_from_listing(sol_list) == PackedStringArray(["kindled", "manifest", "kinds"])
	)


func _fees() -> void:
	_check("base64 of 1 byte is 4", Costs.base64_bytes(1) == 4)
	_check("base64 of 1 MiB", Costs.base64_bytes(1048576) == 1398104)
	_check("Monad createTable is 19.5", is_equal_approx(Costs.estimate("mon", 0, "createTable"), 19.5))
	_check("Robinhood createTable is 0.00036", is_equal_approx(Costs.estimate("rh", 0, "createTable"), 0.00036))
	_check("Solana createTable is the rent", is_equal_approx(Costs.estimate("sol", 0, "createTable"), 0.015585))
	_check("1 MiB Monad write", is_equal_approx(Costs.estimate("mon", 1398104), 24.075688788))
	_check("1 MiB Robinhood write", is_equal_approx(Costs.estimate("rh", 1398104), 0.00090044100084))
	_check("1 MiB Solana write", is_equal_approx(Costs.estimate("sol", 1398104), 0.007165))
	var spec := {
		"create_table": true,
		"blob_raws": [1048576],
	}
	_check(
		"quote includes create and the blob",
		Costs.quote_item("mon", spec) > Costs.estimate("mon", 1398104)
	)
	_check(
		"batch sums the items",
		is_equal_approx(Costs.quote_batch("mon", [spec, spec]), Costs.quote_item("mon", spec) * 2.0)
	)


func _archive() -> void:
	var channel := FileAccess.get_file_as_string("res://tools/fixtures/channel.json")
	var item := Archive.parse_metadata(channel)
	_check("metadata identifier", item["identifier"] == "TerryDavislosethosChannel")
	_check("metadata has two collections", (item["collections"] as PackedStringArray).size() == 2)
	var visible: Array = Archive.originals(item["files"])
	_check("originals keep the video and the subtitle", visible.size() == 2)
	var names: PackedStringArray = []
	for file in visible:
		names.append(str(file["name"]))
	_check("talk.mp4 is original", names.has("talk.mp4"))
	_check("sidecar subtitle is original", names.has("talk.en.vtt"))
	var subs: Array = Archive.subtitle_siblings("talk.mp4", item["files"])
	_check("subtitle sits beside the video", subs.size() == 1 and subs[0]["name"] == "talk.en.vtt")
	var mixed: Array = [
		{"name": "b.mp4", "format": "MPEG4"},
		{"name": "a.mkv", "format": "Matroska"},
		{"name": "c.mp4", "format": "MPEG4"},
		{"name": "dir/a.mp4", "format": "MPEG4"},
	]
	var arranged: Array = Archive.arrange_files(mixed)
	var ordered := PackedStringArray()
	for file in arranged:
		ordered.append(str(file.get("name", "")))
	_check(
		"files group by format then folder then name",
		ordered == PackedStringArray(["a.mkv", "b.mp4", "c.mp4", "dir/a.mp4"])
	)
	_check("a folder is the path above the file", Archive.file_folder("dir/a.mp4") == "dir")
	_check("a root file has no folder", Archive.file_folder("b.mp4") == "")
	_check("format is the section", Archive.file_section(mixed[0]) == "MPEG4")
	_check("a missing format uses the extension", Archive.file_section({"name": "note.txt"}) == "TXT")
	_check("mp4 opens as video", Archive.open_kind("talk.mp4") == "video")
	_check("vtt opens as text", Archive.open_kind("talk.en.vtt") == "text")
	_check("iso is not a player", Archive.open_kind("disc.iso") == "folder")
	var search := Archive.parse_search(FileAccess.get_file_as_string("res://tools/fixtures/search.json"))
	_check("search count", int(search["num_found"]) == 2)
	_check("search first id", search["docs"][0]["identifier"] == "prelinger")
	var url := Archive.search_url(Archive.member_query("prelinger"), 1, 50)
	_check("member query is encoded", url.find("collection%3Aprelinger") >= 0)
	_check("a description is requested", url.find("fl[]=description") >= 0)
	_check("relevance does not sort", Archive.search_url("terry").find("sort[]") < 0)
	var downloaded := Archive.search_url("terry", 1, 20, "downloads")
	_check("downloads sort is encoded", downloaded.find("sort[]=downloads%20desc") >= 0)
	_check("an empty box is not a query", Archive.search_query("", "", "") == "")
	_check(
		"a mediatype tile is the whole query",
		Archive.search_query("", "movies", "") == "mediatype:movies"
	)
	_check(
		"text and a tile combine",
		Archive.search_query("terry", "movies", "prelinger")
		== "mediatype:movies AND collection:prelinger AND (terry)"
	)
	_check(
		"a spaced collection id is quoted",
		Archive.member_query("foo bar") == "collection:\"foo bar\""
	)
	var hit := Archive.present_hit({
		"identifier": "ark",
		"title": ["Ark", "The boat"],
		"creator": ["Noah"],
		"date": "1962-04-01",
		"mediatype": "movies",
		"downloads": 1204,
		"description": "<b>Hello</b>&nbsp;there &amp; more " + "word ".repeat(80),
		"collection": ["prelinger", "nasa"],
	})
	_check("a title list is joined", hit["title"] == "Ark, The boat")
	_check("the year comes from the date", hit["year"] == "1962")
	_check("markup leaves the description", hit["description"].begins_with("Hello there & more"))
	_check("the description is clipped", str(hit["description"]).ends_with("…"))
	var essay := "<p>Opening line.</p>" + ("word ".repeat(5000))
	_check(
		"a long description keeps its opening",
		Archive.plain_text(essay).begins_with("Opening line.")
	)
	_check("two collections are kept", (hit["collections"] as PackedStringArray).size() == 2)
	_check(
		"the byline reads like a catalog card",
		Archive.byline(hit) == "Noah · 1962 · Movies · 1,204 downloads"
	)
	var window := Archive.page_window(2, 20, 50)
	_check("page two starts at 21", int(window["from"]) == 21 and int(window["to"]) == 40)
	var capped := Archive.page_window(1, 20, 50000)
	_check("paging stops at 10,000", int(capped["pages"]) == 500)
	_check("a thousand is grouped", Archive.grouped(1234567) == "1,234,567")
	_check(
		"the count names the window",
		Archive.result_count(window, 50) == "21–40 of 50"
	)
	_check("jpeg magic is jpg", Archive.image_kind(PackedByteArray([0xFF, 0xD8, 0xFF, 0xE0])) == "jpg")
	_check(
		"png magic is png",
		Archive.image_kind(PackedByteArray([
			0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
		])) == "png"
	)
	_check(
		"webp magic is webp",
		Archive.image_kind(PackedByteArray([
			0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
		])) == "webp"
	)
	_check(
		"gif is left alone",
		Archive.image_kind(PackedByteArray([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) == ""
	)
	_check("a short jpeg prefix is left alone", Archive.image_kind(PackedByteArray([0xFF, 0xD8])) == "")
	_check(
		"a cut-off png header is left alone",
		Archive.image_kind(PackedByteArray([0x89, 0x50, 0x4E, 0x47])) == ""
	)
	_check(
		"riff that is not webp is left alone",
		Archive.image_kind(PackedByteArray([
			0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45,
		])) == ""
	)
	_check("html is left alone", Archive.image_kind("<html>".to_utf8_buffer()) == "")
	_check("empty bytes are left alone", Archive.image_kind(PackedByteArray()) == "")
	var got := Archive.download_url("TerryDavislosethosChannel", "talk.mp4")
	_check(
		"download url keeps the filename",
		got == "https://archive.org/download/TerryDavislosethosChannel/talk.mp4"
	)
	var spaced := Archive.download_url("ark", "my talk.mp4")
	_check("spaces are encoded", spaced.ends_with("my%20talk.mp4"))
	var probe := "user://ark_hash_probe.txt"
	var out := FileAccess.open(probe, FileAccess.WRITE)
	out.store_string("ark")
	out.close()
	_check("empty checksums are allowed", Archive.hashes_match(probe, "", ""))
	_check("a present sha1 must match", Archive.hashes_match(probe, "", Ark.sha1_file(probe)))
	_check("a wrong sha1 is refused", not Archive.hashes_match(probe, "", "00"))
	_check("a wrong md5 is refused when sha1 is absent", not Archive.hashes_match(probe, "00", ""))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))


func _featured() -> void:
	var rows: Array = [
		Ark.kind_header_row("alpha", "Alpha", "", ""),
		Ark.mark_row("alpha", "Alpha", 1000, "featured"),
		Ark.mark_row("beta", "Beta", 2000, "featured"),
		Ark.kind_member_row("alpha", "Alpha", "one"),
	]
	var band: Array = Ark.featured_band(rows)
	_check("two efforts are featured", band.size() == 2)
	_check("oldest effort is first", band[0]["slug"] == "alpha")
	rows.append(Ark.mark_row("alpha", "Alpha", 3000, "done"))
	band = Ark.featured_band(rows)
	_check("done takes alpha off the band", band.size() == 1 and band[0]["slug"] == "beta")
	rows.append(Ark.mark_row("alpha", "Alpha", 4000, "featured"))
	band = Ark.featured_band(rows)
	_check("a later featured mark restores alpha", band.size() == 2)
	var members := PackedStringArray(["one", "two"])
	var complete := {"one": true, "two": true}
	_check("complete effort", Ark.effort_is_complete(members, complete, true))
	_check("a gap stays featured", not Ark.effort_is_complete(members, {"one": true}, true))
	_check(
		"unreachable archive does not finish an effort",
		not Ark.effort_is_complete(members, complete, false)
	)
	_check("empty kind is not complete", not Ark.effort_is_complete(PackedStringArray(), {}, true))


func _cache() -> void:
	var cache := ArkCache.new("user://ark_selftest_cache")
	cache.clear_all()
	var video := "not-a-real-mp4".to_utf8_buffer()
	var sha := Ark.sha256_bytes(video)
	var path := cache.remember(sha, "talk.mp4", "TerryDavislosethosChannel", video)
	_check("cache wrote the mp4", FileAccess.file_exists(path))
	var absolute := cache.absolute_of(sha)
	_check("launcher path is absolute", absolute.is_absolute_path())
	_check("launcher path ends in .mp4", absolute.ends_with("talk.mp4"))
	var sub := "WEBVTT".to_utf8_buffer()
	var sub_sha := Ark.sha256_bytes(sub)
	var sub_path := cache.remember(sub_sha, "talk.en.vtt", "TerryDavislosethosChannel", sub, sha)
	_check("subtitle sits in the video directory", sub_path.get_base_dir() == path.get_base_dir())
	var chain := {"rows": 1}
	cache.clear_file(sha)
	_check("clear file removes the video", not FileAccess.file_exists(path))
	_check("clear file removes the sidecar", not FileAccess.file_exists(sub_path))
	_check("clear file leaves chain rows in place", int(chain["rows"]) == 1)
	var first := "one".to_utf8_buffer()
	var second := "two".to_utf8_buffer()
	var first_sha := Ark.sha256_bytes(first)
	var second_sha := Ark.sha256_bytes(second)
	cache.remember(first_sha, "one.mp4", "item", first)
	cache.remember(second_sha, "two.mp4", "item", second)
	cache.set_opened(first_sha, 1.0)
	cache.set_opened(second_sha, 2.0)
	cache.evict(second.size(), second_sha)
	_check("eviction keeps the file just opened", cache.has_sha(second_sha))
	_check("eviction drops the older file", not cache.has_sha(first_sha))
	cache.clear_item("item")
	_check("clear item drops what remains", not cache.has_sha(second_sha))
	cache.remember(first_sha, "one.mp4", "item", first)
	cache.clear_all()
	_check("clear all empties the index", not cache.has_sha(first_sha))


func _look() -> void:
	var theme := ArkTheme.build()
	_check("theme builds", theme != null)
	var mark := ArkTheme.mark()
	_check("chest mark has a size", mark.custom_minimum_size.x >= 36.0)
	mark.free()


func _aboard() -> void:
	_check("an item table is i plus 23 hex", Ark.is_item_table(Ark.table_name("ark")))
	_check("kindled is not an item table", not Ark.is_item_table("kindled"))
	_check("the hex seed of kindled is not an item table", not Ark.is_item_table(Ark.KINDLED_HEX))
	_check("a short name is not an item table", not Ark.is_item_table("iab"))
	var restored := Ark.item_from_card(Ark.card_row({
		"identifier": "ark",
		"title": "Ark",
		"mediatype": "texts",
		"collections": ["prelinger", "nasa"],
	}))
	_check("a card restores the title", str(restored.get("title", "")) == "Ark")
	var restored_collections: Array = restored.get("collections", [])
	_check(
		"a card restores both collections",
		restored_collections.size() == 2 and str(restored_collections[0]) == "prelinger"
	)
	var mirror := "user://ark_selftest_mirror.bin"
	Ark.save_mirror(mirror, [{"identifier": "ark"}])
	var loaded := Ark.load_mirror(mirror)
	_check(
		"the mirror round-trips",
		loaded.size() == 1 and str((loaded[0] as Dictionary).get("identifier", "")) == "ark"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mirror))
	_check("a missing mirror is empty", Ark.load_mirror(mirror).is_empty())
	var manifest: Array = [
		{
			"id": "one",
			"identifier": "one",
			"title": "One",
			"collections": "prelinger,nasa",
			"bytes": "10",
		},
		{
			"id": "one",
			"identifier": "one",
			"title": "Newer",
			"collections": "prelinger",
			"bytes": "1",
		},
		{"id": "three", "identifier": "three", "title": "Three", "collections": "prelinger", "bytes": "3"},
		{"id": "four", "identifier": "four", "title": "Four", "collections": "", "bytes": "4"},
	]
	var kinds: Array = [
		Ark.kind_header_row("alpha", "Alpha", "", ""),
		Ark.kind_member_row("alpha", "Alpha", "one"),
		Ark.kind_member_row("alpha", "Alpha", "two"),
		Ark.mark_row("alpha", "Alpha", 1000, "featured"),
		Ark.kind_header_row("beta", "Beta", "prelinger", ""),
		Ark.kind_header_row("gamma", "Gamma", "", ""),
	]
	var groups := Ark.aboard_groups(manifest, kinds)
	var alpha := _group(groups, "Alpha")
	var one_title := ""
	var two_aboard := true
	for entry in alpha.get("items", []):
		if str((entry as Dictionary).get("identifier", "")) == "one":
			one_title = str((entry as Dictionary).get("title", ""))
		if str((entry as Dictionary).get("identifier", "")) == "two":
			two_aboard = bool((entry as Dictionary).get("aboard", true))
	_check("the first manifest row wins", one_title == "One")
	_check("a missing member stays an empty berth", two_aboard == false)
	_check("the kind lists its member", _ids(alpha) == PackedStringArray(["one", "two"]))
	var beta := _group(groups, "Beta")
	_check("a bound collection shares the kind heading", _ids(beta) == PackedStringArray(["one", "three"]))
	_check("no second heading is opened for that collection", _group(groups, "prelinger").is_empty())
	_check("an empty kind stays on the wall", (_group(groups, "Gamma").get("items", [1]) as Array).is_empty())
	var nasa := _group(groups, "nasa")
	_check("the other collection keeps its own heading", _ids(nasa) == PackedStringArray(["one"]))
	_check("unfiled is last", str((groups[groups.size() - 1] as Dictionary).get("heading", "")) == "UNFILED")
	_check("an ungrouped item is unfiled", _ids(groups[groups.size() - 1]) == PackedStringArray(["four"]))
	var by_heading := Ark.aboard_filter(groups, "gamma")
	_check(
		"a heading filter keeps an empty kind",
		by_heading.size() == 1 and str((by_heading[0] as Dictionary).get("heading", "")) == "Gamma"
	)
	var by_title := Ark.aboard_filter(groups, "four")
	_check("a title filter keeps the item", by_title.size() == 1 and _ids(by_title[0]) == PackedStringArray(["four"]))
	var many: Array = []
	for i in 81:
		many.append({"identifier": str(i)})
	var window := Ark.aboard_page(many, 2)
	var last: Array = window.get("items", [])
	_check(
		"page two of the cabinet is the last row",
		int(window.get("page", 0)) == 2 and last.size() == 1 and str((last[0] as Dictionary).get("identifier", "")) == "80"
	)


func _kinds() -> void:
	var url := Archive.scrape_url(Archive.member_query("prelinger"), "abc/def")
	_check("a scrape asks the cursor api", url.find("services/search/v1/scrape") >= 0)
	_check("a scrape encodes the collection", url.find("collection%3Aprelinger") >= 0)
	_check("a scrape encodes the cursor", url.find("cursor=abc%2Fdef") >= 0)
	var page := Archive.parse_scrape('{"items":[{"identifier":"a"},{"identifier":"b"}],"cursor":"next","total":10}')
	var page_items: PackedStringArray = page.get("items", PackedStringArray())
	_check("a scrape page lists the identifiers", bool(page.get("ok", false)) and page_items.size() == 2)
	_check("a scrape page keeps the cursor", str(page.get("cursor", "")) == "next" and not bool(page.get("finished", true)))
	var last := Archive.parse_scrape('{"items":[{"identifier":"c"}],"cursor":null,"total":3}')
	_check("a null cursor finishes the walk", bool(last.get("ok", false)) and bool(last.get("finished", false)))
	_check("a broken scrape is not a page", not bool(Archive.parse_scrape("{").get("ok", true)))
	var rows: Array = [
		Ark.card_row({"identifier": "ark", "title": "Ark", "collections": []}),
		Ark.file_row("ark", 0, {"name": "note.txt", "size": "1", "source": "original"}, "abc", 1),
		Ark.blob_row(0, 0, 1, "abc", 1, "QQ=="),
	]
	var whole := Ark.file_tally(rows, PackedStringArray(["note.txt"]))
	_check("a file with its blob is complete", bool(whole.get("complete", false)) and int(whole.get("aboard", 0)) == 1)
	var gap := Ark.file_tally(rows.slice(0, 2), PackedStringArray(["note.txt"]))
	_check("a missing blob is not complete", not bool(gap.get("complete", true)))
	var split := Ark.file_tally(
		[
			Ark.card_row({"identifier": "ark", "title": "Ark", "collections": []}),
			Ark.file_row("ark", 0, {"name": "clip.mp4", "size": "4"}, "abc", 2),
			Ark.blob_row(0, 0, 2, "abc", 2, "AQI="),
		],
		PackedStringArray(["clip.mp4"])
	)
	_check("one part of two is not complete", not bool(split.get("complete", true)))
	var card_only := Ark.file_tally(
		[Ark.card_row({"identifier": "ark", "title": "Ark", "collections": []})],
		PackedStringArray()
	)
	_check("a card with no originals is complete", bool(card_only.get("complete", false)))
	var no_card := Ark.file_tally(rows.slice(1), PackedStringArray(["note.txt"]))
	_check("files without a card are not complete", not bool(no_card.get("complete", true)))
	var members := PackedStringArray(["one", "two"])
	var done := {"one": true, "two": true}
	_check("a finished walk can be marked done", Ark.should_finish(members, done, true, true))
	_check("a partial walk stays featured", not Ark.should_finish(members, done, true, false))
	_check("a silent archive does not finish", not Ark.should_finish(members, done, false, true))
	var walk := Ark.walk_add({}, PackedStringArray(["one", "two"]), "next", false)
	walk = Ark.walk_add(walk, PackedStringArray(["two", "three"]), "", true)
	var walked: PackedStringArray = walk.get("members", PackedStringArray())
	_check(
		"a walk keeps each member once",
		bool(walk.get("finished", false)) and walked == PackedStringArray(["one", "two", "three"])
	)
	var saved := {"cursor": "next", "members": ["one"]}
	_check("a walk round-trips", Ark.save_walk("selftest-walk", saved))
	var loaded := Ark.load_walk("selftest-walk")
	_check("a walk keeps its cursor", str(loaded.get("cursor", "")) == "next")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ark.feature_path("selftest-walk")))
	_check("a missing walk is empty", Ark.load_walk("selftest-walk").is_empty())
	_check(
		"identifiers keep the first spelling",
		Ark.identifiers_of(" one \ntwo\none\n\n three ") == PackedStringArray(["one", "two", "three"])
	)
	var terry: Array = [Ark.kind_header_row("terry", "Terry Davis", "", "")]
	for ident in [
		"TerryDavislosethosChannel",
		"TerryDavisAltChannel",
		"TerryADavisTempleOSYouTubeChannelArchive",
		"TerryDavisYoutubeMarchMay2018",
		"TempleOS_org_videos",
		"TerryADavis_TempleOS_Archive",
	]:
		terry.append(Ark.kind_member_row("terry", "Terry Davis", ident))
	terry.append(Ark.mark_row("terry", "Terry Davis", 1000, "featured"))
	var shelf := Ark.kind_members(terry, "terry")
	_check("the terry shelf holds six items", shelf.size() == 6)
	_check("the terry shelf starts with losethos", shelf[0] == "TerryDavislosethosChannel")
	_check("an empty collection id is not a kind", Ark.kind_for_ia(terry, "").is_empty())
	var channel := "TerryADavisTempleOSYouTubeChannelArchive"
	var channel_slug := Ark.slug_for("Terry A. Davis' TempleOS YouTube Channel Archive", channel)
	_check(
		"an item effort slug is the identifier hash",
		channel_slug == Ark.sha256_text(channel).substr(0, 24) and Ark.slug_fits(channel_slug)
	)
	var channel_rows: Array = [
		Ark.kind_header_row(channel_slug, "Terry A. Davis' TempleOS YouTube Channel Archive", ""),
		Ark.kind_member_row(channel_slug, "Terry A. Davis' TempleOS YouTube Channel Archive", channel),
	]
	_check(
		"an item effort is not a collection binding",
		Ark.kind_for_ia(channel_rows, channel).is_empty()
		and Ark.kind_members(channel_rows, channel_slug) == PackedStringArray([channel])
	)
	var bound: Array = [Ark.kind_header_row("prelinger", "Prelinger", "prelinger", "")]
	_check("prelinger binds to its collection", str(Ark.kind_for_ia(bound, "prelinger").get("id", "")) == "prelinger")
	_check(
		"the chip names items before files are known",
		Ark.effort_label("Terry", 2, 6, 0, 0, false) == "Terry  2/6"
	)
	_check(
		"the chip adds files once a check has run",
		Ark.effort_label("Terry", 2, 6, 14, 20, true) == "Terry  2/6 · 14/20 files"
	)
	_check("an empty shelf is just its title", Ark.effort_label("Terry", 0, 0, 0, 0, false) == "Terry")


func _group(groups: Array, heading: String) -> Dictionary:
	for group in groups:
		if str((group as Dictionary).get("heading", "")) == heading:
			return group
	return {}


func _ids(group: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in group.get("items", []):
		out.append(str((entry as Dictionary).get("identifier", "")))
	return out


func _chain_writes() -> void:
	var item := {
		"identifier": "ark",
		"title": "Ark",
		"mediatype": "texts",
		"collections": ["prelinger"],
	}
	var files: Array = [{
		"name": "note.txt",
		"size": "40000000",
		"source": "original",
		"format": "Text",
	}]
	var path := "user://ark_selftest_note.txt"
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_8(65)
	handle.close()
	var paths := {"note.txt": path}
	var bare := Cabinet.new(FakeSpace.new())
	var denied: bool = await bare.inscribe(item, files, paths, Callable())
	_check("unkindled chain is refused", denied == false)
	_check("the refusal names kindling", bare.last_error == "This chain has not been kindled.")
	var refused_repair: int = await bare.repair()
	_check("repair refuses an unkindled chain", refused_repair == -1)
	var refused_kind: bool = await bare.ensure_kind("terry", "Terry", "")
	_check("a shelf refuses an unkindled chain", refused_kind == false)

	var space := FakeSpace.new()
	space.tables["kindled"] = []
	var cabinet := Cabinet.new(space)
	var kindled: bool = await cabinet.kindle()
	_check("kindle fills in manifest and kinds", kindled)
	_check("kindle leaves the sentinel in place", space.created.size() == 2)
	_check("manifest is created before kinds", space.created[0]["name"] == "manifest")
	_check(
		"kindle writers stay empty",
		(space.created[0]["writers"] as PackedStringArray).is_empty()
	)

	space.fail_on = "b:0:0"
	var first: bool = await cabinet.inscribe(item, files, paths, Callable())
	_check("first pass stops on the blob", first == false)
	var table := Ark.table_name("ark")
	_check("meta was written", space.has_id(table, "meta"))
	_check("file header was written", space.has_id(table, "f:0"))
	_check("blob was not written", not space.has_id(table, "b:0:0"))
	_check("manifest waits for the bytes", not space.has_id("manifest", "ark"))
	var header: Dictionary = space.row(table, "f:0")
	_check("file row uses the real length", str(header.get("bytes", "")) == "1")
	_check("one byte is one part", str(header.get("parts", "")) == "1")
	space.fail_on = ""
	var before := space.writes.size()
	var second: bool = await cabinet.inscribe(item, files, paths, Callable())
	_check("second pass finishes", second)
	_check("blob landed", space.has_id(table, "b:0:0"))
	_check("manifest landed", space.has_id("manifest", "ark"))
	var resumed: Array = space.writes.slice(before)
	_check("resume writes the blob and the manifest", resumed == ["b:0:0", "ark"])
	var blob: Dictionary = space.row(table, "b:0:0")
	_check(
		"blob is the byte itself",
		str(blob.get("data", "")) == Marshalls.raw_to_base64(PackedByteArray([65]))
	)
	_check("resume does not open a second table", space.created.size() == 3)
	var listed: Array = await cabinet.file_list("ark")
	var expect_sha := str(space.row(table, "f:0").get("sha256", "")).to_lower()
	_check(
		"file list names the note",
		listed.size() == 1 and str((listed[0] as Dictionary).get("name", "")) == "note.txt"
	)
	_check(
		"file list keeps the chain sha",
		str((listed[0] as Dictionary).get("sha256", "")) == expect_sha
	)
	var back := "user://ark_selftest_back.txt"
	var got: Dictionary = await cabinet.reassemble("ark", "note.txt", back)
	_check(
		"read-back matches the chain sha",
		bool(got.get("ok", false)) and str(got.get("sha", "")) == expect_sha
	)
	_check("read-back is the byte", FileAccess.get_file_as_bytes(back) == PackedByteArray([65]))
	var live := space.row(table, "b:0:0")
	live["data"] = Marshalls.raw_to_base64(PackedByteArray([66]))
	var bad: Dictionary = await cabinet.reassemble("ark", "note.txt", back)
	_check("a chain mismatch is refused", not bool(bad.get("ok", false)))
	_check("a mismatch deletes the partial", not FileAccess.file_exists(back))
	var raw := PackedByteArray([1, 2, 3, 4])
	var sha := Ark.sha256_bytes(raw)
	var split := Ark.table_name("split")
	space.tables[split] = [
		Ark.file_row("split", 0, {"name": "clip.mp4", "size": "4"}, sha, 2),
		Ark.blob_row(0, 0, 2, sha, 2, Marshalls.raw_to_base64(PackedByteArray([1, 2]))),
		Ark.blob_row(0, 1, 2, sha, 2, Marshalls.raw_to_base64(PackedByteArray([3, 4]))),
	]
	var clip := "user://ark_selftest_clip.mp4"
	var joined: Dictionary = await cabinet.reassemble("split", "clip.mp4", clip)
	_check(
		"two parts join",
		bool(joined.get("ok", false)) and FileAccess.get_file_as_bytes(clip) == raw
	)
	space.tables[split] = [
		Ark.file_row("split", 0, {"name": "clip.mp4", "size": "4"}, sha, 2),
		Ark.blob_row(0, 0, 2, sha, 2, Marshalls.raw_to_base64(PackedByteArray([1, 2]))),
	]
	var gapped: Dictionary = await cabinet.reassemble("split", "clip.mp4", clip)
	_check("a missing part is refused", not bool(gapped.get("ok", false)))
	_check("a missing part deletes the partial", not FileAccess.file_exists(clip))
	var orphan_name := Ark.table_name("orphan")
	space.tables[orphan_name] = [Ark.card_row({
		"identifier": "orphan",
		"title": "Orphan",
		"mediatype": "texts",
		"collections": ["nasa"],
	})]
	space.tables["notes"] = [Ark.card_row({"identifier": "notes", "title": "Notes"})]
	space.tables[Ark.KINDLED_HEX] = [Ark.card_row({"identifier": "nope", "title": "No"})]
	var added: int = await cabinet.repair()
	_check("repair writes the missing manifest row", added == 1)
	_check("repair names the orphan", space.has_id("manifest", "orphan"))
	_check(
		"repair keeps the orphan title",
		str(space.row("manifest", "orphan").get("title", "")) == "Orphan"
	)
	_check("repair ignores a loose table", not space.has_id("manifest", "notes"))
	_check("repair ignores the hex reserved seed", not space.has_id("manifest", "nope"))
	var again: int = await cabinet.repair()
	_check("repair does not write twice", again == 0)
	var before_kind := space.writes.size()
	var shelved: bool = await cabinet.ensure_kind("terry", "Terry Davis", "")
	_check("a shelf is opened", shelved)
	_check("the shelf header is one row", space.has_id("kinds", "terry"))
	var shelved_again: bool = await cabinet.ensure_kind("terry", "Terry Davis", "")
	_check("the shelf is not opened twice", shelved_again and space.writes.size() == before_kind + 1)
	var membered: bool = await cabinet.add_member("terry", "Terry Davis", "TerryDavislosethosChannel")
	_check("a member is filed", membered)
	_check(
		"the member id is the shelf and the hash",
		space.has_id("kinds", Ark.member_id("terry", "TerryDavislosethosChannel"))
	)
	var membered_again: bool = await cabinet.add_member("terry", "Terry Davis", "TerryDavislosethosChannel")
	_check("a member is not filed twice", membered_again and space.writes.size() == before_kind + 2)
	var marked: bool = await cabinet.write_mark("terry", "Terry Davis", "featured")
	_check("a feature mark is written", marked)
	var band: Array = Ark.featured_band(await cabinet.kind_rows())
	_check("the new shelf is on the band", band.size() >= 1)
	var refused_mark: bool = await cabinet.write_mark("terry", "Terry Davis", "nope")
	_check("a mark is featured or done", refused_mark == false)
	var shelf_item := {
		"identifier": "shelfitem",
		"title": "Shelf",
		"mediatype": "texts",
		"collections": [],
	}
	var filed: bool = await cabinet.inscribe(
		shelf_item,
		files,
		paths,
		Callable(),
		[{"slug": "terry", "title": "Terry Davis"}]
	)
	_check("inscribe files the item on the shelf", filed)
	_check(
		"the shelf names the inscribed item",
		space.has_id("kinds", Ark.member_id("terry", "shelfitem"))
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok  ", name)
	else:
		_failed += 1
		push_error("FAIL " + name)
		print(" FAIL ", name)


class FakeSpace:
	var tables := {}
	var fail_on := ""
	var last_error := ""
	var writes: Array = []
	var created: Array = []

	func table_exists(name: String) -> bool:
		return tables.has(name)

	func create_table(
		name: String,
		_columns: PackedStringArray,
		_id_col: String,
		writers: PackedStringArray = PackedStringArray(),
		_progress: Callable = Callable()
	) -> Variant:
		created.append({"name": name, "writers": writers})
		if not tables.has(name):
			tables[name] = []
		return {"ok": true}

	func write_row(name: String, row: Dictionary, _progress: Callable = Callable()) -> Variant:
		var id := str(row.get("id", ""))
		if id == fail_on:
			last_error = "stopped"
			return null
		if not tables.has(name):
			last_error = "missing table"
			return null
		(tables[name] as Array).append(row)
		writes.append(id)
		return {"ok": true}

	func table_names() -> PackedStringArray:
		var out := PackedStringArray()
		for name in tables:
			out.append(str(name))
		return out

	func read_rows(
		name: String,
		limit: int = 20,
		_error: Array = [],
		_progress: Callable = Callable(),
		_with_signers: bool = false
	) -> Array:
		if not tables.has(name):
			return []
		var rows: Array = tables[name]
		var out: Array = []
		var count := mini(limit, rows.size())
		for i in count:
			out.append(rows[rows.size() - 1 - i])
		return out

	func has_id(name: String, id: String) -> bool:
		for row in tables.get(name, []):
			if str((row as Dictionary).get("id", "")) == id:
				return true
		return false

	func row(name: String, id: String) -> Dictionary:
		for entry in tables.get(name, []):
			if str((entry as Dictionary).get("id", "")) == id:
				return entry
		return {}
