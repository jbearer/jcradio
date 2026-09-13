# Xfinity Network Setup

This is a proposed setup guide, not a record of router or Pi changes. The Pi
remains read-only. Port numbers come from the September 12, 2026 SSH inspection;
the app steps come from [Xfinity's official guide](https://www.xfinity.com/support/articles/xfi-port-forwarding),
consulted on the same date.

## Ports for This Installation

- <details open> <summary> <b>Ports for This Installation</b> </summary>

    For the existing direct-hosting design, use individual TCP rules, not a range:

    | Purpose | External Port | Internal Destination | Needed for Listeners? |
    | --- | --- | --- | --- |
    | Website | TCP 3000 | Pi TCP 3000 | Yes, for the queue/game UI outside the LAN |
    | Audio stream | TCP 8000 | Pi TCP 8000 | Yes, if listening directly to Icecast |
    | Remote administration | TCP 10110 | Pi TCP 10110 | No; optional SSH access only |

    The observed wired Pi address is `10.0.0.110`; use that only while it remains
    the address assigned to the chosen Ethernet device. Wi-Fi is a separate
    interface, observed at `10.0.0.145`. Do not attach the rules to the wrong one.

    Website scheme: **HTTPS**, because `jcradio-start` binds Rails with TLS.
    Audio scheme: **HTTP** for the inspected Icecast endpoint. Once services,
    DNS, and forwarding are working, the historical-style URLs would be:

    - `https://jcradio.ddns.net:3000`
    - `http://jcradio.ddns.net:8000/rapi.mp3`

    These are intended addresses, not verified working links. The Pi's SSH
    server listens on 10110, not 22. No UDP forwarding was identified as needed
    for this web/MP3 setup. Spotify outbound connections and No-IP updates do
    not require additional inbound forwarding rules for the inspected design.

    Do not forward all ports, enable DMZ, or expose SSH just to make listening
    work. Ports 80/443 are not required by the current explicit-port URLs;
    future TLS renewal or reverse-proxy choices may have separate requirements.

  </details>

## Before Opening Ports

- <details> <summary> <b>Before Opening Ports</b> </summary>

    The radio is intentionally stopped. Forwarding does not start Rails or
    librespot. First preserve the installation and verify local operation in
    an approved session. The current certificate expired November 27, 2021;
    forwarding cannot repair certificate validation.

    This old app has username-only login and insufficiently separated operational
    controls. Public forwarding exposes those risks. Prefer private network
    access for initial testing, and address authentication, TLS, dependency age,
    and stream access before opening it to the internet. Public SSH forwarding
    is not recommended for this legacy host without a separate security plan.

    Review [recovery notes](../operations.md). No service start, renewal,
    network reconfiguration, or public exposure was performed during inspection.

  </details>

## Static Address Versus Xfinity DHCP

- <details> <summary> <b>Static Address Versus Xfinity DHCP</b> </summary>

    The Pi currently sets Ethernet to `10.0.0.110/24` in `/etc/dhcpcd.conf`,
    with gateway `10.0.0.1`. See the existing
    [network configuration copy](file_copy/dhcpcd.conf).

    Xfinity's guide says its app forwarding works with IPv4 devices using DHCP;
    a device with its own static address may not appear in the device selector.
    A Pi-side static address is different from a gateway DHCP reservation.

    Before changing anything:

    1. Confirm whether the router is an Xfinity gateway managed by the app or a
       personally owned router. The app steps below apply to the former.
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
    4. Choose **Manual Setup**. Add TCP 3000 and TCP 8000 as separate required
       ports, using the same internal/external port where the interface offers
       both fields. Do not open the range 3000 through 8000.
    5. Save/finish with **Next**. Confirm the rules refer to the Pi's current
       IPv4 lease. Leave 10110 closed unless remote administration is explicitly
       needed and appropriately secured.

    If you use your own router behind a modem or bridged gateway, configure the
    router actually performing NAT instead. An extra router can create double
    NAT; that topology has not been checked here.

  </details>

## Verify in Order

- <details> <summary> <b>Verify in Order</b> </summary>

    | Check | What It Establishes |
    | --- | --- |
    | Pi has the intended IPv4 address | Rules target the correct device |
    | Service listening locally | Process is running; forwarding is irrelevant until then |
    | Website and audio work from another LAN device | Local service/bind/firewall path works |
    | DDNS resolves to the current home public IPv4 | Hostname points to the new home, not the old one |
    | Test from a phone on cellular, with Wi-Fi off | Exercises actual outside access rather than relying on NAT loopback |

    For local tests, substitute the current Pi address. HTTPS access by numeric
    IP will not match the certificate's hostname, and this certificate is also
    expired. Diagnose TLS separately from TCP reachability; do not normalize
    disabling certificate checks as the permanent fix.

    The No-IP updater is running, but its update success and the hostname's
    current public resolution were not verified. DDNS updates the public address;
    it does not forward ports or start the website.

    If an outside test is blocked despite a working LAN path, inspect the rule,
    public DNS, NAT topology, and Xfinity Advanced Security. Xfinity documents
    per-device **Allow Access** for trusted blocked sources. Keep security
    enabled; do not disable protection for the whole home to troubleshoot a
    single service. Exact router behavior remains to be verified.

  </details>
