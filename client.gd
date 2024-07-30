extends Node2D

const port = 8090
var client = PacketPeerUDP.new()
var udp_server = UDPServer.new()
var peers: Array[PacketPeerUDP] = []
var playername = ""
var playerscene = preload("res://player.tscn")

func _ready():
	pass

func _process(delta):
	udp_server.poll()
	
	if udp_server.is_connection_available():
		print("connected")
		var connection = udp_server.take_connection()
		$"textt".text += connection.get_packet_ip()+"\n"
		if !peers.any(func(x: PacketPeerUDP): x.get_packet_ip() == connection.get_packet_ip()):
			peers.append(connection)
	get_packets()

func get_packets():
	for peer in peers:
		if peer.get_available_packet_count() > 0:
			var res = peer.get_packet().get_string_from_utf8().split(",")
		
			if res[0] == "add":
				add_child(playerscene.instantiate())

			if res[0] == "ready":
				pass
			send_packets(",".join(res), peer.get_packet_ip())

func send_packets(data, ingoreip):
	for peer in peers:
		if peer.get_packet_ip() != ingoreip:
			peer.put_packet(data)

func _on_button_pressed():
	if client.is_socket_connected():
		client.put_packet(("Hello world"+$"name".text).to_utf8_buffer())

func _on_button_join_host():
	var ip = get_ip()
	var code: String = $"%iptext".text
	if code.length() < 4:
		return
	var dest = ".".join(ip.split(".").slice(0,2)) + "." \
				+ str(code.substr(0, 2).hex_to_int()) + "." \
				+ str(code.substr(2, 3).hex_to_int())
	$"textt".text += dest+"\n"
	client.connect_to_host(dest, port)
	client.put_packet(("add,"+playername).to_utf8_buffer())

func _on_button_create_host():
	var ip: String = get_ip()
	print("ip: ", ip)
	
	if udp_server.listen(port, ip) != OK:
		print("erro ao escutar na porta ", port)

func  get_ip():
	var ip: String
	
	for address in IP.get_local_addresses():
		if (address.split('.').size() == 4):
			ip=address
	return ip

func _on_name_text_changed():
	playername = $"%name".text
	pass # Replace with function body.
