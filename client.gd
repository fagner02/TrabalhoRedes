extends Node2D

class Peer:
	var connection: PacketPeerUDP
	var ip: String
	var port: String
	
class Oponent:
	var name: String
	var player: CharacterBody2D

var initial_pos = Vector2(100,100)
var ip = get_ip()
var port = 5000
var client = PacketPeerUDP.new()
var udp_server = UDPServer.new()
var peers: Array[Peer] = []
var oponents: Array[Oponent] = []
var started = false
@onready var background = $"background"
@onready var controls = $"Control"
@onready var bounds = $"StaticBody2D"
@onready var background_size = Vector2(background.texture.get_width(), background.texture.get_height())
var playername = ""
var is_host = false
var playerscene = preload("res://oponent.tscn")
@onready var screen_size = Vector2.ZERO

@onready var player = $"player"

func _ready():
	player.position = initial_pos
	if udp_server.listen(port, ip) != OK:
		port += 1
		udp_server.listen(port, ip)
		

func _process(_delta):
	if (get_viewport_rect().size != screen_size):
		screen_size = get_viewport_rect().size
		controls.size = screen_size
		
		var children = bounds.get_children()
		children[0].shape.b.x = screen_size.x
		children[1].shape.b.x = screen_size.x
		children[1].position.y = screen_size.y
		children[2].shape.b.y = screen_size.y
		children[3].shape.b.y = screen_size.y
		children[3].position.x = screen_size.x
		var ratio = Vector2(((screen_size/2.0).length()*2.0)/screen_size.x, ((screen_size/2.0).length()*2.0)/screen_size.y)
		background.scale = ((screen_size/background_size) * ratio)
		background.position = screen_size/2.0

	udp_server.poll()
 
	if udp_server.is_connection_available() and is_host:
		var connection = udp_server.take_connection()
		
		var req = JSON.parse_string(connection.get_packet().get_string_from_utf8())
		
		print("connection received(on "+ip+":"+str(port)+"): from "+req.from)
		var from = req.from.split(":")
		
		var new_peer = Peer.new()
		new_peer.connection = connection
		new_peer.ip = from[0]
		new_peer.port = from[1]
		
		peers.append(new_peer)
	
		print("peer added(on "+ip+":"+str(port)+"): ", new_peer.ip, ":", new_peer.port)
		connection.put_packet(JSON.stringify({
			"from":ip+":"+str(port),
			"action":"connected", 
			"players": oponents.map(func(x): x.name) + [playername]
		}).to_utf8_buffer())
	get_packets()

func get_packets():
	if (not is_host):
		if client.get_available_packet_count() <= 0:
			return
		var json = client.get_packet().get_string_from_utf8()
		var res = JSON.parse_string(json)

		print("connected to host")
		if (res.action == "connected"):
			client.put_packet(JSON.stringify({"from":ip+":"+str(port),"action":"add", "name": playername}).to_utf8_buffer())
			for _player in res.players:
				add_oponent(_player)
		if (res.action == "add"):
			add_oponent(res.name)
		if (res.action == "select"):
			oponent_select(res)
		if (res.action == "start"):
			started = true
		if (res.action == "collide"):
				oponent_collide(res)
		return
		
	for peer: Peer in peers:
		if peer.connection.get_available_packet_count() > 0:
			var res = JSON.parse_string(peer.connection.get_packet().get_string_from_utf8())

			if res.action == "connected":
				player.position = initial_pos
			if res.action == "add":
				add_oponent(res.name)
				send_packets(res, peer)
			if (res.action == "select"):
				oponent_select(res)
				send_packets(res, peer)
			if (res.action == "collide"):
				oponent_collide(res)
				

func send_packets(data, _peer = null):
	for peer: Peer in peers:
		if peer != _peer or _peer == null:
			peer.connection.put_packet(JSON.stringify(data).to_utf8_buffer())
			
func oponent_select(res):
	var oponent = oponents.filter(func(x): return x.name == res.player)[0]
	oponent.player.select(
		Vector2(res.new_direction.x, res.new_direction.y), 
		res.rot, 
		Vector2(res.pos.x, res.pos.y),
		Vector2(res.vel.x, res.vel.y)
	)

func oponent_collide(res):
	var oponent = oponents.filter(func(x): return x.name == res.player)[0]
	oponent.player.collide(
		Vector2(res.new_direction.x, res.new_direction.y), 
		res.rot, 
		Vector2(res.pos.x, res.pos.y),
		Vector2(res.vel.x, res.vel.y)
	)

func send_select(new_direction: Vector2, rot, pos: Vector2, vel):
	var packet = {
		"from": ":",
		"action": "select",
		"new_direction": {"x": new_direction.x, "y": new_direction.y},
		"pos": {"x": pos.x, "y":pos.y},
		"rot": rot,
		"vel": {"x":vel.x, "y": vel.y},
		"player": playername
	}
	if is_host:
		send_packets(packet)
	else:
		client.put_packet(JSON.stringify(packet).to_utf8_buffer())
		
func send_collide(new_direction: Vector2, rot, pos: Vector2, vel):
	var packet = {
		"from": ":",
		"action": "collide",
		"new_direction": {"x": new_direction.x, "y": new_direction.y},
		"pos": {"x": pos.x, "y":pos.y},
		"rot": rot,
		"vel": {"x":vel.x, "y": vel.y},
		"player": playername
	}
	if is_host:
		send_packets(packet)
	else:
		client.put_packet(JSON.stringify(packet).to_utf8_buffer())
func add_oponent(_name):
	var new_oponent = Oponent.new()
	new_oponent.player = playerscene.instantiate()
	new_oponent.player.position = initial_pos
	new_oponent.name = _name
	add_child(new_oponent.player)
	oponents.append(new_oponent)
func _on_button_join_host():
	var code: String = $"%iptext".text
	if code.length() < 4:
		return
	var dest = ".".join(ip.split(".").slice(0, 2))+"."+\
		".".join([0, 2].map(func(num): return str(code.substr(num, 2).hex_to_int())))
	
	$"textt".text += dest+":"+str(5000+int(code.substr(4,1)))+"\n"
	print("send(from "+ip+":"+str(port)+"): to "+dest+":"+str(5000+int(code.substr(4,1))))
	
	$"%startmenu".visible = false
	$"%waitingsign".visible = true
	client.connect_to_host(dest, 5000+int(code.substr(4,1)))
	client.put_packet(JSON.stringify({"from":ip+":"+str(port),"action":"connect", "name":playername}).to_utf8_buffer())

func _on_button_create_host():
	is_host = true
	print("ip: ", ip)
	var res = "".join(Array(ip.split(".").slice(2, 6)).map(func(num): return ("%x" % int(num)).lpad(2, "0"))).to_upper()
	
	$"%startmenu".visible = false
	$"%hostmenu".visible = true
	$"%code".text = res+str(port-5000)

func  get_ip():
	var _ip: String

	for address in IP.get_local_interfaces():
		if address["friendly"].to_lower().begins_with("w"):
			_ip = address["addresses"].filter(func(x: String): return x.split(".").size() == 4)[0]
			break

	return _ip

func _on_name_text_changed():
	playername = $"%name".text
	pass # Replace with function body.

func _on_start_pressed():
	$"%hostmenu".visible=false
	started = true
	send_packets({
		"from": ":",
		"action": "start"
	})
	pass # Replace with function body.
