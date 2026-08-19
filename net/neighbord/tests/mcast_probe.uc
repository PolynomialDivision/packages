#!/usr/bin/ucode

/*
 * mcast_probe.uc send <device> <payload>
 * mcast_probe.uc recv <device> <expected-payload> <ready-marker-file>
 */

let socket = require("socket");
let fs = require("fs");

const GROUP = "ff12::6e65:6967:6862:6f72:64";
const PORT = 32027;
const DEADLINE_S = 5;

function die(message) {
	warn("mcast_probe: " + message + "\n");
	exit(1);
}

function open_socket(device) {
	let sk = socket.create(socket.AF_INET6, socket.SOCK_DGRAM | socket.SOCK_NONBLOCK, 0);
	if (!sk)
		die("socket.create: " + socket.error());

	if (!sk.setopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, true) ||
	    !sk.setopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, device) ||
	    !sk.setopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, true) ||
	    !sk.bind({ address: "::", port: PORT }) ||
	    !sk.setopt(socket.IPPROTO_IPV6, socket.IPV6_ADD_MEMBERSHIP,
	               { multiaddr: GROUP, interface: device }) ||
	    !sk.setopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, device) ||
	    !sk.setopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, 1) ||
	    !sk.setopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_LOOP, false))
		die("socket setup on " + device + ": " + socket.error());

	let bound = sk.sockname();
	if (bound.port != PORT)
		die(sprintf("bound to port %d instead of %d", bound.port, PORT));

	warn(sprintf("mcast_probe: bound [%s]:%d on %s\n", bound.address, bound.port, device));
	return sk;
}

let role = ARGV[0];
let device = ARGV[1];

if (role == "send") {
	let payload = ARGV[2];
	let sk = open_socket(device);
	let sent = sk.send(payload, 0, {
		family: socket.AF_INET6,
		address: GROUP,
		port: PORT,
		interface: device
	});
	if (sent == null)
		die("send: " + socket.error());
	warn(sprintf("mcast_probe: sent %d bytes to [%s%%%s]:%d\n", sent, GROUP, device, PORT));
	exit(0);
}

if (role == "recv") {
	let expected = ARGV[2];
	let ready_marker = ARGV[3];
	let sk = open_socket(device);

	if (ready_marker) {
		let fp = fs.open(ready_marker, "w");
		if (!fp)
			die("cannot create ready marker " + ready_marker);
		fp.close();
	}

	let start = clock(true)[0];
	while (clock(true)[0] - start < DEADLINE_S) {
		let address = {};
		let data = sk.recv(2048, socket.MSG_DONTWAIT, address);
		if (data == null)
			continue;
		if (data == expected) {
			warn(sprintf("mcast_probe: received %d bytes from %s\n",
			             length(data), address.address));
			exit(0);
		}
		warn("mcast_probe: received unexpected payload: " + data + "\n");
	}
	die("timed out waiting for multicast datagram on " + device);
}

die("unknown role '" + role + "', expected 'send' or 'recv'");
