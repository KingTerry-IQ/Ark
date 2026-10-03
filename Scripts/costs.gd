## Protocol-fee estimates. The numbers match GodOnChain's IQCosts, which is
## what the host prints on the approval. Gas is excluded.
##
## Solana's approval quote chunks at 3400 bytes. The write path chunks at
## 850, so a Solana figure here runs low. The stage says so. Changing the
## quote to the 850-byte size would disagree with the approval.

class_name Costs
extends RefCounted

const SOL_CHUNK_BYTES := 3400
const SOL_INITIAL_TX := 0.0001
const SOL_PER_CHUNK := 0.000005
const SOL_FINAL_TX := 0.005005
const SOL_TABLE_RENT := 0.015585

const MON_CHUNK_BYTES := 131072
const MON_PER_CHUNK := 0.415971708
const MON_BASIC_FEE := 6.5
const MON_FINAL_TX := 19.5
const MON_TABLE_FEE := MON_FINAL_TX

const RH_INLINE_LIMIT := 700
const RH_CHUNK_BYTES := 98304
const RH_PER_CHUNK := 0.000036029400056
const RH_BASIC_FEE := 0.00012
const RH_LINKED_FEE := 0.00036
const RH_TABLE_FEE := RH_LINKED_FEE


static func is_monad(chain: String) -> bool:
	return chain.strip_edges().to_lower().begins_with("mon")


static func is_robinhood(chain: String) -> bool:
	var c := chain.strip_edges().to_lower()
	return c == "rh" or c == "rhc" or c == "robinhood" or c == "robinhood-chain"


static func code(chain: String) -> String:
	if is_robinhood(chain):
		return "rh"
	if is_monad(chain):
		return "mon"
	return "sol"


static func token(chain: String) -> String:
	if is_robinhood(chain):
		return "ETH"
	if is_monad(chain):
		return "MON"
	return "SOL"


static func is_create_table(action: String) -> bool:
	return action.strip_edges().to_lower() == "createtable"


static func estimate(chain: String, bytes: int, action: String = "") -> float:
	if is_create_table(action):
		if is_robinhood(chain):
			return RH_TABLE_FEE
		if is_monad(chain):
			return MON_TABLE_FEE
		return SOL_TABLE_RENT

	var payload: int = maxi(bytes, 0)

	if is_robinhood(chain):
		if payload <= RH_INLINE_LIMIT:
			return RH_BASIC_FEE
		@warning_ignore("integer_division")
		var rh_batches: int = (payload + RH_CHUNK_BYTES - 1) / RH_CHUNK_BYTES
		return RH_LINKED_FEE + RH_PER_CHUNK * maxi(rh_batches, 1)

	if is_monad(chain):
		if payload <= RH_INLINE_LIMIT:
			return MON_BASIC_FEE
		@warning_ignore("integer_division")
		var mon_chunks: int = (payload + MON_CHUNK_BYTES - 1) / MON_CHUNK_BYTES
		return MON_FINAL_TX + mon_chunks * MON_PER_CHUNK

	@warning_ignore("integer_division")
	var sol_chunks: int = (payload + SOL_CHUNK_BYTES - 1) / SOL_CHUNK_BYTES
	return SOL_INITIAL_TX + sol_chunks * SOL_PER_CHUNK + SOL_FINAL_TX


static func amount(chain: String, tokens: float) -> String:
	if is_robinhood(chain):
		return "~%.5f ETH" % tokens
	if is_monad(chain):
		return "~%.4f MON" % tokens
	return "~%.6f SOL" % tokens


static func format(chain: String, bytes: int, action: String = "") -> String:
	return amount(chain, estimate(chain, bytes, action))


static func base64_bytes(raw: int) -> int:
	return ((maxi(raw, 0) + 2) / 3) * 4


static func row_bytes(row: Dictionary) -> int:
	return JSON.stringify(row).to_utf8_buffer().size()


## JSON size of a blob row whose `data` is the base64 of `raw` original bytes.
## Base64 uses no JSON escapes, so the empty-row length plus the alphabet
## length is the payload the host will bill.
static func blob_payload_bytes(raw: int) -> int:
	var empty := Ark.blob_row(0, 0, 1, "", raw, "")
	return row_bytes(empty) + base64_bytes(raw)


## spec keys: create_table, meta_row, file_rows, blob_raws, manifest_row,
## kind_member_rows. Row values are the dictionaries that will be written.
static func quote_item(chain: String, spec: Dictionary) -> float:
	var total := 0.0
	if bool(spec.get("create_table", false)):
		total += estimate(chain, 0, "createTable")
	var meta: Variant = spec.get("meta_row")
	if meta is Dictionary:
		total += estimate(chain, row_bytes(meta))
	var files: Variant = spec.get("file_rows", [])
	if files is Array:
		for row in files:
			if row is Dictionary:
				total += estimate(chain, row_bytes(row))
	var blobs: Variant = spec.get("blob_raws", [])
	if blobs is Array:
		for raw in blobs:
			total += estimate(chain, blob_payload_bytes(int(raw)))
	var manifest: Variant = spec.get("manifest_row")
	if manifest is Dictionary:
		total += estimate(chain, row_bytes(manifest))
	var members: Variant = spec.get("kind_member_rows", [])
	if members is Array:
		for row in members:
			if row is Dictionary:
				total += estimate(chain, row_bytes(row))
	return total


static func quote_batch(chain: String, specs: Array) -> float:
	var total := 0.0
	for spec in specs:
		if spec is Dictionary:
			total += quote_item(chain, spec)
	return total
