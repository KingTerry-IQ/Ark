## Internet Archive reads: search URLs, metadata parsing, and which files
## are originals. Downloading lives next to a scene tree. This does not.

class_name Archive
extends RefCounted

const USER_AGENT := "Ark/0.1"
const SEARCH_URL := "https://archive.org/advancedsearch.php"
const SCRAPE_URL := "https://archive.org/services/search/v1/scrape"
const SCRAPE_COUNT := 100
const PAGE_ROWS := 20
## Sorted paging on archive.org stops at this many hits.
const RESULT_CAP := 10000

## The tiles on archive.org, in the order the site offers them, plus the
## collection and data types this app actually walks.
const MEDIATYPES: Array = [
	["", "All"],
	["texts", "Texts"],
	["movies", "Movies"],
	["audio", "Audio"],
	["software", "Software"],
	["image", "Images"],
	["collection", "Collections"],
	["data", "Data"],
]

const SORTS := {
	"relevance": "",
	"downloads": "downloads desc",
	"published": "date desc",
	"archived": "publicdate desc",
	"title": "titleSorter asc",
}

const _MEDIATYPE_LABELS := {
	"texts": "Texts",
	"movies": "Movies",
	"audio": "Audio",
	"software": "Software",
	"image": "Images",
	"collection": "Collection",
	"data": "Data",
	"etree": "Live music",
	"web": "Web",
}

const VIDEO_EXT := ["mp4", "m4v", "webm", "mkv", "mov", "avi", "ogv"]
const AUDIO_EXT := ["mp3", "ogg", "wav", "flac", "m4a", "aac"]
const IMAGE_EXT := ["jpg", "jpeg", "png", "gif", "webp"]
const TEXT_EXT := ["txt", "md", "json", "xml", "html", "vtt", "srt", "ass"]
const SUB_EXT := ["vtt", "srt", "ass"]


static func is_hidden_file(file: Dictionary) -> bool:
	var name := str(file.get("name", "")).strip_edges()
	var source := str(file.get("source", "")).strip_edges().to_lower()
	var format := str(file.get("format", "")).strip_edges().to_lower()
	var base := name.get_file().to_lower()
	if base == "__ia_thumb.jpg":
		return true
	if base.ends_with("_meta.xml") or base.ends_with("_files.xml"):
		return true
	if format == "metadata":
		return true
	if not source.is_empty() and source != "original":
		return true
	return false


static func originals(files: Array) -> Array:
	var out: Array = []
	for file in files:
		if file is Dictionary and not is_hidden_file(file):
			out.append(file)
	return out


static func original_names(files: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	for file in originals(files):
		var name := str(file.get("name", "")).strip_edges()
		if name.is_empty() or seen.has(name):
			continue
		seen[name] = true
		out.append(name)
	return out


## The Archive download list groups by format, then by folder, then by name.
static func file_section(file: Dictionary) -> String:
	var format := str(file.get("format", "")).strip_edges()
	if not format.is_empty():
		return format
	var ext := str(file.get("name", "")).get_extension()
	if ext.is_empty():
		return "Files"
	return ext.to_upper()


static func file_folder(name: String) -> String:
	var slash := name.rfind("/")
	if slash <= 0:
		return ""
	return name.substr(0, slash)


## The download listing as folders, the way archive.org/download/ pages it.
## Keyed by folder path, "" is the item root. Each entry holds its child
## folder paths, the indices of the files directly in it, the indices of
## every file beneath it, and the bytes beneath it.
static func folder_index(files: Array) -> Dictionary:
	var index := {}
	_ensure_folder(index, "")
	for at in files.size():
		var file: Variant = files[at]
		if not file is Dictionary:
			continue
		var folder := file_folder(str(file.get("name", "")))
		_ensure_folder(index, folder)
		(index[folder]["files"] as Array).append(at)
		var bytes := Ark.file_bytes(file)
		var walk := folder
		while true:
			var entry: Dictionary = index[walk]
			(entry["all"] as Array).append(at)
			entry["bytes"] = int(entry["bytes"]) + bytes
			if walk.is_empty():
				break
			walk = file_folder(walk)
	for path in index:
		(index[path]["dirs"] as Array).sort_custom(func(a: String, b: String) -> bool:
			return a.nocasecmp_to(b) < 0
		)
	return index


static func _ensure_folder(index: Dictionary, path: String) -> void:
	if index.has(path):
		return
	index[path] = {"dirs": [], "files": [], "all": [], "bytes": 0}
	if path.is_empty():
		return
	var parent := file_folder(path)
	_ensure_folder(index, parent)
	(index[parent]["dirs"] as Array).append(path)


## A file's name as seen from inside a folder of the listing.
static func relative_to(name: String, folder: String) -> String:
	if folder.is_empty() or not name.begins_with(folder + "/"):
		return name
	return name.substr(folder.length() + 1)


static func arrange_files(files: Array) -> Array:
	var out: Array = []
	for file in files:
		if file is Dictionary:
			out.append(file)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var section_a := file_section(a)
		var section_b := file_section(b)
		if section_a != section_b:
			return section_a.nocasecmp_to(section_b) < 0
		var folder_a := file_folder(str(a.get("name", "")))
		var folder_b := file_folder(str(b.get("name", "")))
		if folder_a != folder_b:
			return folder_a.nocasecmp_to(folder_b) < 0
		return str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) < 0
	)
	return out


