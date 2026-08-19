# neighbord

`neighbord` is a deliberately small OpenWrt daemon that synchronizes 802.11k
Neighbor Reports between local `hostapd.*` BSSes and other OpenWrt APs on the
same link. Reports are shared only between BSSes with exactly the same SSID.
The resulting lists are installed through hostapd's ubus API.

neighbord uses IPv6 link-local UDP multicast between APs. No IPv4 transport or
fallback is implemented.

It does not steer stations, score APs, measure RSSI, kick clients, or implement
any roaming policy. Accurate Neighbor Reports can reduce unnecessary candidate
discovery for clients which use them; they do not guarantee that a client will
never scan.

## Hostapd API used

The current OpenWrt hostapd API represents one Neighbor Report as a three-string
array:

```json
["b6:a7:b9:cb:ee:bc", "example-ssid", "b6a7b9cbeebcaf5900008095090603029b00"]
```

`neighbord` uses these methods:

```sh
ubus call hostapd.<interface> get_status
ubus call hostapd.<interface> rrm_nr_get_own
ubus call hostapd.<interface> rrm_nr_set '{"list": [...]}'
ubus call hostapd.<interface> rrm_nr_list
```

The own value is transported unchanged. Hostapd preserves its own entry when
`rrm_nr_set` replaces the other entries, and `rrm_nr_list` displays only the
other BSSes. Consequently neighbord excludes a BSS from the list sent back to
that same BSS, matching hostapd and usteer behavior.

## Requirements and installation

The package depends only on:

- `ucode`
- `ucode-mod-ubus`
- `ucode-mod-uloop`
- `ucode-mod-socket`
- `ucode-mod-uci`

Copy this directory into an OpenWrt source tree, for example as
`package/network/services/neighbord`, then build it:

```sh
make menuconfig                  # select Network -> neighbord
make package/neighbord/compile V=s
```

Copy the resulting `.apk` to an AP running a current OpenWrt snapshot and
install it with `apk add --allow-untrusted /tmp/neighbord-*.apk`. On older
OpenWrt releases which still use opkg, build in that release's SDK and use
`opkg install /tmp/neighbord_*.ipk`. The init script is enabled normally:

```sh
/etc/init.d/neighbord enable
/etc/init.d/neighbord start
```

## Configuration

`/etc/config/neighbord` contains one small section:

```text
config neighbord 'main'
        option enabled '1'
        option network 'lan'
```

`network` is an OpenWrt logical network name, not a Linux device name.
`neighbord` resolves it through `network.interface.<name> status`, obtains the
`l3_device` (for example `br-lan`), and uses that device's interface index for
IPv6 multicast membership, transmission, and destination scope. It does not
need or inspect a globally routable IPv6 address.

The multicast group, address family, and port are fixed. The interface index
is resolved from `l3_device`; none of these are UCI options.

Announcements are sent every 30 seconds and peers expire after 90 seconds.
Optional `interval`, `timeout`, and `debug` settings remain available for
testing and troubleshooting, but are omitted from the normal configuration.
A timeout shorter than twice the interval is replaced at runtime with three
times the interval. Changing the UCI file through `uci commit neighbord`
triggers a procd-managed restart.

## Protocol

Each UDP datagram goes to `[ff12::6e65:6967:6862:6f72:64]:32027` through the
configured network device with multicast hop limit 1. `ff12` marks a transient
link-local-scope IPv6 multicast group. Link-local scope is used because peers
only need to communicate on the directly attached management/LAN segment; the
traffic must not be routed beyond that link. The payload remains a small JSON
object:

```json
{
  "version": 1,
  "node": "02:00:00:00:00:01",
  "reports": [
    ["02:00:00:00:00:01", "example-ssid", "0200000000018f000000510603010000"]
  ]
}
```

`node` is the lowest local BSSID and identifies the announcing peer. Only
reports obtained from local `rrm_nr_get_own` calls are sent. Learned reports
are never re-advertised.

Input is limited to 8192 bytes, 64 reports per peer, and 64 live peers. At most
64 deterministic, deduplicated entries are installed per BSS. The daemon checks
the protocol version, node and BSSID syntax, SSID length, Neighbor Report hex
syntax and length, and consistency between the report body and its BSSID.
There is no authentication; the multicast link is expected to be a trusted
management/LAN network.

