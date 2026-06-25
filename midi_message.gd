class_name MidiMessage
extends RefCounted

## A minimal MIDI-style note message. Carries the message type, channel, note
## number and velocity so instruments can exchange note-on / note-off events.

const NOTE_OFF := 0x80
const NOTE_ON := 0x90

## Message type: NOTE_ON (0x90) or NOTE_OFF (0x80).
var type: int = NOTE_ON
## MIDI channel (0-15).
var channel: int = 0
## MIDI note number (0-127).
var note: int = 0
## Velocity (0-127). For note-on this is attack; for note-off, release.
var velocity: int = 0


func _init(p_type: int = NOTE_ON, p_note: int = 0, p_velocity: int = 0, p_channel: int = 0) -> void:
	type = p_type
	note = p_note
	velocity = p_velocity
	channel = p_channel


## Builds a note-on message.
static func note_on(p_note: int, p_velocity: int = 100, p_channel: int = 0) -> MidiMessage:
	return MidiMessage.new(NOTE_ON, p_note, p_velocity, p_channel)


## Builds a note-off message.
static func note_off(p_note: int, p_velocity: int = 0, p_channel: int = 0) -> MidiMessage:
	return MidiMessage.new(NOTE_OFF, p_note, p_velocity, p_channel)


## The combined status byte (type nibble OR channel).
func status() -> int:
	return (type & 0xF0) | (channel & 0x0F)


## True for a real note-on. A note-on with velocity 0 counts as note-off (per MIDI).
func is_note_on() -> bool:
	return type == NOTE_ON and velocity > 0


## True for a note-off (explicit, or a velocity-0 note-on).
func is_note_off() -> bool:
	return type == NOTE_OFF or (type == NOTE_ON and velocity == 0)
