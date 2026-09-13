# Xfinity Network Setup

A setup guide for internet access to the Pi. Port numbers come from the Pi's
actual listeners; the app steps come from
[Xfinity's official guide](https://www.xfinity.com/support/articles/xfi-port-forwarding),
consulted 2026-09-12. Confirmed on 2026-09-13: the gateway at `10.0.0.1`
identifies itself as an Xfinity router, and `jcradio.ddns.net` resolves to the
home's current public IPv4. Whether forwarding rules exist has not been tested
from outside the LAN.

## Ports for This Installation

- <details open> <summary> <b>Ports for This Installation</b> </summary>

    For the existing direct-hosting design, use individual TCP rules, not a range:

    | Purpose | External Port | Internal Destination | Needed for Listeners? |
    | --- | --- | --- | --- |
    | Website | TCP 3000 | Pi TCP 3000 | Yes, for the queue/game UI outside the LAN |
    | Audio stream | TCP 8000 | Pi TCP 8000 | Yes, if listening directly to Icecast |
    | Certificate renewal | TCP 80 | Pi TCP 80 | Indirectly: certbot's HTTP-01 challenge needs it; added 2026-09-13 |
    | Remote administration | TCP 10110 | Pi TCP 10110 | No; optional SSH access only |

    The observed wired Pi address is `10.0.0.110`; use that only while it remains
    the address assigned to the chosen Ethernet device. Wi-Fi is a separate
    interface, observed at `10.0.0.145`. Do not attach the rules to the wrong one.

    Website scheme: **HTTPS**, because `jcradio-web.service` binds Rails with TLS.
    Audio scheme: **HTTP** for the Icecast endpoint. The addresses are:

    - `https://jcradio.ddns.net:3000`
    - `http://jcradio.ddns.net:8000/rapi.mp3`

    Both work from the LAN. The Pi's SSH
    server listens on 10110, not 22. No UDP forwarding is needed
    for this web/MP3 setup. Spotify outbound connections and No-IP updates do
    not require inbound forwarding rules.

    Do not forward all ports, enable DMZ, or expose SSH just to make listening
    work. Port 80 is not used by the URLs above; it exists only so certbot's
    `standalone` challenge can reach the Pi during renewal (nothing listens on
    it otherwise). Port 443 is not required.

  </details>

## Before Opening Ports

- <details> <summary> <b>Before Opening Ports</b> </summary>

    The services run and work on the LAN, so forwarding is the only thing
    between them and the internet. The certificate was renewed on
    2026-09-13 (valid to 2026-12-12); browsers no longer need an override for
    the hostname, though numeric-IP access will still mismatch it.

    This app has username-only login and insufficiently separated operational
    controls. Public forwarding exposes those risks to anyone who finds the
    hostname. Address authentication, TLS, dependency age, and stream access
    before opening it to more than the friend group. Public SSH forwarding
    is not recommended for this legacy host without a separate security plan.

  </details>

## Static Address Versus Xfinity DHCP

- <details> <summary> <b>Static Address Versus Xfinity DHCP</b> </summary>

    The Pi currently sets Ethernet to `10.0.0.110/24` in `/etc/dhcpcd.conf`,
    with gateway `10.0.0.1` and DNS `10.0.0.1, 8.8.8.8`; `eth0` has metric 100
    and `wlan0` metric 200.

    Xfinity's guide says its app forwarding works with IPv4 devices using DHCP;
    a device with its own static address may not appear in the device selector.
    A Pi-side static address is different from a gateway DHCP reservation.

    Before changing anything:

    1. The router is an Xfinity gateway, so the app steps below apply.
    2. Identify the Pi's Ethernet device entry and its MAC address privately;
       do not confuse it with the Pi's Wi-Fi entry.
    3. Check whether the gateway supports a DHCP reservation for that Ethernet
       device and whether `10.0.0.110` can be reserved without conflict. Reservation
       controls vary; their availability on this gateway has not been inspected.
    4. Plan an explicit transition from Pi-side static configuration to DHCP,
       preferably with physical access and a recovery path. Confirm the resulting
       lease before creating forwards or updating the local SSH alias.

    This guide does not prescribe blindly deleting the static settings over SSH.
    The IP may change and disconnect the session. The old `192.*` and new `10.*`
    addresses are LAN addresses; use the actual new Pi lease in the new router,
    not an old network's destination.

  </details>

## Add Rules in the Xfinity App

- <details> <summary> <b>Add Rules in the Xfinity App</b> </summary>

    After local service/security checks and device addressing are resolved:

    1. Sign in to the Xfinity app with an authorized account.
    2. Go to **WiFi > View WiFi equipment > Advanced Settings > Port forwarding**.
    3. Select **Add Port Forward**, then continue and select the Pi's Ethernet
       device. Xfinity associates the rule with a device, rather than just an
       arbitrary typed destination IP.
    4. Choose **Manual Setup**. Add TCP 80, TCP 3000, and TCP 8000 as separate
       required ports, using the same internal/external port where the interface
       offers both fields. Do not open the range 80 through 8000.
    5. Save/finish with **Next**. Confirm the rules refer to the Pi's current
       IPv4 lease. Leave 10110 closed unless remote administration is explicitly
       needed and appropriately secured.

    If you use your own router behind a modem or bridged gateway, configure the
    router actually performing NAT instead. An extra router can create double
    NAT; that topology has not been checked here.

  </details>

## Verify in Order

- <details> <summary> <b>Verify in Order</b> </summary>

    | Check | What It Establishes | Status 2026-09-13 |
    | --- | --- | --- |
    | Pi has the intended IPv4 address | Rules target the correct device | `10.0.0.110` static on `eth0` |
    | Service listening locally | Process is running; forwarding is irrelevant until then | 3000 and 8000 listening |
    | Website and audio work from another LAN device | Local service/bind/firewall path works | Yes, from the laptop |
    | DDNS resolves to the current home public IPv4 | Hostname points to the new home, not the old one | Yes |
    | Inbound forwarding works at all | Let's Encrypt reached the Pi on TCP 80 during renewal | Yes, 2026-09-13 |
    | Test from a phone on cellular, with Wi-Fi off | Exercises actual outside access to 3000/8000 rather than relying on NAT loopback | **Not tested** |

    For local tests, substitute the current Pi address. HTTPS access by numeric
    IP will not match the certificate's hostname. Diagnose TLS separately from
    TCP reachability; do not normalize disabling certificate checks as the
    permanent fix.

    DDNS updates the public address; it does not forward ports or start the
    website.

    If an outside test is blocked despite a working LAN path, inspect the rule,
    public DNS, NAT topology, and Xfinity Advanced Security. Xfinity documents
    per-device **Allow Access** for trusted blocked sources. Keep security
    enabled; do not disable protection for the whole home to troubleshoot a
    single service. Exact router behavior remains to be verified.

  </details>
