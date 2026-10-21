## One Archive item is one table. Anyone may append the next part.
## Kindling is the operator's act: it creates kindled, manifest, and kinds.

class_name Cabinet
extends RefCounted

## IQSpace on a live host. A test double with the same methods is also fine.
var space: Variant
var last_error: String = ""

const _SETTLE_SEC := 1.5


func _init(iq_or_space: Variant = null, chain: String = "mon") -> void:
	if iq_or_space is IQClient or iq_or_space == null:
		space = IQSpace.new(iq_or_space, Ark.APP_ROOT, chain)
	else:
		space = iq_or_space


func is_kindled() -> bool:
	return await space.table_exists(Ark.KINDLED_TABLE)


## Operator-only. Not a button in the window. Empty writers on every table,
## so a later wallet can keep writing and that choice cannot be tightened.
func kindle(progress: Callable = Callable()) -> bool:
	var specs: Array = [
		[Ark.KINDLED_TABLE, PackedStringArray(["id", "note"])],
		[Ark.MANIFEST_TABLE, PackedStringArray(Ark.MANIFEST_COLUMNS)],
		[Ark.KINDS_TABLE, PackedStringArray(Ark.KINDS_COLUMNS)],
	]
	for spec in specs:
		var name := str(spec[0])
		if await space.table_exists(name):
			continue
		var columns: PackedStringArray = spec[1]
		var created: Variant = await _create(name, columns, progress)
		if created == null:
			return false
		await _settle()
	return true


func manifest_rows(error: Array = []) -> Array:
	return await space.read_rows(Ark.MANIFEST_TABLE, 2000, error)


func kind_rows(error: Array = []) -> Array:
	return await space.read_rows(Ark.KINDS_TABLE, 2000, error)


func item_rows(identifier: String, error: Array = []) -> Array:
	return await space.read_rows(Ark.table_name(identifier), 5000, error)


## The header is written once. A later call with the same slug adds nothing.
func ensure_kind(slug: String, title: String, ia: String = "") -> bool:
	last_error = ""
	if not Ark.slug_fits(slug):
		last_error = "That name cannot be a shelf."
		return false
	if not await is_kindled():
		last_error = "This chain has not been kindled."
		return false
	if not Ark.kind_header(await kind_rows(), slug).is_empty():
		return true
	return await _write(Ark.KINDS_TABLE, Ark.kind_header_row(slug, title, ia))


## A member row is skipped when this item is already on the shelf.
func add_member(slug: String, title: String, identifier: String) -> bool:
	last_error = ""
	var ident := identifier.strip_edges()
	if not Ark.slug_fits(slug) or ident.is_empty():
		last_error = "Name the shelf and the item."
		return false
	if not await is_kindled():
		last_error = "This chain has not been kindled."
		return false
	var id := Ark.member_id(slug, ident)
	if Ark.row_has_id(await kind_rows(), id):
		return true
	return await _write(Ark.KINDS_TABLE, Ark.kind_member_row(slug, title, ident))


## Append a featured or done mark. A duplicate id retries with the clock moved.
## `note` is the Archive item count when a collection is featured.
func write_mark(slug: String, title: String, state: String, note: String = "") -> bool:
	last_error = ""
	if state != "featured" and state != "done":
		last_error = "A mark is featured or done."
		return false
	if not Ark.slug_fits(slug):
		last_error = "That name cannot be a shelf."
		return false
	if not await is_kindled():
		last_error = "This chain has not been kindled."
		return false
	var rows: Array = await kind_rows()
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	for _attempt in 4:
		var row := Ark.mark_row(slug, title, ms, state, note)
		if not Ark.row_has_id(rows, str(row.get("id", ""))):
			return await _write(Ark.KINDS_TABLE, row)
		ms += 1
	last_error = "Could not choose a mark id."
	return false


func published() -> void:
	await _settle()


