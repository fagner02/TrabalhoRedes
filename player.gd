extends CharacterBody2D

const initial = Vector2(0,1)
var direction = initial
var speed = 100
var selecting = true
@onready var player = $"."
@onready var selection = $"outline/AnimationPlayer" 
var color = Color.from_hsv(0.0,0.58, 1)

func _ready():
	var _rotation = player.rotation
	direction = initial.rotated(_rotation)
	velocity = speed * direction

func _input(event):
	if (not $"../".started):
		return
	if(event.is_action_pressed("space")) or (event is InputEventScreenTouch and event.is_pressed()):
		if selecting:
			selecting = false
			selection.play("close")
			var _rotation = player.rotation
			direction = -initial.rotated(_rotation)
			velocity = speed * direction
		else: 
			select()
		print(velocity)
		$"../".send_select(direction, player.rotation, player.position, velocity, not selecting)

func select():
	selecting = true
	selection.play("open")

func _process(_delta):
	if selecting: 
		player.rotate(deg_to_rad(10))
		return
	var collision = move_and_collide(velocity)
	if collision:
		if (collision.get_collider().name.begins_with("point")):
			$"../".consume_point(collision.get_collider().get_parent().name)
			return
		velocity = velocity.bounce(collision.get_normal())
		player.rotation = velocity.angle()+deg_to_rad(90)
		$"../".send_collide(direction, player.rotation, player.position, velocity)
	velocity *= 0.99
	
