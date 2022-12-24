extends Node

const DEBUG_ENABLED=false

const GROUP_ENEMY:="enemy"
const GROUP_BONUSACTOR:="bonusactor"

enum ENEMY_TYPE_LIST { ANT, SPIDER, BEETLE}

var _is_debug:=false

func is_debug():
	return _is_debug
	