## File rows of one item, oldest index first. Each record carries the chain
## sha256 so a read-back can refuse a mismatched reassembly.
func file_list(identifier: String, progress: Callable = Callable()) -> Array:
	last_error = ""
	var table := Ark.table_name(identifier)
	var rows: Array = await space.read_rows(table, 5000, [], progress)
	var finished := {}
	for name in Ark.complete_file_names(rows):
		finished[name] = true
	var out: Array = []
	var seen := {}
	for row in rows:
		if not row is Dictionary:
			continue
		if str(row.get("role", "")) != "file":
			continue
		var name := str(row.get("name", ""))
		if name.is_empty() or seen.has(name):
			continue
		seen[name] = true
		var parsed: Variant = JSON.parse_string(str(row.get("data", "")))
		var header: Dictionary = parsed if parsed is Dictionary else {}
		out.append({
			"name": name,
			"size": str(row.get("bytes", "0")),
			"format": str(row.get("format", "")),
			"sha256": str(row.get("sha256", "")).to_lower(),
			"md5": str(header.get("md5", "")),
			"sha1": str(header.get("sha1", "")),
			"source": str(header.get("source", "original")),
			"mtime": str(header.get("mtime", "")),
			"index": _file_index(str(row.get("id", ""))),
			"aboard": bool(finished.get(name, false)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("index", 0)) < int(b.get("index", 0))
	)
	if out.is_empty():
		last_error = "No files aboard for %s." % identifier
	return out


## File names on this item whose blob parts are all present.
func aboard_names(identifier: String, progress: Callable = Callable()) -> PackedStringArray:
	last_error = ""
	var problem: Array = []
	var rows: Array = await space.read_rows(Ark.table_name(identifier), 5000, problem, progress)
	if rows.is_empty() and not problem.is_empty():
		last_error = str(problem[0])
	return Ark.complete_file_names(rows)


## Write every blob part of `filename` to `dest`, in order. The file stays
## only when its sha256 matches the file row. A gap or a mismatch deletes it.
func reassemble(
	identifier: String,
	filename: String,
	dest: String,
	progress: Callable = Callable()
) -> Dictionary:
	last_error = ""
	var table := Ark.table_name(identifier)
	var rows: Array = await space.read_rows(table, 5000, [], progress)
	var header := {}
	var blobs := {}
	for row in rows:
		if not row is Dictionary:
			continue
		var id := str(row.get("id", ""))
		if str(row.get("role", "")) == "file" and str(row.get("name", "")) == filename and header.is_empty():
			header = row
		elif str(row.get("role", "")) == "blob" and not blobs.has(id):
			blobs[id] = row
	if header.is_empty():
		last_error = "That file is not aboard."
		return {"ok": false}
	var index := _file_index(str(header.get("id", "")))
	var parts := int(str(header.get("parts", "0")))
	var expect := str(header.get("sha256", "")).strip_edges().to_lower()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest.get_base_dir()))
	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		last_error = "Could not write the read-back."
		return {"ok": false}
	for part in parts:
		var id := Ark.blob_id(index, part)
		if not blobs.has(id):
			out.close()
			_drop(dest)
			last_error = "Part %d of %s is missing." % [part + 1, filename]
			return {"ok": false}
		var blob: Dictionary = blobs[id]
		var raw := Marshalls.base64_to_raw(str(blob.get("data", "")))
		var claimed := int(str(blob.get("bytes", "0")))
		if raw.size() != claimed:
			out.close()
			_drop(dest)
			last_error = "Part %d of %s is not the recorded length." % [part + 1, filename]
			return {"ok": false}
		out.store_buffer(raw)
	out.close()
	var sha := Ark.sha256_file(dest)
	if expect.is_empty() or sha != expect:
		_drop(dest)
		last_error = "The chain bytes do not match the recorded sha256."
		return {"ok": false}
	return {"ok": true, "sha": sha, "path": dest}


## Append a manifest row for every item table that has a card and no list row.
## Reserved names, including their hex seeds, are skipped. Returns how many
## rows were written, or -1 when the chain is not kindled or a write fails.
func repair() -> int:
	last_error = ""
	if not await is_kindled():
		last_error = "This chain has not been kindled."
		return -1
	var names: PackedStringArray = await space.table_names()
	var known := {}
	for row in await manifest_rows():
		if not row is Dictionary:
			continue
		var ident := str(row.get("identifier", "")).strip_edges()
		if ident.is_empty():
			ident = str(row.get("id", "")).strip_edges()
		if not ident.is_empty():
			known[ident] = true
		var table := str(row.get("table", "")).strip_edges()
		if not table.is_empty():
			known[table] = true
	var added := 0
	for name in names:
		if Ark.is_reserved_table(name) or not Ark.is_item_table(name) or known.has(name):
			continue
		var rows: Array = await space.read_rows(name, 5000)
		var meta := {}
		var raw_total := 0
		for row in rows:
			if not row is Dictionary:
				continue
			if str(row.get("id", "")) == Ark.META_ID and meta.is_empty():
				meta = row
			elif str(row.get("role", "")) == "file":
				raw_total += int(str(row.get("bytes", "0")))
		if meta.is_empty():
			continue
		var item := Ark.item_from_card(meta)
		var ident := str(item.get("identifier", "")).strip_edges()
		if ident.is_empty() or known.has(ident):
			continue
		if not await _write(Ark.MANIFEST_TABLE, Ark.manifest_row(item, raw_total)):
			return -1
		known[name] = true
		known[ident] = true
		added += 1
	return added


