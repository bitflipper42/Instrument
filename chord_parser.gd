class_name ChordParser
extends RefCounted

## Parses chord symbol tokens (e.g. "C", "Am7", "F#dim") into MIDI note sets.

const DEFAULT_OCTAVE := 4

## Quality suffix -> semitone intervals from the chord root.
const QUALITY_INTERVALS: Dictionary = {
	"maj7": [0, 4, 7, 11],
	"min7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10],
	"dim7": [0, 3, 6, 9],
	"maj9": [0, 4, 7, 11, 14],
	"min9": [0, 3, 7, 10, 14],
	"sus4": [0, 5, 7],
	"sus2": [0, 2, 7],
	"add9": [0, 4, 7, 14],
	"aug": [0, 4, 8],
	"dim": [0, 3, 6],
	"min": [0, 3, 7],
	"maj": [0, 4, 7],
	"m9": [0, 3, 7, 10, 14],
	"m7": [0, 3, 7, 10],
	"M7": [0, 4, 7, 11],
	"-7": [0, 3, 7, 10],
	"°7": [0, 3, 6, 9],
	"13": [0, 4, 7, 10, 14, 21],
	"11": [0, 4, 7, 10, 14, 17],
	"ø": [0, 3, 6, 10],
	"+": [0, 4, 8],
	"°": [0, 3, 6],
	"9": [0, 4, 7, 10, 14],
	"7": [0, 4, 7, 10],
	"6": [0, 4, 7, 9],
	"m": [0, 3, 7],
	"M": [0, 4, 7],
	"-": [0, 3, 7],
	"5": [0, 7],
	"": [0, 4, 7],
}

static var _quality_keys: PackedStringArray = PackedStringArray()


## Splits `text` on whitespace into non-empty tokens (row order preserved).
static func tokenize(text: String) -> PackedStringArray:
	var tokens: PackedStringArray = []
	for line in text.split("\n"):
		for part in line.split(" ", false):
			var token := part.strip_edges()
			if not token.is_empty():
				tokens.append(token)
	return tokens


## Parses one chord token. Returns `{ "valid": bool, "tones": Array[int], "token": String }`.
static func parse(token: String) -> Dictionary:
	var cleaned := token.strip_edges()
	if cleaned.is_empty():
		return {"valid": false, "tones": [], "token": cleaned}
	var root := _parse_root(cleaned)
	if root.is_empty():
		return {"valid": false, "tones": [], "token": cleaned}
	var quality: String = root["quality"]
	var intervals: Array = _intervals_for_quality(quality)
	if intervals.is_empty():
		return {"valid": false, "tones": [], "token": cleaned}
	var pc := BasicInstrument.CHROMATIC.find(root["pitch"])
	if pc < 0:
		return {"valid": false, "tones": [], "token": cleaned}
	var base := (int(root["octave"]) + 1) * 12 + pc
	var tones: Array[int] = []
	for interval in intervals:
		var midi := base + int(interval)
		if midi < 0 or midi > 127:
			return {"valid": false, "tones": [], "token": cleaned}
		if not tones.has(midi):
			tones.append(midi)
	tones.sort()
	return {"valid": true, "tones": tones, "token": cleaned}


static func is_valid(token: String) -> bool:
	return parse(token)["valid"]


static func _parse_root(s: String) -> Dictionary:
	if s.is_empty():
		return {}
	var letter := s[0]
	if not ((letter >= "A" and letter <= "G") or (letter >= "a" and letter <= "g")):
		return {}
	var i := 1
	var acc := ""
	if i < s.length() and s[i] in "#b":
		acc = s[i]
		i += 1
	var pitch := s.substr(0, 1).to_upper() + acc
	if BasicInstrument.FLAT_ALIASES.has(pitch):
		pitch = BasicInstrument.FLAT_ALIASES[pitch]
	if not BasicInstrument.CHROMATIC.has(pitch):
		return {}
	var octave := DEFAULT_OCTAVE
	var oct_start := i
	while i < s.length() and s[i].is_valid_int():
		i += 1
	if i > oct_start:
		octave = int(s.substr(oct_start, i - oct_start))
	return {"pitch": pitch, "octave": octave, "quality": s.substr(i)}


static func _intervals_for_quality(quality: String) -> Array:
	if QUALITY_INTERVALS.has(quality):
		return QUALITY_INTERVALS[quality]
	if _quality_keys.is_empty():
		var keys: Array[String] = []
		for key in QUALITY_INTERVALS:
			keys.append(key)
		keys.sort_custom(func(a: String, b: String) -> bool:
			return a.length() > b.length())
		_quality_keys = PackedStringArray(keys)
	for key in _quality_keys:
		if quality == key:
			return QUALITY_INTERVALS[key]
	return []
