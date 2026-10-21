## Protocol ark/1. One Archive item is one table under the shared root.
## A kind is a shelf. A mark on that shelf is a community effort.

class_name Ark
extends RefCounted

const PROTOCOL := "ark/1"
const APP_ROOT := "GodOnChain-KingTerry-Ark"
const KINDLED_TABLE := "kindled"
const MANIFEST_TABLE := "manifest"
const KINDS_TABLE := "kinds"
const KINDLED_HEX := "6b696e646c6564"
const MANIFEST_HEX := "6d616e6966657374"
const KINDS_HEX := "6b696e6473"

const PART_RAW_BYTES := 32 * 1024 * 1024
const SELECT_ALL_LIMIT := 100 * 1024 * 1024
const CACHE_LIMIT_DEFAULT := 8 * 1024 * 1024 * 1024
const ABOARD_PAGE := 80
const MANIFEST_MIRROR := "user://manifest.bin"
const KINDS_MIRROR := "user://kinds.bin"

const ITEM_COLUMNS := [
	"id", "identifier", "name", "role", "sha256", "bytes", "part", "parts", "format", "data",
]
const MANIFEST_COLUMNS := [
	"id", "identifier", "title", "mediatype", "table", "bytes", "collections",
]
const KINDS_COLUMNS := ["id", "title", "ia", "identifier", "note", "state"]
const ID_COLUMN := "id"
const META_ID := "meta"

const _SLUG_MAX := 24
const _RESERVED_SLUGS := ["kindled", "manifest", "kinds"]


static func sha256_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func sha256_text(text: String) -> String:
	return sha256_bytes(text.to_utf8_buffer())


static func sha256_file(path: String) -> String:
	return _hash_file(path, HashingContext.HASH_SHA256)


static func sha1_file(path: String) -> String:
	return _hash_file(path, HashingContext.HASH_SHA1)


static func md5_file(path: String) -> String:
	return _hash_file(path, HashingContext.HASH_MD5)


static func _hash_file(path: String, algo: HashingContext.HashType) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(algo)
	while not file.eof_reached():
		var chunk := file.get_buffer(1024 * 1024)
		if chunk.is_empty():
			break
		ctx.update(chunk)
	file.close()
	return ctx.finish().hex_encode()


static func table_name(identifier: String) -> String:
	return "i" + sha256_text(identifier.strip_edges()).substr(0, 23)


