# JC Radio Documentation

JC Radio is a shared, turn-based radio app. Friends in different locations join
a station, take turns adding songs, and build a queue together. Each selection
also sets the starting-letter constraint for the next selection. The shared
queue is both a listening experience and a collaborative music game.

Formatting follows the [documentation style guide](DOCS_STYLE_GUIDE.md).

## Current State

- <details open> <summary> <b>Current State</b> </summary>

    Checked on the Pi on **2026-09-13**. The radio works end to end again after
    the September 12 repair; see [Pi overview](pi-overview.md) for details.

    - **Website:** Rails runs on the Pi with HTTPS on port 3000, started by the
      owner's `jcradio-start` shell function. The checkout is `atc/dev`.
    - **Player:** a current librespot (0.8.0) runs as the `jcradio-player`
      systemd service and restarts on failure and reboot. The original 2020
      binary and launchers are preserved but no longer used.
    - **Stream:** librespot feeds ALSA loopback, DarkIce encodes 320 kbps MP3,
      Icecast serves `/rapi.mp3`. Listening happens in a separate tab.
    - **Data:** the Pi's development SQLite database is the live, authoritative
      history; it received writes today. A backup from before the repair is on
      the Pi under `~/jcradio-recovery/2026-09-12`.
    - **HTTPS:** the `jcradio.ddns.net` certificate was renewed on 2026-09-13
      after four years expired; certbot now renews it automatically and a
      deploy hook restarts Rails. Browsers load the site without an override.
    - **Tests:** `bin/rake test` on the Pi passes (24 runs, 90 assertions).

    Still outstanding: see [Open Items](#open-items).

  </details>

## How to Read These Docs

- <details open> <summary> <b>How to Read These Docs</b> </summary>

    | Level | Start Here | Purpose |
    | --- | --- | --- |
    | Product | [Overview](overview.md) | What the app is and how a session feels |
    | System | [Architecture](architecture.md) | Website, Spotify, live updates, and external audio |
    | Rules | [Letter rules](letter-rules.md) | Exact title normalization, examples, and overrides |
    | Behavior | [Workflows](workflows.md) | Login, queueing, search, recommendations, Buddy, and social features |
    | Data | [Data model](data-model.md) | Records, queue history, and persistence limits |
    | Development | [Development and code map](development.md) | Toolchain, source navigation, and how to run the tests |
    | Operations | [Operating the Pi](operations.md) | Start, check, back up, and troubleshoot the running installation |
    | Host | [Pi overview](pi-overview.md) | Current web/audio setup on the Pi |
    | Network | [Xfinity setup](pi/network-setup.md) | Forwarding ports, DHCP requirements, and local versus internet access |
    | Future | [Hosting](hosting.md) | Constraints and inputs for a later cloud/cost comparison |
    | History | [Pi records](pi/README.md) | Dated inspection and repair journals from September 2026 |

    Pages marked **Historical** describe a specific past date and are kept as a
    record; they are not updated to reflect later changes.

    - <details> <summary> <b>Evidence Labels and Scope</b> </summary>

        Throughout these docs:

        - **Verified in code** means an implementation was inspected, not that it was
          successfully exercised against Spotify or the old host.
        - **Owner context** means information supplied by a project participant.
        - **Verified on Pi** means directly observed through SSH or a documented
          status check on the stated date.
        - **Inference** means an interpretation that still needs confirmation.

        Cloud hosting and pricing remain future work.

      </details>

  </details>

## Open Items

- <details> <summary> <b>Open Items</b> </summary>

    Work that is known to be pending as of 2026-09-13. Remove items here when done.

    | Item | Why | Needs |
    | --- | --- | --- |
    | Reboot the Pi and re-verify | The 2026-09-13 `apt upgrade` replaced `libc6`, `systemd`, and DarkIce (now 1.3) under running processes; `/var/run/reboot-required` is set | A quiet moment, then `jcradio-start` and the stream checks in [operations](operations.md#routine-commands) |
    | Confirm outside access | DDNS resolves to the current public address, but reachability from outside the LAN was not tested | A phone on cellular, see [network setup](pi/network-setup.md) |
    | Watch the first automatic renewal | The certbot deploy hook that restarts Rails was tested by hand on 2026-09-13, not yet by `certbot.timer` | Around 2026-11-12, check `/var/log/jcradio-cert-deploy.log` and the served certificate; see [operations](operations.md#routine-commands) |
    | Product-rule confirmation | Whether the one-word next-letter rule and join-after-first-selector behavior are intended house rules | Owner decision; see [letter rules](letter-rules.md) and [workflows](workflows.md) |

  </details>

## Code Anchors

- <details> <summary> <b>Code Anchors</b> </summary>

    - [Station model](../app/models/station.rb): sends selections to Spotify,
      records queue entries, and tracks the current song.
    - [Stations controller](../app/controllers/stations_controller.rb): checks
      whose turn it is and advances the selection order.
    - [Queue entry model](../app/models/queue_entry.rb): connects a song, station,
      selector, and reactions.
    - [Original README](../README.rdoc): historical setup and deployment notes.

  </details>
