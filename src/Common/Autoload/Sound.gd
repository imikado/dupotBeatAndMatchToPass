extends Node

const PATH_AUDIO_CONFIG := "user://audio.cfg"

const POOL_SIZE = 10
const MUSIC_VOLUME_DB = -10.0

const SOUNDS = {
	"swing": preload("res://src/Common/Audio/sounds/swing.wav"),
	"hit": preload("res://src/Common/Audio/sounds/hit.wav"),
	"enemy_die": preload("res://src/Common/Audio/sounds/enemy_die.wav"),
	"player_hurt": preload("res://src/Common/Audio/sounds/player_hurt.wav"),
	"thunder": preload("res://src/Common/Audio/sounds/thunder.wav"),
	"energy": preload("res://src/Common/Audio/sounds/energy.wav"),
	"barrier_open": preload("res://src/Common/Audio/sounds/barrier_open.wav"),
	"bottle": preload("res://src/Common/Audio/sounds/bottle.wav"),
	"combo": preload("res://src/Common/Audio/sounds/combo.wav"),
	"spider_shot": preload("res://src/Common/Audio/sounds/spider_shot.wav"),
	"mana_ready": preload("res://src/Common/Audio/sounds/mana_ready.wav"),
	"level_complete": preload("res://src/Common/Audio/sounds/level_complete.wav"),
	"gameover": preload("res://src/Common/Audio/sounds/gameover.wav"),
	"go": preload("res://src/Common/Audio/sounds/go.wav"),
	"menu_move": preload("res://src/Common/Audio/sounds/menu_move.wav"),
	"menu_select": preload("res://src/Common/Audio/sounds/menu_select.wav"),
	"logo": preload("res://src/Common/Audio/sounds/logo.wav"),
	"pause": preload("res://src/Common/Audio/sounds/pause.wav"),
}

const MUSIC = preload("res://src/Common/Audio/sounds/music.wav")

var _pool := []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _music_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = MUSIC
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	load_config()


func _exit_tree() -> void:
	_music_player.stop()
	_music_player.stream = null
	for player in _pool:
		player.stop()
		player.stream = null


func play(sound_name: String, pitch_variation: float = 0.08, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound_name):
		print_debug("Unknown sound: " + sound_name)
		return

	var player: AudioStreamPlayer = _pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE

	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_music() -> void:
	if not _music_enabled or _music_player.playing:
		return
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func _on_music_finished() -> void:
	if _music_enabled:
		_music_player.play()


func toggle_music() -> void:
	_music_enabled = !_music_enabled
	if _music_enabled:
		play_music()
	else:
		stop_music()
	save_config()


func is_music_enabled() -> bool:
	return _music_enabled


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_music()


func load_config() -> void:
	var config = ConfigFile.new()
	if config.load(PATH_AUDIO_CONFIG) == OK:
		_music_enabled = config.get_value("audio", "music_enabled", true)


func save_config() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_enabled", _music_enabled)
	config.save(PATH_AUDIO_CONFIG)
