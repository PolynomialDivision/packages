#!/bin/sh
# Sends a real IPv6 UDP multicast datagram across a Linux bridge between two
# network namespaces (veth-a/br0/veth-b), using neighbord's actual socket
# calls, to prove the transport works between two separate hosts.
set -eu

repo_dir="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
probe="$repo_dir/tests/mcast_probe.uc"

if ! command -v unshare >/dev/null 2>&1 || ! command -v nsenter >/dev/null 2>&1; then
	echo "skip - unshare/nsenter not available"
	exit 0
fi

if ! command -v ucode >/dev/null 2>&1; then
	echo "skip - ucode not available"
	exit 0
fi

if ! unshare --user --net --map-root-user true 2>/dev/null; then
	echo "skip - unprivileged user/network namespaces are not permitted here"
	exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

unshare --user --net --map-root-user --mount --fork -- sh -c '
	set -eu
	work="'"$work"'"
	probe="'"$probe"'"
	payload="neighbord-integration-probe"

	ip link add veth-a type veth peer name veth-a-br
	ip link add veth-b type veth peer name veth-b-br
	ip link add br0 type bridge
	ip link set veth-a-br master br0
	ip link set veth-b-br master br0
	ip link set br0 up
	ip link set veth-a-br up
	ip link set veth-b-br up

	unshare --net -- sh -c "echo \$\$ > \"$work/apA.pid\"; exec sleep 30" &
	unshare --net -- sh -c "echo \$\$ > \"$work/apB.pid\"; exec sleep 30" &

	for i in 1 2 3 4 5 6 7 8 9 10; do
		[ -s "$work/apA.pid" ] && [ -s "$work/apB.pid" ] && break
		sleep 0.2
	done
	apA="$(cat "$work/apA.pid")"
	apB="$(cat "$work/apB.pid")"

	ip link set veth-a netns "$apA"
	ip link set veth-b netns "$apB"

	nsenter -t "$apA" -n -- sh -c "
		ip link set lo up
		ip link set veth-a name eth0
		ip link set eth0 up
	"
	nsenter -t "$apB" -n -- sh -c "
		ip link set lo up
		ip link set veth-b name eth0
		ip link set eth0 up
	"

	# Let IPv6 duplicate-address detection / link-local assignment settle.
	sleep 3

	nsenter -t "$apB" -n -- ucode "$probe" recv eth0 "$payload" "$work/ready" \
		> "$work/recv.log" 2>&1 &
	recv_pid=$!

	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
		[ -e "$work/ready" ] && break
		sleep 0.2
	done
	[ -e "$work/ready" ] || { echo "not ok - receiver never became ready"; cat "$work/recv.log"; exit 1; }

	nsenter -t "$apA" -n -- ucode "$probe" send eth0 "$payload" \
		> "$work/send.log" 2>&1

	wait "$recv_pid"
	recv_status=$?

	cat "$work/send.log" >&2
	cat "$work/recv.log" >&2

	if [ "$recv_status" -eq 0 ]; then
		echo "ok - a real IPv6 UDP multicast datagram crossed netns A -> bridge -> netns B on port 32027"
	else
		echo "not ok - receiver in namespace B did not observe the multicast datagram sent from namespace A"
		exit 1
	fi
'
