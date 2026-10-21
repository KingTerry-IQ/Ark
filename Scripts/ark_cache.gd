## One content-addressed cache for OPEN and for aboard read-back.
## Clearing it removes local files. It never writes a chain row.

class_name ArkCache
extends RefCounted

const INDEX_NAME := "index.bin"

var root := "user://cache"
var _index: Dictionary = {}


func _init(cache_root: String = "user://cache") -> void:
	root = cache_root
	_load()


func total_bytes() -> int:
	var total := 0
	for sha in _index:
		var row: Dictionary = _index[sha]
		if FileAccess.file_exists(str(row.get("path", ""))):
			total += int(row.get("bytes", 0))
	return total


func has_sha(sha: String) -> bool:
	if not _index.has(sha):
		return false
	return FileAccess.file_exists(str((_index[sha] as Dictionary).get("path", "")))


func path_of(sha: String) -> String:
	if not _index.has(sha):
		return ""
	return str((_index[sha] as Dictionary).get("path", ""))


func absolute_of(sha: String) -> String:
	var path := path_of(sha)
	if path.is_empty():
		return ""
	return ProjectSettings.globalize_path(path)


func sha_for(identifier: String, filename: String) -> String:
	for sha in _index:
		var row: Dictionary = _index[sha]
		if str(row.get("identifier", "")) != identifier:
			continue
		if str(row.get("filename", "")) != filename:
			continue
		if FileAccess.file_exists(str(row.get("path", ""))):
			return str(sha)
	return ""


func remember_path(
	sha: String,
	filename: String,
	identifier: String,
	source: String,
	dir_sha: String = ""
) -> String:
	var folder := dir_sha if not dir_sha.is_empty() else sha
	var dir := root.path_join(folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dir.path_join(_safe_name(filename))
	var incoming := FileAccess.open(source, FileAccess.READ)
	var outgoing := FileAccess.open(path, FileAccess.WRITE)
	if incoming == null or outgoing == null:
		if incoming != null:
			incoming.close()
		if outgoing != null:
			outgoing.close()
		return ""
	var total := 0
	while not incoming.eof_reached():
		var chunk := incoming.get_buffer(1024 * 1024)
		if chunk.is_empty():
			break
		outgoing.store_buffer(chunk)
		total += chunk.size()
	incoming.close()
	outgoing.close()
	_index[sha] = {
		"sha256": sha,
		"filename": filename,
		"path": path,
		"bytes": total,
		"identifier": identifier,
		"opened": Time.get_unix_time_from_system(),
		"dir": folder,
	}
	_save()
	return path


func files_for(identifier: String) -> Array:
	var out: Array = []
	for sha in _index:
		var row: Dictionary = _index[sha]
		if str(row.get("identifier", "")) == identifier:
			out.append(row)
	return out


## Store `data` as `filename` inside the directory of `dir_sha`. Sidecars
## pass the video's sha so they sit beside the video. The index key stays
## the file's own sha.
func remember(
	sha: String,
	filename: String,
	identifier: String,
	data: PackedByteArray,
	dir_sha: String = ""
) -> String:
	var folder := dir_sha if not dir_sha.is_empty() else sha
	var dir := root.path_join(folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dir.path_join(_safe_name(filename))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(data)
	file.close()
	_index[sha] = {
		"sha256": sha,
		"filename": filename,
		"path": path,
		"bytes": data.size(),
		"identifier": identifier,
		"opened": Time.get_unix_time_from_system(),
		"dir": folder,
	}
	_save()
	return path


func touch(sha: String) -> void:
	set_opened(sha, Time.get_unix_time_from_system())


func set_opened(sha: String, at: float) -> void:
	if not _index.has(sha):
		return
	(_index[sha] as Dictionary)["opened"] = at
	_save()


func clear_file(sha: String) -> void:
	if not _index.has(sha):
		return
	var row: Dictionary = _index[sha]
	var dir := str(row.get("dir", sha))
	var drop: Array = [sha]
	# Clearing the file that owns the directory also clears sidecars
	# stored beside it. Clearing a sidecar leaves the video in place.
	if dir == sha:
		for other in _index.keys():
			if str((_index[other] as Dictionary).get("dir", "")) == dir and not drop.has(other):
				drop.append(other)
	for gone in drop:
		_remove_path(str((_index[gone] as Dictionary).get("path", "")))
		_index.erase(gone)
	_remove_dir_if_empty(root.path_join(dir))
	_save()


func clear_item(identifier: String) -> void:
	var doomed: Array = []
	for sha in _index:
		if str((_index[sha] as Dictionary).get("identifier", "")) == identifier:
			doomed.append(sha)
	for sha in doomed:
		clear_file(str(sha))


func clear_all() -> void:
	for sha in _index.keys():
		_remove_path(str((_index[sha] as Dictionary).get("path", "")))
	_index = {}
	_wipe_dir(root)
	_save()


## Drop the least-recently opened entries until `total_bytes()` fits.
## `keep_sha` is the file just opened and is not evicted. A limit of 0
## turns eviction off.
func evict(limit: int, keep_sha: String = "") -> void:
	if limit <= 0:
		return
	while total_bytes() > limit:
		var oldest := ""
		var oldest_at := 1.0e30
		for sha in _index:
			if sha == keep_sha:
				continue
			var opened := float((_index[sha] as Dictionary).get("opened", 0))
			if opened < oldest_at:
				oldest_at = opened
				oldest = str(sha)
		if oldest.is_empty():
			return
		clear_file(oldest)


func _wipe_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var names: PackedStringArray = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for name in names:
		var child := path.path_join(name)
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(child)):
			_wipe_dir(child)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))


func _safe_name(filename: String) -> String:
	return Archive.local_name(filename)


func _remove_path(path: String) -> void:
	if path.is_empty():
		return
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs)


func _remove_dir_if_empty(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			return
		entry = dir.get_next()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))


func _load() -> void:
	var path := root.path_join(INDEX_NAME)
	if not FileAccess.file_exists(path):
		_index = {}
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_index = {}
		return
	var parsed: Variant = file.get_var()
	file.close()
	_index = parsed if parsed is Dictionary else {}


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var file := FileAccess.open(root.path_join(INDEX_NAME), FileAccess.WRITE)
	if file == null:
		return
	file.store_var(_index)
	file.close()
