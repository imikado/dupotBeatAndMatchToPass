extends Node

const DEBUG_ENABLED = false

const GROUP_ENEMY := "enemy"
const GROUP_BONUSACTOR := "bonusactor"

const PATH_HIGHSCORE := "user://highscore.dat"

enum ENEMY_TYPE_LIST { ANT, SPIDER, BEETLE }

var _is_debug := false

var _is_controls_enabled := true

var last_score_is_record := false

# Mode capture (update_screenshots.sh) : lancé avec « -- --screenshots=<dossier> »,
# F12 enregistre l'écran en 1280x720 dans ce dossier ; avec « --tour » en plus,
# ScreenshotTour joue tout seul et prend les captures du README / de Flathub ;
# avec « --demo=<clip> », DemoTour joue la démo du README (update_demo.sh)
const SCREENSHOT_SIZE := Vector2i(1280, 720)
var _screenshot_dir := ""
var _screenshot_count := 0


func _ready():
	var is_tour := false
	var demo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			_screenshot_dir = arg.trim_prefix("--screenshots=")
		elif arg == "--tour":
			is_tour = true
		elif arg.begins_with("--demo="):
			demo = arg.trim_prefix("--demo=")
	if _screenshot_dir == "":
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_screenshot_dir)
	DisplayServer.window_set_size(SCREENSHOT_SIZE)
	if demo != "":
		add_child(load("res://src/Common/Autoload/DemoTour.gd").new(demo))
	elif is_tour:
		add_child(preload("res://src/Common/Autoload/ScreenshotTour.gd").new())


func _input(event):
	if _screenshot_dir == "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		takeScreenshot()


func takeScreenshot(file_name := ""):
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != SCREENSHOT_SIZE:
		image.resize(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGB8)
	_screenshot_count += 1
	if file_name == "":
		file_name = "capture_%03d.png" % _screenshot_count
	var path := _screenshot_dir.path_join(file_name)
	image.save_png(path)
	print("Capture : ", path)


func isControlsEnabled():
	return _is_controls_enabled


func setControlsEnabled(enabled):
	_is_controls_enabled = enabled


func is_debug():
	return _is_debug


func hit_stop(duration: float, time_scale: float = 0.05) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func saveHighScore(newScoreValue):
	var datetimeNow = Time.get_datetime_dict_from_system()

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

	last_score_is_record = false
	if !isHighestScore(highScoreList, newScoreValue):
		return
	last_score_is_record = true

	var newScoreObj = {"score": newScoreValue, "date": dateTimeString}

	highScoreList.append(newScoreObj)

	var jsonList = JSON.stringify(highScoreList)
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
	if !FileAccess.file_exists(PATH_HIGHSCORE):
		return []

	var content = loadFile(PATH_HIGHSCORE)

	var highScoreListParseResult = JSON.parse_string(content)

	if typeof(highScoreListParseResult) == TYPE_ARRAY:
		return highScoreListParseResult

	return []


func saveFile(filepath, content):
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(content)
	file.close()


func loadFile(filepath):
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return ""
	var content = file.get_as_text()
	file.close()
	return content

func isInputNextButton(event: InputEvent)->bool:
	if event.is_action_pressed("attack_mana") or event.is_action_pressed(PlayerAbstractState.INPUT_DOWN)  or event.is_action_pressed(PlayerAbstractState.INPUT_UP) or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_cancel"):
		return true
	return false
	
func isInputValidateButton(event: InputEvent)->bool:
	if event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		return true
	return false

# Escape / gamepad Start / Home: deliberately not ui_cancel, which is also gamepad B (mana attack)
func isInputPauseButton(event: InputEvent)->bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		return true
	return event.is_action_pressed("ui_home")

func isInputEscapeButton(event: InputEvent)->bool:
	if event.is_action_pressed("ui_home") or event.is_action_pressed("ui_cancel"):
		return true
	return false
