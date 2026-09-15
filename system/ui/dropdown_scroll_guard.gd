extends Node

# All app windows and creators share this behavior, including dynamically built pages.
func _ready() -> void:
	get_tree().node_added.connect(_watch_node)
	_watch_existing(get_tree().root)

func _watch_existing(node: Node) -> void:
	_watch_node(node)
	for child in node.get_children():
		_watch_existing(child)

func _watch_node(node: Node) -> void:
	if node is ScrollContainer:
		_connect_scroll.call_deferred(node)

func _connect_scroll(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	var close_dropdowns := _close_dropdowns.bind(scroll)
	for bar in [scroll.get_h_scroll_bar(), scroll.get_v_scroll_bar()]:
		if not bar.value_changed.is_connected(close_dropdowns):
			bar.value_changed.connect(close_dropdowns)

func _close_dropdowns(_value: float, content: Node) -> void:
	for child in content.get_children():
		if child is OptionButton or child is MenuButton:
			child.get_popup().hide()
		elif not child is Window:
			_close_dropdowns(_value, child)
