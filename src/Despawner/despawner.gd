@tool
class_name Despawner
extends Node3D

## When true, the despawner actively removes objects that enter its area.
@export var monitoring: bool = true:
	set(value):
		if _area_3d:
			_area_3d.monitoring = value
	get:
		return _area_3d.monitoring if _area_3d else true

@onready var _area_3d: Area3D = get_node("Area3D")


func _enter_tree() -> void:
	if _area_3d && not _area_3d.body_entered.is_connected(_body_entered):
		_area_3d.body_entered.connect(_body_entered)


func _ready() -> void:
	_area_3d.body_entered.connect(_body_entered)
	# Add a StaticBody3D so the selection system's raycast can detect this node.
	# Area3D nodes are not returned by intersect_ray.
	_create_selection_body()


func _exit_tree() -> void:
	_area_3d.body_entered.disconnect(_body_entered)


func _body_entered(node: Node) -> void:
	var _parent := node.get_parent()
	if _parent.has_method("selected") and _parent.get("instanced"):
		_parent.queue_free()


## Create a StaticBody3D that mirrors the Area3D collision shape so that
## physics raycasts (used by the selection system) can hit the despawner.
func _create_selection_body() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var area_shape := _area_3d.get_node_or_null("CollisionShape3D")
	if area_shape and area_shape.shape:
		shape_node.shape = area_shape.shape.duplicate()
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(1, 1, 1)
		shape_node.shape = box
	body.add_child(shape_node)
	add_child(body)
