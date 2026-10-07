class_name PlayerStateMove
extends PlayerAbstractStateMotion

var MAX_WALK_SPEED = 60

var speed = 0.0
var velocity = Vector2()

func enter():
	speed = 0.0
	velocity = Vector2()

	var input_direction = get_input_direction()
	update_look_direction(input_direction)
	play_animation(ANIM_WALK_RIGHT)


func handle_input(event):
	return super.handle_input(event)


func update(delta):
	var input_direction = get_input_direction()
	if not input_direction:
		emit_signal("finished", STATE_IDLE)
	update_look_direction(input_direction)

	speed = MAX_WALK_SPEED
	var collision_info = move(speed, input_direction)
	if not collision_info:
		return


func move(speed, direction):
	var body: CharacterBody2D = owner
	velocity = direction.normalized() * speed
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body.max_slides = 2
	body.velocity = velocity
	body.move_and_slide()
	if body.get_slide_collision_count() == 0:
		return
	return body.get_slide_collision(0)
