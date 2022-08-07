extends Node

const START_LIFE=100
const START_MANA=10
const MAX_MANA=80

var score=0
var life=START_LIFE
var mana=START_MANA

func increment_mana(value):
	mana+=value
	if mana > MAX_MANA:
		mana=MAX_MANA
	
func decrease_health(value):
	life-=value

func update_life(value):
	life=value
