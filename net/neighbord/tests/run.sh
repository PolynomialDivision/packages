#!/bin/sh
set -eu

repo_dir="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
daemon="$repo_dir/files/usr/sbin/neighbord"
config="$repo_dir/files/etc/config/neighbord"

fail() {
	echo "not ok - $1" >&2
	exit 1
}

ucode "$daemon" --self-test
ucode "$repo_dir/tests/check_declaration_order.uc" "$daemon"

ipv4_pattern='239\.255|socket\.AF_INET,|socket\.IPPROTO_IP,'
ipv4_pattern="$ipv4_pattern|IP_ADD_MEMBERSHIP|IP_MULTICAST_(IF|TTL)|ipv4-address"
if grep -Eq "$ipv4_pattern" "$daemon"; then
	fail "IPv4 multicast code remains"
fi
[ "$(grep -c 'socket.create(' "$daemon" || true)" -eq 1 ] || fail "transport does not use exactly one socket"
grep -Fq 'socket.create(socket.AF_INET6' "$daemon" || fail "transport socket is not IPv6"
grep -Fq 'const GROUP = "ff12::6e65:6967:6862:6f72:64"' "$daemon" || fail "unexpected multicast group"
grep -Fq '{ multiaddr: GROUP, interface: info.device }' "$daemon" || fail "membership does not use resolved interface"
grep -Fq 'socket.IPV6_MULTICAST_IF, info.device' "$daemon" || fail "outgoing interface is not selected"
grep -Fq 'interface: socket_device' "$daemon" || fail "send address lacks IPv6 scope interface"

grep -Eq 'bind\(\s*"::"\s*,' "$daemon" && fail "bind() uses the broken two-argument form and ignores the port"
grep -Fq 'sk.bind({ address: "::", port: PORT })' "$daemon" || fail "bind() does not explicitly bind the configured port"
grep -Fq 'bus.listener("network.interface"' "$daemon" || fail "no recovery path for network interface recreation"

if grep -Eq 'option (interface|port)|option network .*239\.' "$config"; then
	fail "obsolete or configurable transport setting remains"
fi
config_options="$(grep -c '^[[:space:]]*option ' "$config" || true)"
[ "$config_options" -eq 2 ] || fail "default UCI transport configuration is not minimal"
grep -Fq "option network 'lan'" "$config" || fail "logical network option is missing"

echo "ok - one IPv6 link-local multicast transport uses the resolved interface"
echo "ok - no IPv4 or dual-stack fallback is present"
