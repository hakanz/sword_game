extends TestCase
## Localization source integrity (charter §29): every key must have a
## non-empty English AND Turkish cell — missing cells fall back silently at
## runtime, so we catch them here instead.

const CSV_PATH: String = "res://localization/strings.csv"


func test_every_key_has_en_and_tr() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_true(file != null, "cannot open %s" % CSV_PATH)
	if file == null:
		return

	var header: PackedStringArray = file.get_csv_line()
	assert_eq(header[0], "keys", "first CSV column must be 'keys'")
	assert_true(header.has("en") and header.has("tr"), "CSV must define en and tr columns")
	var en_index: int = header.find("en")
	var tr_index: int = header.find("tr")

	var seen_keys: Dictionary = {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0].strip_edges() == ""):
			continue
		var key: String = row[0]
		assert_false(seen_keys.has(key), "duplicate localization key: %s" % key)
		seen_keys[key] = true
		assert_true(row.size() > tr_index and row[en_index].strip_edges() != "",
				"key '%s' missing English text" % key)
		assert_true(row.size() > tr_index and row[tr_index].strip_edges() != "",
				"key '%s' missing Turkish text" % key)
	assert_true(seen_keys.size() >= 30, "suspiciously few localization keys parsed")