## Debugging

Discover the actual BSS object names and inspect their signatures:

```sh
ubus list 'hostapd.*'
ubus -v list hostapd.<interface>
ubus call hostapd.<interface> get_status
ubus call hostapd.<interface> rrm_nr_get_own
ubus call hostapd.<interface> rrm_nr_list
logread -e neighbord
```

Set `neighbord.main.debug=1` only while troubleshooting malformed packets or
socket setup. With debug enabled, `ensure_socket()` logs the resolved
network, device, multicast group and port once when the transport comes up:

```sh
uci set neighbord.main.debug='1'
uci commit neighbord
```

### Verifying the network transport on two real APs

Run these on both `AP1` and `AP2`, both on the same LAN, to check the
transport independently of hostapd. Substitute the `l3_device` shown by:

```sh
ubus call network.interface.lan status
```

for `br-lan` below if it differs (VLAN-backed or non-default network names
resolve to something else).

1. **Interface exists and is up:**

   ```sh
   ubus call network.interface.lan status
   ip link show br-lan
   ip -6 addr show br-lan
   ```

2. **neighbord has joined the multicast group on the right device:**

   ```sh
   ip -6 maddr show dev br-lan
   ```

   Expect an entry for `ff12:0:6e65:6967:6862:6f72:64` (the expanded form of
   `ff12::6e65:6967:6862:6f72:64`) under `br-lan`'s `inet6` list. If it is
   missing, neighbord never reached `IPV6_ADD_MEMBERSHIP` successfully;
   check `logread -e neighbord` for a socket setup failure.

3. **neighbord is bound to the right port:**

   ```sh
   ss -6 -u -a -n | grep 32027
   ```

   Expect `*:32027` (or `[::]:32027`). If nothing is listening on 32027,
   the daemon is not running or its socket setup failed — check `logread`.

4. **Outgoing announcements leave the interface.** On AP1:

   ```sh
   tcpdump -ni br-lan -vv 'ip6 and udp port 32027'
   ```

   Expect one `AP1-link-local -> ff12::6e65:6967:6862:6f72:64.32027` UDP
   packet every `interval` seconds (30s by default).

5. **Packets arrive on AP2's wire.** Run the same `tcpdump` command on AP2
   at the same time. If AP1's packets show up in AP1's own capture but never
   in AP2's, the break is between the two APs (switch/VLAN/multicast
   snooping), not in neighbord.

6. **AP2's socket actually receives them.** With debug enabled and
   `logread -f -e neighbord` running on AP2, a changed announcement logs
   `learned N remote BSSes`; unchanged repeats do not log anything (by
   design, to avoid spamming). If tcpdump sees the packet on AP2 but nothing
   is ever logged, the payload is reaching the wire but not the socket, or
   the socket is bound to a stale/mismatched interface.

7. **Malformed input is rejected without killing the daemon:**

   ```sh
   printf 'not-json' | nc -u -w 1 'ff12::6e65:6967:6862:6f72:64%br-lan' 32027
   ```

   The process must remain running; with debug enabled, exactly one
   rejection is logged.

This isolates the failure modes in order: (A) nothing captured on AP1's own
`br-lan` means neighbord is not sending; (B) AP1's capture shows the packet
but AP2's capture does not means `br-lan`/the switch is not forwarding it;
(C) AP2's capture shows it but nothing is logged means the socket on AP2
is not receiving it (wrong interface/port/membership); (D) it is logged as
rejected means the payload reached the socket but failed validation; (E) it
is logged as learned but `rrm_nr_list` never updates means the hostapd side
of the pipeline, not the transport, is the problem.

### Firewall and bridging

No firewall rule is needed for the default OpenWrt configuration: this is a
host-local socket receiving on `br-lan`, handled by the `INPUT` chain of the
interface's firewall zone (`lan` by default), and stock OpenWrt sets that
zone's input policy to `ACCEPT`. Only a zone whose input policy was changed
away from the default would need an explicit rule, and that is a
site-specific firewall decision, not something this package should impose.