static func collections_of(metadata: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = metadata.get("collection", [])
	if raw is String:
		var one := str(raw).strip_edges()
		if not one.is_empty():
			out.append(one)
		return out
	if raw is Array:
		for entry in raw:
			var one := str(entry).strip_edges()
			if not one.is_empty():
				out.append(one)
	return out


static func parse_metadata(body: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body)
	if not parsed is Dictionary:
		return {}
	var doc: Dictionary = parsed
	var meta: Dictionary = doc.get("metadata", {})
	if not meta is Dictionary:
		meta = {}
	var files: Array = []
	var listed: Variant = doc.get("files", [])
	if listed is Array:
		files = listed
	return {
		"identifier": str(meta.get("identifier", "")),
		"title": str(meta.get("title", "")),
		"creator": str(meta.get("creator", "")),
		"date": str(meta.get("date", meta.get("year", ""))),
		"mediatype": str(meta.get("mediatype", "")),
		"description": str(meta.get("description", "")),
		"collections": collections_of(meta),
		"item_size": str(doc.get("item_size", meta.get("item_size", ""))),
		"files": files,
		"metadata_sha256": Ark.sha256_text(body),
	}


static func parse_search(body: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body)
	if not parsed is Dictionary:
		return {"num_found": 0, "docs": []}
	var response: Variant = (parsed as Dictionary).get("response", {})
	if not response is Dictionary:
		return {"num_found": 0, "docs": []}
	var docs: Array = []
	var listed: Variant = (response as Dictionary).get("docs", [])
	if listed is Array:
		docs = listed
	return {
		"num_found": int((response as Dictionary).get("numFound", docs.size())),
		"docs": docs,
	}


## One box, then the filters. An empty box with a mediatype is the tile
## the Archive offers. An empty everything is the front page, not a query.
static func search_query(text: String, mediatype: String = "", collection_id: String = "") -> String:
	var parts := PackedStringArray()
	var kind := mediatype.strip_edges()
	if not kind.is_empty():
		parts.append("mediatype:%s" % kind)
	var collection := collection_id.strip_edges()
	if not collection.is_empty():
		parts.append("collection:%s" % _lucene_term(collection))
	var q := text.strip_edges()
	if not q.is_empty():
		parts.append("(%s)" % q)
	return " AND ".join(parts)


static func member_query(collection_id: String) -> String:
	return search_query("", "", collection_id)


static func search_url(query: String, page: int = 1, rows: int = PAGE_ROWS, sort: String = "relevance") -> String:
	var url := (
		SEARCH_URL
		+ "?q=" + query.uri_encode()
		+ "&output=json&rows=%d&page=%d" % [maxi(rows, 1), maxi(page, 1)]
		+ "&fl[]=identifier&fl[]=title&fl[]=mediatype&fl[]=creator"
		+ "&fl[]=year&fl[]=date&fl[]=downloads&fl[]=description&fl[]=collection"
	)
	var key := sort if SORTS.has(sort) else "relevance"
	var value := str(SORTS[key])
	if not value.is_empty():
		url += "&sort[]=" + value.uri_encode()
	return url


## One page of a collection walk. Advanced search stops at 10,000; the scrape
## cursor is how a check continues past that.
static func scrape_url(query: String, cursor: String = "", count: int = SCRAPE_COUNT) -> String:
	var url := "%s?q=%s&fields=identifier&count=%d" % [
		SCRAPE_URL,
		query.uri_encode(),
		clampi(count, 1, 10000),
	]
	if not cursor.is_empty():
		url += "&cursor=" + cursor.uri_encode()
	return url


## `ok` is false when the body is not a scrape response. An empty cursor means
## the walk has reached the last page.
static func parse_scrape(body: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body)
	if not parsed is Dictionary:
		return {"ok": false, "items": PackedStringArray(), "cursor": "", "total": 0, "finished": false, "total_known": false}
	var doc: Dictionary = parsed
	var items := PackedStringArray()
	var listed: Variant = doc.get("items", [])
	if listed is Array:
		for entry in listed:
			if not entry is Dictionary:
				continue
			var ident := str(entry.get("identifier", "")).strip_edges()
			if not ident.is_empty():
				items.append(ident)
	var cursor_value: Variant = doc.get("cursor", null)
	var cursor := ""
	var finished := true
	if cursor_value != null:
		cursor = str(cursor_value).strip_edges()
		finished = cursor.is_empty()
	var total_known := doc.has("total")
	var total := items.size()
	if total_known:
		total = int(doc.get("total", items.size()))
	return {
		"ok": true,
		"items": items,
		"cursor": cursor,
		"total": total,
		"total_known": total_known,
		"finished": finished,
	}


static func thumb_url(identifier: String) -> String:
	return "https://archive.org/services/img/" + identifier.uri_encode()


## "jpg", "png", "webp", or "" from the file header.
## Godot's image loaders print an engine error whenever the bytes are the
## wrong format, even if the caller checks the return code. Callers must
## ask image_kind first and invoke only that loader.
static func image_kind(body: PackedByteArray) -> String:
	if body.size() >= 3 and body[0] == 0xFF and body[1] == 0xD8 and body[2] == 0xFF:
		return "jpg"
	if (
		body.size() >= 8
		and body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E and body[3] == 0x47
		and body[4] == 0x0D and body[5] == 0x0A and body[6] == 0x1A and body[7] == 0x0A
	):
		return "png"
	if (
		body.size() >= 12
		and body[0] == 0x52 and body[1] == 0x49 and body[2] == 0x46 and body[3] == 0x46
		and body[8] == 0x57 and body[9] == 0x45 and body[10] == 0x42 and body[11] == 0x50
	):
		return "webp"
	return ""


## Decode a thumbnail. A gif, an html error page, or any other header stays
## unloaded, so the hull placeholder remains and the console stays quiet.
static func decode_image(body: PackedByteArray, image: Image) -> bool:
	var err := ERR_FILE_UNRECOGNIZED
	match image_kind(body):
		"jpg":
			err = image.load_jpg_from_buffer(body)
		"png":
			err = image.load_png_from_buffer(body)
		"webp":
			err = image.load_webp_from_buffer(body)
		_:
			return false
	return err == OK


static func mediatype_label(kind: String) -> String:
	var key := kind.strip_edges().to_lower()
	if _MEDIATYPE_LABELS.has(key):
		return str(_MEDIATYPE_LABELS[key])
	return key


## A search document, flattened the way a result row needs it.
## Title and creator arrive as either a string or a list.
static func present_hit(doc: Dictionary) -> Dictionary:
	var identifier := _as_text(doc.get("identifier", ""))
	var title := _as_text(doc.get("title", ""))
	if title.is_empty():
		title = identifier
	return {
		"identifier": identifier,
		"title": title,
		"creator": _as_text(doc.get("creator", "")),
		"year": _year_of(doc),
		"mediatype": _as_text(doc.get("mediatype", "")).to_lower(),
		"downloads": int(str(doc.get("downloads", "0"))),
		"description": _clip(plain_text(_as_text(doc.get("description", ""))), 180),
		"collections": collections_of({"collection": doc.get("collection", [])}),
	}


static func byline(hit: Dictionary) -> String:
	var parts := PackedStringArray()
	var creator := str(hit.get("creator", "")).strip_edges()
	if not creator.is_empty():
		parts.append(creator)
	var year := str(hit.get("year", "")).strip_edges()
	if not year.is_empty():
		parts.append(year)
	var kind := mediatype_label(str(hit.get("mediatype", "")))
	if not kind.is_empty():
		parts.append(kind)
	var downloads := int(hit.get("downloads", 0))
	if downloads > 0:
		parts.append("%s downloads" % grouped(downloads))
	return " · ".join(parts)


static func page_window(page: int, rows: int, found: int) -> Dictionary:
	var safe_rows := maxi(rows, 1)
	if found <= 0:
		return {"page": 1, "pages": 0, "from": 0, "to": 0}
	var capped := mini(found, RESULT_CAP)
	var pages := int(ceili(float(capped) / float(safe_rows)))
	var safe := clampi(page, 1, pages)
	var start := (safe - 1) * safe_rows + 1
	return {
		"page": safe,
		"pages": pages,
		"from": start,
		"to": mini(safe * safe_rows, capped),
	}


static func result_count(window: Dictionary, found: int) -> String:
	if found <= 0:
		return "No results"
	var text := "%s–%s of %s" % [
		grouped(int(window.get("from", 0))),
		grouped(int(window.get("to", 0))),
		grouped(found),
	]
	if found > RESULT_CAP:
		text += "  ·  first %s can be paged" % grouped(RESULT_CAP)
	return text


static func grouped(n: int) -> String:
	var negative := n < 0
	var digits := str(absi(n))
	var parts: PackedStringArray = []
	while digits.length() > 3:
		parts.append(digits.substr(digits.length() - 3, 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.append(digits)
	parts.reverse()
	var text := ",".join(parts)
	return "-" + text if negative else text


static var _tags: RegEx
static var _gaps: RegEx


## Catalog blurbs are clipped to a couple of lines. A collection page can
## still hand back a whole essay per hit, so only the opening is read.
static func plain_text(raw: String) -> String:
	var text := raw.substr(0, 4000) if raw.length() > 4000 else raw
	if _tags == null:
		_tags = RegEx.new()
		_tags.compile("<[^>]+>")
		_gaps = RegEx.new()
		_gaps.compile("\\s+")
	if _tags != null and _tags.is_valid():
		text = _tags.sub(text, " ", true)
	text = text.replace("&nbsp;", " ")
	text = text.replace("&amp;", "&")
	text = text.replace("&lt;", "<")
	text = text.replace("&gt;", ">")
	text = text.replace("&quot;", "\"")
	text = text.replace("&#39;", "'")
	text = text.replace("&apos;", "'")
	if _gaps != null and _gaps.is_valid():
		text = _gaps.sub(text, " ", true)
	return text.strip_edges()


static func _as_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is Array:
		var parts := PackedStringArray()
		for entry in value:
			var one := str(entry).strip_edges()
			if not one.is_empty() and one != "<null>":
				parts.append(one)
		return ", ".join(parts)
	var text := str(value).strip_edges()
	return "" if text == "<null>" else text


static func _year_of(doc: Dictionary) -> String:
	var year := _as_text(doc.get("year", ""))
	if year.length() >= 4 and year.substr(0, 4).is_valid_int():
		return year.substr(0, 4)
	var date := _as_text(doc.get("date", ""))
	if date.length() >= 4 and date.substr(0, 4).is_valid_int():
		return date.substr(0, 4)
	return ""


static func _clip(text: String, limit: int) -> String:
	var clean := text.strip_edges()
	if clean.length() <= limit:
		return clean
	var cut := clean.substr(0, limit)
	var space := cut.rfind(" ")
	if space > limit * 2 / 3:
		cut = cut.substr(0, space)
	return cut.strip_edges() + "…"


static func _lucene_term(value: String) -> String:
	var plain := true
	for i in value.length():
		var c := value[i]
		var ok := (
			(c >= "a" and c <= "z")
			or (c >= "A" and c <= "Z")
			or (c >= "0" and c <= "9")
			or c == "_"
			or c == "-"
			or c == "."
		)
		if not ok:
			plain = false
			break
	if plain:
		return value
	return "\"%s\"" % value.replace("\"", "")


static func metadata_url(identifier: String) -> String:
	return "https://archive.org/metadata/" + identifier.uri_encode()


static func download_url(identifier: String, filename: String) -> String:
	var segments: PackedStringArray = []
	for part in filename.split("/"):
		segments.append(part.uri_encode())
	return "https://archive.org/download/%s/%s" % [identifier.uri_encode(), "/".join(segments)]


static func extension_of(filename: String) -> String:
	var base := filename.get_file().to_lower()
	var dot := base.rfind(".")
	if dot < 0:
		return ""
	return base.substr(dot + 1)


const _RESERVED_NAMES := [
	"CON", "PRN", "AUX", "NUL",
	"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
	"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
]
const LOCAL_NAME_MAX := 120


## An Archive file name as one this machine can write. Archive names carry
## characters Windows refuses (a mail timestamp's colons, a quote, a "?"),
## Windows device names, and lengths that blow past MAX_PATH once they sit
## in the cache. The extension survives, so players still know the file.
static func local_name(filename: String) -> String:
	var base := filename.get_file()
	var out := ""
	for i in base.length():
		var c := base[i]
		if c in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"] or base.unicode_at(i) < 32:
			out += "_"
		else:
			out += c
	out = out.strip_edges().rstrip(". ")
	if out.is_empty():
		return "file"
	var stem := out.get_slice(".", 0).to_upper()
	if stem in _RESERVED_NAMES:
		out = "_" + out
	if out.length() > LOCAL_NAME_MAX:
		var ext := extension_of(out)
		var keep := LOCAL_NAME_MAX - (ext.length() + 1 if not ext.is_empty() and ext.length() < 16 else 0)
		out = out.substr(0, keep).rstrip(". ")
		if not ext.is_empty() and ext.length() < 16:
			out += "." + ext
	return out


static func basename_of(filename: String) -> String:
	var base := filename.get_file()
	var dot := base.rfind(".")
	if dot < 0:
		return base
	return base.substr(0, dot)


## video, audio, image, text, pdf, or folder. Folder means the bytes are
## written and revealed, and nothing is asked to play them.
static func open_kind(filename: String) -> String:
	var ext := extension_of(filename)
	if ext in VIDEO_EXT:
		return "video"
	if ext in AUDIO_EXT:
		return "audio"
	if ext in IMAGE_EXT:
		return "image"
	if ext in TEXT_EXT:
		return "text"
	if ext == "pdf":
		return "pdf"
	return "folder"


static func subtitle_siblings(video_name: String, files: Array) -> Array:
	var stem := basename_of(video_name)
	var out: Array = []
	for file in files:
		if not file is Dictionary:
			continue
		var name := str(file.get("name", ""))
		if name == video_name:
			continue
		if basename_of(name).begins_with(stem) and extension_of(name) in SUB_EXT:
			out.append(file)
	return out


static func hashes_match(path: String, md5: String, sha1: String) -> bool:
	var want_sha := sha1.strip_edges().to_lower()
	var want_md5 := md5.strip_edges().to_lower()
	if want_sha.is_empty() and want_md5.is_empty():
		return true
	if not want_sha.is_empty() and Ark.sha1_file(path) != want_sha:
		return false
	if want_sha.is_empty() and Ark.md5_file(path) != want_md5:
		return false
	return true
