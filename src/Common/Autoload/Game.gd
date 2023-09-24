extends Node

const DEBUG_ENABLED = false

const GROUP_ENEMY := "enemy"
const GROUP_BONUSACTOR := "bonusactor"

const PATH_HIGHSCORE := "user://highscore.dat"

enum ENEMY_TYPE_LIST { ANT, SPIDER, BEETLE }

var _is_debug := false


func is_debug():
	return _is_debug


func saveHighScore(newScoreValue):
	var datetimeNow = OS.get_datetime()

	var dateTimeString = (
		str("%04d" % [datetimeNow.year])
		+ "-"
		+ str("%02d" % [datetimeNow.month])
		+ "-"
		+ str("%02d" % [datetimeNow.day])
		+ " "
		+ str("%02d" % [datetimeNow.hour])
		+ ":"
		+ str("%02d" % [datetimeNow.minute])
	)

	var highScoreList = getHighScoreList()

	if !isHighestScore(highScoreList, newScoreValue):
		return

	var newScoreObj = {"score": newScoreValue, "date": dateTimeString}

	highScoreList.append(newScoreObj)

	var jsonList = JSON.print(highScoreList)
	saveFile(PATH_HIGHSCORE, jsonList)

	pass


func getHighestScore(highScoreList):
	var highestScore = 0
	for highScoreLoop in highScoreList:
		if highScoreLoop.score > highestScore:
			highestScore = highScoreLoop.score

	return highestScore


func isHighestScore(highScoreList, askScore):
	var highestScore = getHighestScore(highScoreList)
	if askScore > highestScore:
		return true

	return false


func getHighScoreList():
	var directory = Directory.new()
	if !directory.file_exists(PATH_HIGHSCORE):
		return []

	var content = loadFile(PATH_HIGHSCORE)

	var highScoreListParseResult = JSON.parse(content)

	if typeof(highScoreListParseResult.result) == TYPE_ARRAY:
		return highScoreListParseResult.result

	return []


func saveFile(filepath, content):
	var file = File.new()
	file.open(filepath, File.WRITE)
	file.store_string(content)
	file.close()


func loadFile(filepath):
	var file = File.new()
	file.open(filepath, File.READ)
	var content = file.get_as_text()
	file.close()
	return content
