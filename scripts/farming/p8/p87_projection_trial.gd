extends "res://scripts/farming/p8/p87_scene.gd"
## Isolated A sample. Never reads/writes player slots or display settings.
func _init() -> void:
	super()
	var path := "res://.art-work/p87-interactive/session-%d" % OS.get_process_id()
	store = P8Store.new(path)
	settings = Settings.new(path+"/settings.cfg",0.1)
	show_rulers = true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _text_focus():
		if event.keycode == KEY_F7:
			configure_projection("p86" if projection.enabled else "matched35")
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F8:
			show_rulers = not show_rulers
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	super(event)
