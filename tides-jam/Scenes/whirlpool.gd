extends Area2D

## Pull force applied while swinging the boat toward the center
@export var pull_strength  := 380.0
## Spin torque during the pull phase
@export var spin_strength  := 60.0
## Distance from center that triggers the catch
@export var capture_radius := 22.0
## Seconds the boat is frozen at center before being flung (the "snap" moment)
@export var hold_time      := 0.08
## Minimum exit speed — actual speed will match incoming speed if faster
@export var min_exit_speed := 420.0
## Cargo health lost when caught (0–1)
@export var capture_damage := 0.25

enum Phase { IDLE, PULLING, HOLDING }

var _phase       := Phase.IDLE
var _hold_timer  := 0.0
var _eject_dir   := Vector2.ZERO
var _exit_speed  := 0.0
var _boat        : RigidBody2D = null
var _cooldown    := 0.0   # prevents immediate re-capture after ejection


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boat") and _phase == Phase.IDLE and _cooldown <= 0.0:
		_boat = body as RigidBody2D
		_phase = Phase.PULLING


func _on_body_exited(body: Node2D) -> void:
	# Boat rowed out before being caught — release it
	if body == _boat and _phase == Phase.PULLING:
		_reset()


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	if _boat == null:
		return

	var to_center := global_position - _boat.global_position

	match _phase:
		Phase.PULLING:
			# Swing the boat toward the center
			_boat.apply_central_force(to_center.normalized() * pull_strength)
			_boat.apply_torque(spin_strength)
			if to_center.length() < capture_radius:
				# Caught — damage cargo
				if _boat.has_cargo:
					_boat.cargo_health = maxf(0.0, _boat.cargo_health - capture_damage)
				# Preserve incoming speed (floored), swing direction ~180° from entry
				_exit_speed = maxf(_boat.linear_velocity.length(), min_exit_speed)
				var entry_dir := _boat.linear_velocity.normalized()
				var swing := PI + randf_range(-PI * 0.3, PI * 0.3)  # 126–234°
				_eject_dir  = entry_dir.rotated(swing)
				_hold_timer = hold_time
				_phase      = Phase.HOLDING

		Phase.HOLDING:
			# Dead stop — crisp "snap" at center before the fling
			_boat.linear_velocity  = Vector2.ZERO
			_boat.angular_velocity = 0.0
			_hold_timer -= delta
			if _hold_timer <= 0.0:
				# Send boat off at its captured speed, turned around
				_boat.linear_velocity = _eject_dir * _exit_speed
				_reset()
				_cooldown = 1.5


func _reset() -> void:
	_boat  = null
	_phase = Phase.IDLE
