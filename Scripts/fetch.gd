## Streams an Archive download to disk. Follows a few redirects, and can
## resume with a Range header when the destination already has a prefix.

class_name Fetch
extends Node

signal progressed(received: int)

var last_error := ""
var _job := 0


## Drops the download in progress. The call that is waiting returns false.
func cancel() -> void:
	_job += 1


func download(url: String, dest: String) -> bool:
	last_error = ""
	var job := _job
	# A cancelled call closes its file on the next frame. Wait, so this one
	# does not reopen that path while the other handle is still up.
	await get_tree().process_frame
	if job != _job:
		last_error = "Cancelled."
		return false
	var current := url
	for _hop in 5:
		if job != _job:
			last_error = "Cancelled."
			return false
		var part := _split(current)
		if part.is_empty():
			last_error = "Bad URL."
			return false
		var http := HTTPClient.new()
		var tls := TLSOptions.client()
		var err := http.connect_to_host(str(part["host"]), int(part["port"]), tls)
		if err != OK or job != _job:
			last_error = "Cancelled." if job != _job else "Could not connect."
			http.close()
			return false
		if not await _until(http, HTTPClient.STATUS_CONNECTED, job):
			last_error = "Cancelled." if job != _job else "Connection stalled."
			http.close()
			return false
		var have := 0
		if FileAccess.file_exists(dest):
			var existing := FileAccess.open(dest, FileAccess.READ)
			if existing != null:
				have = existing.get_length()
				existing.close()
		var headers := PackedStringArray(["User-Agent: %s" % Archive.USER_AGENT])
		if have > 0:
			headers.append("Range: bytes=%d-" % have)
		err = http.request(HTTPClient.METHOD_GET, str(part["path"]), headers)
		if err != OK:
			last_error = "Request failed."
			http.close()
			return false
		if not await _until(http, HTTPClient.STATUS_BODY, job):
			last_error = "Cancelled." if job != _job else "No response."
			http.close()
			return false
		var code := http.get_response_code()
		if code == 301 or code == 302 or code == 303 or code == 307 or code == 308:
			var location := _header(http.get_response_headers(), "location")
			http.close()
			if location.is_empty():
				last_error = "Redirect with no location."
				return false
			current = _resolve(current, location)
			continue
		if code != 200 and code != 206:
			last_error = "HTTP %d" % code
			http.close()
			return false
		var mode := FileAccess.WRITE_READ if code == 206 and have > 0 else FileAccess.WRITE
		var out := FileAccess.open(dest, mode)
		if out == null:
			last_error = "Could not write the file."
			http.close()
			return false
		if code == 206:
			out.seek_end()
		var received := have if code == 206 else 0
		var last_byte := Time.get_ticks_msec()
		while http.get_status() == HTTPClient.STATUS_BODY:
			if job != _job:
				out.close()
				http.close()
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
				last_error = "Cancelled."
				return false
			http.poll()
			var chunk := http.read_response_body_chunk()
			if chunk.is_empty():
				if Time.get_ticks_msec() - last_byte > 20000:
					break
				await get_tree().process_frame
				continue
			out.store_buffer(chunk)
			received += chunk.size()
			last_byte = Time.get_ticks_msec()
			progressed.emit(received)
		out.close()
		http.close()
		if received <= 0:
			last_error = "Empty download."
			return false
		return true
	last_error = "Too many redirects."
	return false


func _until(http: HTTPClient, want: int, job: int) -> bool:
	var started := Time.get_ticks_msec()
	while true:
		if job != _job:
			return false
		http.poll()
		var status := http.get_status()
		if status == want:
			return true
		if (
			status == HTTPClient.STATUS_CONNECTION_ERROR
			or status == HTTPClient.STATUS_CANT_CONNECT
			or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR
			or status == HTTPClient.STATUS_DISCONNECTED
		):
			return false
		if Time.get_ticks_msec() - started > 30000:
			return false
		await get_tree().process_frame
	return false


func _header(headers: PackedStringArray, name: String) -> String:
	var prefix := name.to_lower() + ":"
	for header in headers:
		if header.to_lower().begins_with(prefix):
			return header.substr(prefix.length()).strip_edges()
	return ""


func _resolve(base: String, location: String) -> String:
	if location.begins_with("https://") or location.begins_with("http://"):
		return location
	var part := _split(base)
	if location.begins_with("/"):
		return "https://%s%s" % [part["host"], location]
	return base.get_base_dir() + "/" + location


func _split(url: String) -> Dictionary:
	var rest := url
	if rest.begins_with("https://"):
		rest = rest.trim_prefix("https://")
	elif rest.begins_with("http://"):
		rest = rest.trim_prefix("http://")
	else:
		return {}
	var slash := rest.find("/")
	if slash < 1:
		return {}
	var host := rest.substr(0, slash)
	var path := rest.substr(slash)
	var port := 443
	var colon := host.find(":")
	if colon > 0:
		port = int(host.substr(colon + 1))
		host = host.substr(0, colon)
	return {"host": host, "port": port, "path": path}