static func is_reserved_table(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	return (
		n == KINDLED_TABLE
		or n == MANIFEST_TABLE
		or n == KINDS_TABLE
		or n == KINDLED_HEX
		or n == MANIFEST_HEX
		or n == KINDS_HEX
	)


## An item table name is "i" plus 23 hex characters. That string is already
## the name. A Solana listing returns the hex of the name, and decoding the
## name a second time is how a repair misses the table.
static func is_item_table(name: String) -> bool:
	var n := name.strip_edges().to_lower()
	if is_reserved_table(n) or n.length() != 24 or not n.begins_with("i"):
		return false
	for i in 23:
		var c := n[i + 1]
		var hex := (c >= "0" and c <= "9") or (c >= "a" and c <= "f")
		if not hex:
			return false
	return true


static func slug_fits(text: String) -> bool:
	if text.is_empty() or text.length() > _SLUG_MAX:
		return false
	if text in _RESERVED_SLUGS:
		return false
	for i in text.length():
		var c := text[i]
		var ok := (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-"
		if not ok:
			return false
	return true


static func normalize_slug(text: String) -> String:
	var raw := text.strip_edges().to_lower()
	var out := ""
	var dash := false
	for i in raw.length():
		var c := raw[i]
		var ok := (c >= "a" and c <= "z") or (c >= "0" and c <= "9")
		if ok:
			out += c
			dash = false
		elif not dash and not out.is_empty():
			out += "-"
			dash = true
		if out.length() >= _SLUG_MAX:
			break
	return out.trim_suffix("-").substr(0, _SLUG_MAX)


## A collection id is the slug when it already fits. Otherwise the slug is
## the first 24 hex chars of sha256(id). A titled kind with no collection
## uses the normalized title the same way.
static func slug_for(title: String, ia: String = "") -> String:
	var bound := ia.strip_edges()
	if not bound.is_empty():
		if slug_fits(bound):
			return bound
		return sha256_text(bound).substr(0, _SLUG_MAX)
	var normalized := normalize_slug(title)
	if slug_fits(normalized):
		return normalized
	return sha256_text(title.strip_edges()).substr(0, _SLUG_MAX)


static func member_id(slug: String, identifier: String) -> String:
	return "%s/%s" % [slug, sha256_text(identifier.strip_edges()).substr(0, 16)]


static func mark_id(slug: String, unix_ms: int) -> String:
	return "%s/mark/%016d" % [slug, unix_ms]


static func part_count(raw: int) -> int:
	if raw <= 0:
		return 0
	return (raw + PART_RAW_BYTES - 1) / PART_RAW_BYTES


static func part_raw(file_bytes: int, part: int) -> int:
	var parts := part_count(file_bytes)
	if part < 0 or part >= parts:
		return 0
	if part == parts - 1:
		return file_bytes - part * PART_RAW_BYTES
	return PART_RAW_BYTES


static func missing_parts(file_index: int, parts: int, have: Dictionary) -> Array:
	var missing: Array = []
	for part in parts:
		var id := "b:%d:%d" % [file_index, part]
		if not have.has(id):
			missing.append(part)
	return missing


static func file_id(file_index: int) -> String:
	return "f:%d" % file_index


static func blob_id(file_index: int, part: int) -> String:
	return "b:%d:%d" % [file_index, part]


static func _item_row(
	id: String,
	identifier: String,
	name: String,
	role: String,
	sha: String,
	raw_bytes: int,
	part: int,
	parts: int,
	format: String,
	data: String
) -> Dictionary:
	return {
		"id": id,
		"identifier": identifier,
		"name": name,
		"role": role,
		"sha256": sha,
		"bytes": str(raw_bytes),
		"part": str(part),
		"parts": str(parts),
		"format": format,
		"data": data,
	}


static func card_row(item: Dictionary) -> Dictionary:
	var description := str(item.get("description", ""))
	if description.length() > 2048:
		description = description.substr(0, 2048)
	var card := {
		"title": str(item.get("title", "")),
		"creator": str(item.get("creator", "")),
		"date": str(item.get("date", "")),
		"mediatype": str(item.get("mediatype", "")),
		"collection": item.get("collections", []),
		"description": description,
		"item_size": str(item.get("item_size", "")),
		"metadata_sha256": str(item.get("metadata_sha256", "")),
	}
	return _item_row(
		META_ID,
		str(item.get("identifier", "")),
		"",
		"card",
		"",
		0,
		0,
		0,
		"card",
		JSON.stringify(card)
	)


static func file_row(
	identifier: String,
	file_index: int,
	file: Dictionary,
	sha: String,
	parts: int
) -> Dictionary:
	var header := {
		"md5": str(file.get("md5", "")),
		"sha1": str(file.get("sha1", "")),
		"source": str(file.get("source", "")),
		"mtime": str(file.get("mtime", "")),
		"part_raw_bytes": PART_RAW_BYTES,
	}
	return _item_row(
		file_id(file_index),
		identifier,
		str(file.get("name", "")),
		"file",
		sha,
		int(str(file.get("size", "0"))),
		0,
		parts,
		str(file.get("format", "")),
		JSON.stringify(header)
	)


static func blob_row(
	file_index: int,
	part: int,
	parts: int,
	sha: String,
	raw_bytes: int,
	b64: String
) -> Dictionary:
	return _item_row(
		blob_id(file_index, part),
		"",
		"",
		"blob",
		sha,
		raw_bytes,
		part,
		parts,
		"",
		b64
	)


static func manifest_row(item: Dictionary, raw_bytes: int) -> Dictionary:
	var collections: PackedStringArray = []
	var listed: Variant = item.get("collections", [])
	if listed is Array:
		for entry in listed:
			collections.append(str(entry))
	elif listed is PackedStringArray:
		collections = listed
	var joined := ",".join(collections)
	if joined.length() > 400:
		joined = joined.substr(0, 400)
	return {
		"id": str(item.get("identifier", "")),
		"identifier": str(item.get("identifier", "")),
		"title": str(item.get("title", "")),
		"mediatype": str(item.get("mediatype", "")),
		"table": table_name(str(item.get("identifier", ""))),
		"bytes": str(raw_bytes),
		"collections": joined,
	}


static func kind_header_row(slug: String, title: String, ia: String, note: String = "") -> Dictionary:
	return {
		"id": slug,
		"title": title,
		"ia": ia,
		"identifier": "",
		"note": note,
		"state": "",
	}


static func kind_member_row(slug: String, title: String, identifier: String) -> Dictionary:
	return {
		"id": member_id(slug, identifier),
		"title": title,
		"ia": "",
		"identifier": identifier,
		"note": "",
		"state": "",
	}


static func mark_row(slug: String, title: String, unix_ms: int, state: String, note: String = "") -> Dictionary:
	return {
		"id": mark_id(slug, unix_ms),
		"title": title,
		"ia": "",
		"identifier": "",
		"note": note,
		"state": state,
	}


## Latest mark per slug. Keyed by slug, values carry state, id, and title.
## Mark ids sort in time order because the millisecond field is zero-padded.
static func latest_marks(rows: Array) -> Dictionary:
	var best := {}
	for row in rows:
		if not row is Dictionary:
			continue
		var state := str(row.get("state", "")).strip_edges()
		if state != "featured" and state != "done":
			continue
		var id := str(row.get("id", ""))
		var cut := id.find("/mark/")
		if cut < 1:
			continue
		var slug := id.substr(0, cut)
		var prev: Dictionary = best.get(slug, {})
		if prev.is_empty() or id > str(prev.get("id", "")):
			best[slug] = {
				"state": state,
				"id": id,
				"title": str(row.get("title", "")),
				"note": str(row.get("note", "")),
			}
	return best


## Featured efforts, oldest mark first. A later `done` drops the slug.
## A later `featured` puts it back. `note` is the collection size when the
## mark recorded one.
static func featured_band(rows: Array) -> Array:
	var marks := latest_marks(rows)
	var band: Array = []
	for slug in marks:
		var mark: Dictionary = marks[slug]
		if str(mark.get("state", "")) != "featured":
			continue
		band.append({
			"slug": slug,
			"id": str(mark.get("id", "")),
			"title": str(mark.get("title", "")),
			"note": str(mark.get("note", "")),
		})
	band.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := str(a.get("id", ""))
		var b_id := str(b.get("id", ""))
		var a_at := _mark_time(a_id)
		var b_at := _mark_time(b_id)
		if a_at == b_at:
			return a_id < b_id
		return a_at < b_at
	)
	return band


static func _mark_time(id: String) -> String:
	var cut := id.find("/mark/")
	if cut < 0:
		return id
	return id.substr(cut + 6)


## A feature mark may carry the Archive's item count as its note.
## A grouping's note is `f:` plus the original file count, which is not an item count.
static func published_total(note: String) -> int:
	var text := note.strip_edges()
	if not text.is_valid_int():
		return -1
	var n := int(text)
	if n <= 0:
		return -1
	return n


## Original-file count stored on a grouping's feature mark.
static func published_file_total(note: String) -> int:
	var text := note.strip_edges()
	if not text.begins_with("f:"):
		return -1
	return published_total(text.substr(2))


## The one item a featured grouping stands for, such as the TempleOS channel
## archive. A collection binding, and a shelf with any other number of
## members, is not a grouping.
static func item_effort_member(kinds: Array, slug: String) -> String:
	if slug.strip_edges().is_empty():
		return ""
	if not str(kind_header(kinds, slug).get("ia", "")).strip_edges().is_empty():
		return ""
	var members := kind_members(kinds, slug)
	if members.size() != 1:
		return ""
	return members[0]


## The live Archive count wins, then a walk this machine has saved, then the
## size written on the feature mark.
static func known_total(published: int, walked: int, peeked: int) -> int:
	if peeked > 0:
		return peeked
	if walked > 0:
		return walked
	if published > 0:
		return published
	return -1


## Items aboard for one effort, from the manifest every client reads.
## A bound collection uses `archive_total` as the whole collection. Until that
## size is known the fraction stays open, so a few inscribed items are not
## reported as a finished collection. A shelf with no collection id uses its
## member list as the whole effort. Members that are aboard still count when
## the collection list on the manifest row was clipped.
static func effort_progress(
	manifest: Array,
	kinds: Array,
	slug: String,
	ia: String,
	archive_total: int = -1
) -> Dictionary:
	var want := ia.strip_edges()
	var aboard_of := {}
	var seen_row := {}
	for row in manifest:
		if not row is Dictionary:
			continue
		var ident := str(row.get("identifier", "")).strip_edges()
		if ident.is_empty():
			ident = str(row.get("id", "")).strip_edges()
		if ident.is_empty() or seen_row.has(ident):
			continue
		seen_row[ident] = true
		if want.is_empty():
			continue
		if _split_collections(str(row.get("collections", ""))).has(want):
			aboard_of[ident] = true
	var members := kind_members(kinds, slug)
	for ident in members:
		if seen_row.has(ident):
			aboard_of[ident] = true
	var aboard := aboard_of.size()
	var known := false
	var total := 0
	if archive_total > 0:
		known = true
		total = archive_total
	elif not members.is_empty() and want.is_empty():
		known = true
		total = members.size()
	if known and aboard > total:
		total = aboard
	return {"aboard": aboard, "total": total, "known": known}


## One entry per featured effort, oldest mark first. `totals` maps a
## collection id to the Archive's item count when this client knows it.
## `files` maps a grouping slug to `{aboard, total, known}` for its original files.
static func featured_views(
	manifest: Array,
	kinds: Array,
	totals: Dictionary = {},
	files: Dictionary = {}
) -> Array:
	var views: Array = []
	for entry in featured_band(kinds):
		var slug := str(entry.get("slug", ""))
		var title := str(entry.get("title", "")).strip_edges()
		if title.is_empty():
			title = slug
		var ia := str(kind_header(kinds, slug).get("ia", "")).strip_edges()
		var archive_total := -1
		if not ia.is_empty():
			archive_total = int(totals.get(ia, -1))
		var progress := effort_progress(manifest, kinds, slug, ia, archive_total)
		var file_row: Dictionary = files.get(slug, {})
		var files_known := bool(file_row.get("known", false))
		var files_total := maxi(int(file_row.get("total", 0)), 0)
		views.append({
			"slug": slug,
			"title": title,
			"ia": ia,
			"member": item_effort_member(kinds, slug),
			"aboard": int(progress.get("aboard", 0)),
			"total": int(progress.get("total", 0)),
			"known": bool(progress.get("known", false)),
			"files_aboard": int(file_row.get("aboard", 0)) if files_known else 0,
			"files_total": files_total,
			"files_known": files_known,
		})
	return views


## True only when the Archive answered and every member is fully aboard.
## An empty member list is not a finished effort.
static func effort_is_complete(
	members: PackedStringArray,
	complete: Dictionary,
	archive_reachable: bool
) -> bool:
	if not archive_reachable or members.is_empty():
		return false
	for identifier in members:
		if not bool(complete.get(identifier, false)):
			return false
	return true


## A finished walk writes `done` only when the Archive answered and every
## member is fully aboard. A partial scrape, a gap, a silent Archive, or a
## collection larger than the members gathered stays featured.
static func should_finish(
	members: PackedStringArray,
	complete: Dictionary,
	archive_reachable: bool,
	walk_finished: bool,
	archive_total: int = -1
) -> bool:
	if not walk_finished:
		return false
	if archive_total > members.size():
		return false
	return effort_is_complete(members, complete, archive_reachable)


static func kind_header(rows: Array, slug: String) -> Dictionary:
	for row in rows:
		if not row is Dictionary:
			continue
		if str(row.get("id", "")).strip_edges() != slug:
			continue
		if not str(row.get("identifier", "")).strip_edges().is_empty():
			continue
		if not str(row.get("state", "")).strip_edges().is_empty():
			continue
		return row
	return {}


static func kind_for_ia(rows: Array, ia: String) -> Dictionary:
	var want := ia.strip_edges()
	if want.is_empty():
		return {}
	for row in rows:
		if not row is Dictionary:
			continue
		if str(row.get("ia", "")).strip_edges() != want:
			continue
		var slug := str(row.get("id", "")).strip_edges()
		if slug.is_empty() or slug.find("/") >= 0:
			continue
		if not str(row.get("identifier", "")).strip_edges().is_empty():
			continue
		if not str(row.get("state", "")).strip_edges().is_empty():
			continue
		return row
	return {}


static func kind_members(rows: Array, slug: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for row in rows:
		if not row is Dictionary:
			continue
		var id := str(row.get("id", ""))
		if not id.begins_with(slug + "/") or id.find("/mark/") >= 0:
			continue
		var ident := str(row.get("identifier", "")).strip_edges()
		if ident.is_empty() or seen.has(ident):
			continue
		seen[ident] = true
		out.append(ident)
	return out


static func latest_state(rows: Array, slug: String) -> String:
	var marks := latest_marks(rows)
	if not marks.has(slug):
		return ""
	return str((marks[slug] as Dictionary).get("state", ""))


static func row_has_id(rows: Array, id: String) -> bool:
	for row in rows:
		if row is Dictionary and str(row.get("id", "")) == id:
			return true
	return false


static func identifiers_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for line in text.split("\n", false):
		var ident := line.strip_edges()
		if ident.is_empty() or seen.has(ident):
			continue
		seen[ident] = true
		out.append(ident)
	return out


static func merge_ids(first: Variant, second: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for source in [first, second]:
		if not (source is Array or source is PackedStringArray):
			continue
		for entry in source:
			var ident := str(entry).strip_edges()
			if ident.is_empty() or seen.has(ident):
				continue
			seen[ident] = true
			out.append(ident)
	return out


## Fold one scrape page into a walk. Members already recorded stay put.
static func walk_add(
	state: Dictionary,
	identifiers: PackedStringArray,
	cursor: String,
	finished: bool,
	total: int = -1
) -> Dictionary:
	var next := state.duplicate(true)
	next["members"] = merge_ids(next.get("members", []), identifiers)
	next["cursor"] = cursor
	next["finished"] = finished
	if total > 0:
		next["total"] = total
	return next


static func feature_path(slug: String) -> String:
	return "user://feature".path_join(slug + ".bin")


static func save_walk(slug: String, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://feature"))
	var file := FileAccess.open(feature_path(slug), FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(state)
	file.close()
	return true


static func load_walk(slug: String) -> Dictionary:
	var path := feature_path(slug)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var got: Variant = file.get_var()
	file.close()
	return got if got is Dictionary else {}


## Names whose file row and every blob part are on these rows.
static func complete_file_names(rows: Array) -> PackedStringArray:
	var have := {}
	var by_name := {}
	for row in rows:
		if not row is Dictionary:
			continue
		var id := str(row.get("id", ""))
		have[id] = true
		if str(row.get("role", "")) != "file":
			continue
		var name := str(row.get("name", ""))
		if name.is_empty() or by_name.has(name):
			continue
		by_name[name] = row
	var out := PackedStringArray()
	for name in by_name:
		var header: Dictionary = by_name[name]
		var index := _row_index(str(header.get("id", "")))
		if index < 0:
			continue
		var parts := int(str(header.get("parts", "0")))
		var whole := true
		for part in parts:
			if not have.has(blob_id(index, part)):
				whole = false
				break
		if whole:
			out.append(str(name))
	return out


## A file is aboard when its file row and every blob part are present.
## Derivatives are not in `names`. A card with no originals is complete.
static func file_tally(rows: Array, names: PackedStringArray) -> Dictionary:
	var finished := {}
	for name in complete_file_names(rows):
		finished[name] = true
	var aboard := 0
	for name in names:
		if finished.has(name):
			aboard += 1
	var meta := false
	for row in rows:
		if row is Dictionary and str(row.get("id", "")) == META_ID:
			meta = true
			break
	return {
		"complete": meta and aboard == names.size(),
		"aboard": aboard,
		"total": names.size(),
	}


## Files aboard against the original count, without asking the Archive.
##
## When `names` is the Archive's original list, only those files count.
## Otherwise every complete file on `rows` counts, and `published` is the
## `f:` total written on the feature mark when the item was featured.
## A missing denominator stays unknown, so an empty chain is not "0/0".
static func grouping_files(
	rows: Array,
	published: int,
	names: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var aboard := 0
	var total := 0
	if not names.is_empty():
		var tally := file_tally(rows, names)
		aboard = int(tally.get("aboard", 0))
		total = names.size()
	else:
		aboard = complete_file_names(rows).size()
		total = published
	if published > total:
		total = published
	if aboard > total:
		total = aboard
	if total <= 0:
		return {"known": false, "aboard": 0, "total": 0}
	return {"known": true, "aboard": aboard, "total": total}


static func effort_label(
	title: String,
	aboard_items: int,
	member_items: int,
	files_aboard: int,
	files_total: int,
	files_known: bool
) -> String:
	if member_items <= 0:
		return title
	var head := "%s  %d/%d" % [title, aboard_items, member_items]
	if files_known and files_total > 0:
		return "%s · %d/%d files" % [head, files_aboard, files_total]
	return head


static func walk_file_counts(state: Dictionary) -> Dictionary:
	var files: Variant = state.get("files", {})
	var aboard := 0
	var total := 0
	var known := false
	if files is Dictionary and not (files as Dictionary).is_empty():
		known = true
		for ident in files:
			var row: Variant = (files as Dictionary)[ident]
			if not row is Dictionary:
				continue
			aboard += int(row.get("aboard", 0))
			total += int(row.get("total", 0))
	return {"aboard": aboard, "total": total, "known": known}


static func _row_index(id: String) -> int:
	if not id.begins_with("f:"):
		return -1
	var tail := id.substr(2)
	if not tail.is_valid_int():
		return -1
	return int(tail)


static func file_bytes(file: Dictionary) -> int:
	return int(str(file.get("size", "0")))


## The card JSON on a meta row, back into the item shape the manifest writer uses.
static func item_from_card(row: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(str(row.get("data", "")))
	var card: Dictionary = parsed if parsed is Dictionary else {}
	var collections: Array = []
	var listed: Variant = card.get("collection", [])
	if listed is Array:
		collections = listed
	elif listed is PackedStringArray:
		for entry in listed:
			collections.append(str(entry))
	elif not str(listed).strip_edges().is_empty():
		collections.append(str(listed))
	var identifier := str(row.get("identifier", "")).strip_edges()
	return {
		"identifier": identifier,
		"title": str(card.get("title", identifier)),
		"creator": str(card.get("creator", "")),
		"date": str(card.get("date", "")),
		"mediatype": str(card.get("mediatype", "")),
		"collections": collections,
		"description": str(card.get("description", "")),
		"item_size": str(card.get("item_size", "")),
		"metadata_sha256": str(card.get("metadata_sha256", "")),
	}


static func save_mirror(path: String, rows: Array) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(rows)
	file.close()
	return true


static func load_mirror(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var got: Variant = file.get_var()
	file.close()
	return got if got is Array else []


## Kind shelves first, then UNFILED. An item under several shelves is listed
## under each. A shelf bound to an Archive collection also lists manifest rows
## that name that collection. Other collection tags stay on the manifest and
## do not open a heading: archive.org stamps housekeeping ids such as
## deemphasize and additional_collections_video on an upload, and those are
## not shelves anyone filed. A shelf with no finished items stays, so its
## empty berths remain visible. Duplicate manifest rows keep the first one.
static func aboard_groups(manifest: Array, kinds: Array) -> Array:
	var by_id := {}
	var order: Array = []
	for row in manifest:
		if not row is Dictionary:
			continue
		var ident := str(row.get("identifier", "")).strip_edges()
		if ident.is_empty():
			ident = str(row.get("id", "")).strip_edges()
		if ident.is_empty() or by_id.has(ident):
			continue
		by_id[ident] = row
		order.append(ident)

	var groups: Array = []
	var bound := {}
	var seen_header := {}
	for row in kinds:
		if not row is Dictionary:
			continue
		var slug := str(row.get("id", "")).strip_edges()
		if slug.is_empty() or slug.find("/") >= 0 or seen_header.has(slug):
			continue
		if not str(row.get("identifier", "")).strip_edges().is_empty():
			continue
		if not str(row.get("state", "")).strip_edges().is_empty():
			continue
		seen_header[slug] = true
		var ia := str(row.get("ia", "")).strip_edges()
		if not ia.is_empty() and not bound.has(ia):
			bound[ia] = groups.size()
		var items: Array = []
		var seen_member := {}
		for member in kinds:
			if not member is Dictionary:
				continue
			var id := str(member.get("id", ""))
			if not id.begins_with(slug + "/") or id.find("/mark/") >= 0:
				continue
			var member_id := str(member.get("identifier", "")).strip_edges()
			if member_id.is_empty() or seen_member.has(member_id):
				continue
			seen_member[member_id] = true
			items.append(_aboard_entry(member_id, by_id.get(member_id, {})))
		groups.append({
			"key": "kind:" + slug,
			"heading": str(row.get("title", slug)),
			"slug": slug,
			"ia": ia,
			"items": items,
		})

	var placed := {}
	for group in groups:
		for entry in (group as Dictionary).get("items", []):
			if bool((entry as Dictionary).get("aboard", false)):
				placed[str((entry as Dictionary).get("identifier", ""))] = true

	for ident in order:
		var row: Dictionary = by_id[ident]
		var filed := false
		for cid in _split_collections(str(row.get("collections", ""))):
			if not bound.has(cid):
				continue
			var host: Dictionary = groups[int(bound[cid])]
			_aboard_push(host, ident, row)
			filed = true
		if filed:
			placed[ident] = true

	var unfiled: Array = []
	for ident in order:
		if placed.has(ident):
			continue
		unfiled.append(_aboard_entry(ident, by_id[ident]))
	if not unfiled.is_empty():
		groups.append({
			"key": "unfiled",
			"heading": "UNFILED",
			"slug": "",
			"ia": "",
			"items": unfiled,
		})
	return groups


## Keep a group whose heading matches. Otherwise keep the items whose title
## or identifier matches. An empty kind stays only when its heading matches.
static func aboard_filter(groups: Array, query: String) -> Array:
	var q := query.strip_edges().to_lower()
	if q.is_empty():
		return groups
	var out: Array = []
	for group in groups:
		if not group is Dictionary:
			continue
		var heading := str(group.get("heading", ""))
		var items: Array = group.get("items", [])
		var kept: Array = []
		if heading.to_lower().find(q) >= 0:
			kept = items.duplicate()
		else:
			for entry in items:
				if not entry is Dictionary:
					continue
				var title := str(entry.get("title", "")).to_lower()
				var ident := str(entry.get("identifier", "")).to_lower()
				if title.find(q) >= 0 or ident.find(q) >= 0:
					kept.append(entry)
		if kept.is_empty() and heading.to_lower().find(q) < 0:
			continue
		var copy: Dictionary = group.duplicate()
		copy["items"] = kept
		out.append(copy)
	return out


static func aboard_page(items: Array, page: int, size: int = ABOARD_PAGE) -> Dictionary:
	var count := items.size()
	var pages := 1
	if size > 0 and count > size:
		pages = (count + size - 1) / size
	var current := clampi(page, 1, maxi(pages, 1))
	var start := (current - 1) * size if size > 0 else 0
	var end := mini(start + size, count) if size > 0 else count
	return {
		"page": current,
		"pages": pages,
		"items": items.slice(start, end),
	}


static func _split_collections(raw: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in raw.split(",", false):
		var id := part.strip_edges()
		if not id.is_empty() and not out.has(id):
			out.append(id)
	return out


static func _aboard_entry(ident: String, row: Dictionary) -> Dictionary:
	var title := str(row.get("title", "")).strip_edges()
	if title.is_empty():
		title = ident
	return {
		"identifier": ident,
		"title": title,
		"aboard": not row.is_empty(),
		"bytes": str(row.get("bytes", "")),
		"mediatype": str(row.get("mediatype", "")),
	}


static func _aboard_push(group: Dictionary, ident: String, row: Dictionary) -> void:
	var items: Array = group.get("items", [])
	_aboard_push_list(items, ident, row)
	group["items"] = items


static func _aboard_push_list(items: Array, ident: String, row: Dictionary) -> void:
	for entry in items:
		if str((entry as Dictionary).get("identifier", "")) == ident:
			return
	items.append(_aboard_entry(ident, row))


## A lone file starts checked. Two or more start clear, so opening a
## channel archive does not select every file for inscription.
static func default_checked(files: Array, hidden: Callable) -> PackedStringArray:
	var names := PackedStringArray()
	for file in files:
		if not file is Dictionary:
			continue
		if hidden.call(file):
			continue
		var name := str(file.get("name", ""))
		if name.is_empty():
			continue
		names.append(name)
		if names.size() > 1:
			return PackedStringArray()
	return names
