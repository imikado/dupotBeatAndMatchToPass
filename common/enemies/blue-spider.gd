extends KinematicBody2D

signal hitPlayer

const DIR_RIGHT='right'
const DIR_LEFT='left' 
const DIR_UP='up'
const DIR_DOWN='down'

var side=DIR_RIGHT

const ANIM_IDLE="idle"
const ANIM_ATTACK="attack"
const ANIM_DAMAGE="damage"
const ANIM_DIE="die"

const SPEED = 15

var player=null
var directionBack
var shouldGoBack=false

var isRunningAnimation=false

var currentAnimation=null

var life=20

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("Enemy")
	
	flipPlayer(DIR_RIGHT)
	playAnimation(ANIM_IDLE)

func damaged(damage_):
	life-=damage_
	if life <= 0:
		die()
		return
	lockAnimation()
	playAnimation(ANIM_DAMAGE)

func die():
	lockAnimation()
	playAnimation(ANIM_DIE)

#animation
func unlockAnimation():
	isRunningAnimation=false

func lockAnimation():
	isRunningAnimation=true

#attack
func attack():
	print("attack")
	lockAnimation()
	playAnimation(ANIM_ATTACK)
	$attackArea/attackCollision.disabled=false
	
func resetAttack():
	unlockAnimation()
	$attackArea/attackCollision.disabled=true

	
func setPlayer(player_):
	player=player_

func getPlayer():
	return player

func _process(delta):
	
	if(isRunningAnimation):
		return

	var player_position=getPlayer().getPlayerPosition()

	var player_relative_position =  player_position - position

	var direction = Vector2.ZERO

	if position.x < player_position.x:
		flipPlayer(DIR_RIGHT)
	else:
		flipPlayer(DIR_LEFT)
	
	if player_relative_position.length() <= 50:
		direction = Vector2.ZERO
		attack()
	else :
		direction = player_relative_position.normalized()
		playAnimation(ANIM_IDLE)
	move_and_collide(direction*delta*SPEED)
	
	directionBack=-1*direction*SPEED


		
func playAnimation(anim):
	if anim==currentAnimation:
		return
		
	$AnimatedSprite.play(anim)
	currentAnimation=anim

func goBack():
	shouldGoBack=true


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


func _on_attackArea_body_entered(body):
	if body.is_in_group("Player"):
		emit_signal("hitPlayer")
	pass # Replace with function body.


func _on_AnimatedSprite_animation_finished():
	if currentAnimation == ANIM_ATTACK:
		resetAttack()
	elif currentAnimation == ANIM_DAMAGE:
		unlockAnimation()
	elif currentAnimation == ANIM_DIE:
		unlockAnimation()
		queue_free()
	
