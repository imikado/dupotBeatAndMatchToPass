extends KinematicBody2D

signal startClimbing
signal endClimbing

signal hit(enemy_)
signal damagedBy(enemy_)

signal pressAccept
signal pressMenu

var speed=100

var left=false
var right=false
var up=false
var down=false
var buttonPressed=false

var useTouch=false

var startClimbing=false
var onScale=false
var isClimbing=false

var limitLeft=0
var limitRight=0
var limitTop=0
var limitBottom=0

#export var refRect : Rect2

var refRect:ReferenceRect

const DIR_RIGHT='right'
const DIR_LEFT='left' 
const DIR_UP='up'
const DIR_DOWN='down'

var side=DIR_RIGHT

var isAttacking=false

var currentAnimation=null

const ANIM_IDLE='idle'
const ANIM_ATTACK_1='attack1'

func loadCameraLimits(refRect_: ReferenceRect):
	refRect=refRect_

func updateRefRect():
	var position=refRect.rect_global_position
	var rect=refRect.rect_size + position
	
	limitLeft=position.x
	limitTop=position.y
	limitRight=rect.x
	limitBottom=rect.y
 

func attack():
	print("attack")
	playAnimation(ANIM_ATTACK_1)
	isAttacking=true

	$hit/hitCollision.disabled=false
	#$attackArea/attackCollision.disabled=false
	
func resetAttack():
	isAttacking=false
	currentAnimation=null
	$hit/hitCollision.disabled=true
	#$attackArea/attackCollision.disabled=true

	
func _ready():
	add_to_group("Player")

	flipPlayer(DIR_RIGHT)
	#loadCameraLimits()
	#resetZoom()

func _process(delta):

	pocessInput()
	
	if isAttacking:
		return
	
	var velocity = Vector2()  # The player's movement vector.
	
	var moveSide=null
	
	if left:
		velocity.x -= 1
		moveSide=DIR_LEFT
	elif right:
		velocity.x += 1
		moveSide=DIR_RIGHT
	elif up:
		velocity.y -= 1	
		moveSide=DIR_UP
	elif down:
		velocity.y += 1
		moveSide=DIR_DOWN
		
	flipPlayer(moveSide)
	
	var velocityMin=velocity	
		
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
	
	var expectPosition=global_position+velocityMin
	
	#updateRefRect()
	#if expectPosition.x < limitRight && expectPosition.x > limitLeft && expectPosition.y > limitTop && expectPosition.y < limitBottom: 	
		
	#	move_and_slide(velocity)
	move_and_slide(velocity)
 
	
	processAnimation()
	
	resetKeys()


func pocessInput():
	if Input.is_action_pressed("ui_right"):
		right=true
		useTouch=false
	if Input.is_action_pressed("ui_left"):
		left=true
		useTouch=false
	if Input.is_action_pressed("ui_down"):
		down=true
		useTouch=false
	if Input.is_action_pressed("ui_up"):
		up=true
		useTouch=false
		
	if Input.is_action_just_pressed("ui_accept"):
		emit_signal("pressAccept")
	
	if Input.is_action_just_pressed("ui_cancel"):
		emit_signal("pressMenu")
		print("press menuA")
	
	
	if Input.is_action_just_pressed("ui_accept"):
		attack()
		useTouch=false


		

func flipPlayer(side_):
	
	if(side_==null):
		return
	elif(side==side_):
		return

	if(side_==DIR_RIGHT || side_==DIR_LEFT):

		apply_scale(Vector2(-1,1))
	else:
		return
	
	side=side_

		
func processAnimation():
	var currentAnimation='walk-right'
	
	if up :
		currentAnimation='walk-up'
	elif down :
		currentAnimation='walk-down'
	elif left:
		currentAnimation='walk-right'
	elif right:
		currentAnimation='walk-right'
	else:
		currentAnimation=ANIM_IDLE

	playAnimation(currentAnimation)


func playAnimation(anim):
	if anim==currentAnimation:
		return
	
	currentAnimation=anim
	$AnimatedSprite.play(anim)
	
	

func stop():
	left=false
	right=false
	up=false
	down=false

func resetKeys():
	if useTouch:
		return
		
	left=false
	right=false
	up=false
	down=false


func _on_navigation_movePlayer(joystickVector_):
	useTouch=true
	
	right=false
	left=false
	down=false
	up=false	
	
	if abs(joystickVector_.x)>abs(joystickVector_.y) :
	
		if(joystickVector_.x > 10):
			right=true
		elif(joystickVector_.x < -10):
			left=true
	 
	else:
				
		if(joystickVector_.y > 10):
			down=true
		elif(joystickVector_.y < -10):
			up=true


func _on_gordonhome_playerStartClimbing():
	startClimbing=true
	emit_signal("startClimbing")

func _on_gordonhome_playerOnScale():
	onScale=true

func _on_gordonhome_playerLeaveScale():
	onScale=false

func _on_gordonhome_playerEndClimbing():
	if !onScale:
		startClimbing=false
		emit_signal("endClimbing")


func _on_navigation_releaseButton():
	buttonPressed=false
	pass # Replace with function body.


func _on_navigation_pushButton():
	attack()
	buttonPressed=true




func _on_hit_body_shape_entered(body_id, body, body_shape, area_shape):
	if body.is_in_group("Enemy"):
		emit_signal("hit",body)
		



func _on_damage_body_shape_entered(body_id, body, body_shape, area_shape):
	if body.is_in_group("Enemy"):
		emit_signal("damagedBy",body)
		animDamage()
		

func animDamage():
	$redModulate.visible=true
	$timerModulate.start()


func _on_timerModulate_timeout():
	$redModulate.visible=false



func _on_AnimatedSprite_animation_finished():
	if currentAnimation==ANIM_ATTACK_1:
		resetAttack()
	pass # Replace with function body.
