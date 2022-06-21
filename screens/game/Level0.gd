extends "res://common/class/scene.gd"

onready var BlueSpider=preload("res://common/enemies/blue-spider.tscn")

const SPEED=15

onready var spawnPositionList=[
	get_node("Path2D/PathFollow2D/Camera2D/enemySpawnPosition1"),
	get_node("Path2D/PathFollow2D/Camera2D/enemySpawnPosition2"),
	get_node("Path2D/PathFollow2D/Camera2D/enemySpawnPosition3")	
]

func debug():
	GlobalPlayer.addItem(GlobalItems.ID.WOOD_SWORD)
	GlobalPlayer.setEquipment((GlobalItems.ID.WOOD_SWORD))

	
# Called when the node enters the scene tree for the first time.
func _ready():
	debug()
	
	
	setPlayerPath("playerAndControl")

	spawnBlueSpider()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Path2D/PathFollow2D.offset+=SPEED*delta
#	pass


func _on_outCamera_outOfCamera():
	print("OUT")
	pass # Replace with function body.

func getRandomPosition():
		
	randomize()
	var spawnI=randi()  %3
	print(spawnI)
	
	return spawnPositionList[spawnI]

func spawnBlueSpider():

	var newBlueSpider=BlueSpider.instance()
	newBlueSpider.setPlayer(getPlayer())
	newBlueSpider.position=getRandomPosition().global_position
	
	add_child(newBlueSpider)


func _on_SpawnTimer_timeout():
	spawnBlueSpider()


func _on_playerAndControl_damagedBy(enemy_):
	pass # Replace with function body.


func _on_playerAndControl_hit(enemy_):
	print(enemy_)
	enemy_.damaged(10)
	pass # Replace with function body.