A locally joined IPv6 multicast group is always delivered to the joining
host's own stack regardless of MLD querier presence — this does not depend
on Linux bridge multicast snooping timers. The one real caveat: if the two
APs are connected through an *intermediate managed switch* that performs
its own independent IGMP/MLD snooping with no querier on the segment, that
switch's forwarding state for the group can expire and start dropping the
traffic between its ports. That is outside neighbord's and the AP's own
bridge's control; the fix is on the switch (enable a querier, or disable
snooping for that VLAN), not in neighbord.

## Tests without Wi-Fi hardware

On a development system with ucode installed, run:

```sh
./tests/run.sh
```

The embedded self-test exercises SSID scoping, local and remote merging,
self-exclusion, packet round trips, expiry, malformed input, duplicate input,
local-only advertisement, and deterministic lists. The test wrapper also
checks that there is exactly one IPv6 socket, that the resolved interface is
used for membership and destination scope, and that no IPv4 fallback remains.
The embedded part can also be run on an AP:

```sh
/usr/sbin/neighbord --self-test
```

None of the above touches a real socket. `tests/network_integration.sh`
additionally proves the actual transport calls work: it creates two Linux
network namespaces joined by a bridge (one veth pair per side), the same
topology as two separate hosts on one L2 segment, and runs
`tests/mcast_probe.uc` — a small standalone tool built from the exact same
socket calls as `ensure_socket()`/`announce_local_reports()` — in each
namespace to confirm a real IPv6 UDP multicast datagram sent from one
namespace on port 32027 is actually received in the other:

```sh
./tests/network_integration.sh
```

It needs unprivileged user+network namespaces (`unshare --user --net`); if
the host does not permit that, it prints `skip -` and exits 0 rather than
failing.

## Manual verification

Use the actual object names returned by `ubus list 'hostapd.*'` in every command.

1. **Two local BSSes, same SSID.** Start neighbord, obtain each BSS's own value
   with `rrm_nr_get_own`, then call `rrm_nr_list` on both. Each list should
   contain the other BSS and should not contain itself.

2. **Different SSIDs.** Configure another BSS with a different SSID. Its
   `rrm_nr_list` must not contain reports from the first SSID.

3. **Two APs.** Install and start neighbord on both APs with `network` pointing
   at the same L2 segment and with the same SSID. Within one announce interval,
   each AP's `rrm_nr_list` should contain the other AP's same-SSID BSSes.

4. **Peer expiry.** Stop neighbord on AP 2:

   ```sh
   /etc/init.d/neighbord stop
   ```

   After the configured timeout plus the five-second expiry tick, AP 1 should
   log `peer ... expired`, and its `rrm_nr_list` should no longer contain AP 2.

5. **Wi-Fi reload.** Start AP 2 again, wait for convergence, run `wifi reload`
   on AP 1, and query `rrm_nr_list` after the hostapd objects return. The object
   add listener normally restores the list immediately; the 15-second
   reconciliation timer is the fallback.

6. **Daemon restart.** Run `/etc/init.d/neighbord restart`. The initial
   reconciliation should repopulate every same-SSID list.

7. **Malformed UDP.** With an IPv6-capable `nc`, send a bad datagram through the
   correct scoped interface (replace `br-lan` as needed):

   ```sh
   printf 'not-json' | nc -u -w 1 'ff12::6e65:6967:6862:6f72:64%br-lan' 32027
   ```

   The process must remain running. With debug enabled, one rejection is logged.

8. **Duplicate announcements.** Capture one valid JSON datagram, duplicate one
   report inside its `reports` array, and send it with `nc -u`. `rrm_nr_list`
   should contain that BSSID only once.

9. **No advertisement loop.** Capture AP 1 announcements with `tcpdump -A` and
   compare them with AP 1's local `rrm_nr_get_own` values. Reports learned only
   from AP 2 must appear in AP 1's installed `rrm_nr_list`, but never in AP 1's
   outgoing `reports` array.

10. **No needless writes.** Follow the log across at least two announcement
    intervals:

    ```sh
    logread -f -e neighbord
    ```

    With unchanged peers, no additional `updated neighbor list` messages should
    appear. A message corresponds to a successful `rrm_nr_set`; repeated
    announcements merely refresh peer expiry time.
