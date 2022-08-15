extends Node

const START_LIFE=100
const START_MANA=10
const MAX_MANA=80

var score=0
var life=START_LIFE
var mana=START_MANA

var attack_amount_mana=10

func increment_mana(value):
	mana+=value
	if mana > MAX_MANA:
		mana=MAX_MANA


func use_amount_mana(value):
	mana-=value


func can_use_amount_mana(value):
	if mana >= value:
		return true
	return false


func decrease_health(value):
	life-=value


func update_life(value):
	life=value
