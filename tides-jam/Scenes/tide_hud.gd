extends Control

@onready var strength_label: Label = $StrengthLabel

const MAX_STRENGTH := 110.0

var _angle := 0.0
var _strength := 0.0


func update_tide(vec: Vector2) -> void:
	_angle = vec.angle()
	_strength = vec.length()
	strength_label.text = "Tide: %d" % int(_strength)
	queue_redraw()


func _draw() -> void:
	# Background panel
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.12), false, 1.0)

	var center := Vector2(size.x * 0.5, 54.0)
	var fade := _strength / MAX_STRENGTH
	var col := Color(0.3, 0.88, 1.0, lerpf(0.25, 1.0, fade))

	# Outer ring — brightens with strength
	draw_arc(center, 38.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.05 + 0.15 * fade), 1.5)

	# "Tide" header text
	draw_string(
		ThemeDB.fallback_font,
		Vector2(size.x * 0.5 - 15.0, 13.0),
		"TIDE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(1.0, 1.0, 1.0, 0.5)
	)

	if _strength < 1.0:
		return

	var dir := Vector2.from_angle(_angle)
	var tip  := center + dir * 30.0
	var tail := center - dir * 16.0

	# Shaft
	draw_line(tail, tip, col, 3.0, true)

	# Arrowhead (135° back from tip on each side)
	draw_line(tip, tip + dir.rotated( 2.356) * 13.0, col, 3.0, true)
	draw_line(tip, tip + dir.rotated(-2.356) * 13.0, col, 3.0, true)