## `files` are Archive file records. `paths` maps each file name to a local
## path. `status` receives a short sentence. `progress` receives 0-100 across
## the chain writes. Returns false with last_error set.
func inscribe(
	item: Dictionary,
	files: Array,
	paths: Dictionary,
	status: Callable = Callable(),
	kinds: Array = [],
	progress: Callable = Callable()
) -> bool:
	last_error = ""
	var identifier := str(item.get("identifier", "")).strip_edges()
	if identifier.is_empty():
		last_error = "This item has no identifier."
		return false
	if files.is_empty():
		last_error = "Nothing selected."
		return false

	var prepared: Array = []
	var raw_total := 0
	for file in files:
		if not file is Dictionary:
			last_error = "A staged file was not a record."
			return false
		var name := str((file as Dictionary).get("name", ""))
		var path := str(paths.get(name, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			last_error = "Missing a cached copy of %s." % name
			return false
		_say(status, "Hashing %s" % name)
		var handle := FileAccess.open(path, FileAccess.READ)
		if handle == null:
			last_error = "Could not read %s." % name
			return false
		var length := handle.get_length()
		handle.close()
		prepared.append({
			"file": file,
			"name": name,
			"path": path,
			"length": length,
			"sha": Ark.sha256_file(path),
		})
		raw_total += length

	if not await is_kindled():
		last_error = "This chain has not been kindled."
		return false

	var table := Ark.table_name(identifier)
	_say(status, "Reading what is already aboard.")
	var creating: bool = not await space.table_exists(table)
	if creating:
		_say(status, "Opening a table anyone can continue.")
		var created: Variant = await _create(table, PackedStringArray(Ark.ITEM_COLUMNS), Callable())
		if created == null:
			return false
		await _settle()
		if not await space.table_exists(table):
			last_error = "Table was not visible on-chain after createTable."
			return false

	var have := {}
	var by_name := {}
	var max_index := -1
	if not creating:
		# One page. Past 5000 rows an EVM read cannot ask for the rest.
		var existing: Array = await space.read_rows(table, 5000)
		for row in existing:
			if not row is Dictionary:
				continue
			var id := str((row as Dictionary).get("id", ""))
			have[id] = true
			var index := _file_index(id)
			if index < 0:
				continue
			max_index = maxi(max_index, index)
			var named := str((row as Dictionary).get("name", ""))
			if not named.is_empty() and not by_name.has(named):
				by_name[named] = index

	var ops: Array = []
	if not bool(have.get(Ark.META_ID, false)):
		ops.append({
			"op": "row",
			"table": table,
			"row": Ark.card_row(item),
			"note": "Writing the card for %s" % identifier,
		})
		have[Ark.META_ID] = true

	for entry in prepared:
		var name := str(entry["name"])
		var length := int(entry["length"])
		var parts := Ark.part_count(length)
		var index := int(by_name[name]) if by_name.has(name) else max_index + 1
		if not by_name.has(name):
			max_index = index
			by_name[name] = index
		var file_id := Ark.file_id(index)
		if not bool(have.get(file_id, false)):
			var recorded: Dictionary = (entry["file"] as Dictionary).duplicate()
			recorded["size"] = str(length)
			ops.append({
				"op": "row",
				"table": table,
				"row": Ark.file_row(identifier, index, recorded, str(entry["sha"]), parts),
				"note": "Writing %s" % name,
			})
			have[file_id] = true
		var missing: Array = Ark.missing_parts(index, parts, have)
		for part in missing:
			var payload := _part_b64(str(entry["path"]), int(part), length)
			if payload.is_empty() and Ark.part_raw(length, int(part)) > 0:
				last_error = "Could not read part %d of %s." % [int(part), name]
				return false
			ops.append({
				"op": "row",
				"table": table,
				"row": Ark.blob_row(
					index,
					int(part),
					parts,
					str(entry["sha"]),
					Ark.part_raw(length, int(part)),
					payload
				),
				"note": "Writing %s  part %d of %d" % [name, int(part) + 1, parts],
			})
			have[Ark.blob_id(index, int(part))] = true
	ops.append({"op": "manifest"})
	for kind in kinds:
		if not kind is Dictionary:
			continue
		if str(kind.get("slug", "")).strip_edges().is_empty():
			continue
		ops.append({"op": "kind", "kind": kind})

	# A lambda copies an int. The dictionary is shared, so each finished write
	# moves the fraction instead of leaving it on the first step.
	var pace := {"done": 1 if creating else 0}
	var total := ops.size() + int(pace["done"])
	var pulse := func(local: float) -> void:
		if not progress.is_valid() or total <= 0:
			return
		var blended := (float(pace["done"]) + local / 100.0) / float(total) * 100.0
		progress.call(clampf(blended, 0.0, 100.0))
	pulse.call(0.0)

	for op in ops:
		var op_name := str(op.get("op", ""))
		var note := str(op.get("note", ""))
		if not note.is_empty():
			_say(status, note)
		var on_part := func(p: Variant) -> void:
			pulse.call(float(p))
		if op_name == "row":
			var record: Dictionary = op.get("row", {})
			if not await _write(str(op.get("table", "")), record, on_part):
				return false
		elif op_name == "manifest":
			_say(status, "Checking the manifest.")
			var on_chain := await _manifest_has(identifier, on_part)
			if not on_chain:
				_say(status, "Adding %s to the manifest." % identifier)
				if not await _write(Ark.MANIFEST_TABLE, Ark.manifest_row(item, raw_total), on_part):
					return false
		elif op_name == "kind":
			var shelf: Dictionary = op.get("kind", {})
			var slug := str(shelf.get("slug", "")).strip_edges()
			var title := str(shelf.get("title", slug))
			_say(status, "Filing %s on %s." % [identifier, title])
			if not await add_member(slug, title, identifier):
				return false
		pace["done"] = int(pace["done"]) + 1
		pulse.call(0.0)

	_say(status, "Aboard: %s" % identifier)
	if progress.is_valid():
		progress.call(100.0)
	return true


func _create(name: String, columns: PackedStringArray, progress: Callable) -> Variant:
	var created: Variant = await space.create_table(name, columns, Ark.ID_COLUMN, PackedStringArray(), progress)
	if created != null:
		return created
	var chain := ""
	if space is IQSpace:
		chain = (space as IQSpace).chain
	if not (space is IQSpace) or IQSpace.is_evm(chain) or not _missing_root(str(space.last_error)):
		last_error = str(space.last_error)
		return null
	await _settle()
	created = await space.create_table(name, columns, Ark.ID_COLUMN, PackedStringArray(), progress)
	if created == null:
		last_error = str(space.last_error)
	return created


func _write(name: String, row: Dictionary, progress: Callable = Callable()) -> bool:
	var wrote: Variant = await space.write_row(name, row, progress)
	if wrote == null:
		last_error = str(space.last_error)
		return false
	return true


func _manifest_has(identifier: String, progress: Callable = Callable()) -> bool:
	var rows: Array = await space.read_rows(Ark.MANIFEST_TABLE, 2000, [], progress)
	for row in rows:
		if not row is Dictionary:
			continue
		if str((row as Dictionary).get("id", "")) == identifier:
			return true
		if str((row as Dictionary).get("identifier", "")) == identifier:
			return true
	return false


func _part_b64(path: String, part: int, length: int) -> String:
	var count := Ark.part_raw(length, part)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	file.seek(part * Ark.PART_RAW_BYTES)
	var raw := file.get_buffer(count)
	file.close()
	if raw.size() != count:
		return ""
	return Marshalls.raw_to_base64(raw)


func _drop(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _settle() -> void:
	if not (space is IQSpace):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(_SETTLE_SEC).timeout


func _file_index(id: String) -> int:
	if not id.begins_with("f:"):
		return -1
	var tail := id.substr(2)
	if not tail.is_valid_int():
		return -1
	return int(tail)


func _missing_root(message: String) -> bool:
	var lower := message.to_lower()
	return lower.find("db_root not found") >= 0 or lower.find("dbroot not found") >= 0


func _say(status: Callable, text: String) -> void:
	if status.is_valid():
		status.call(text)
