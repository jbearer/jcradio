# JC Radio Documentation

JC Radio is a shared, turn-based radio app. Friends in different locations join
a station, take turns adding songs, and build a queue together. Each selection
also sets the starting-letter constraint for the next selection. The shared
queue is both a listening experience and a collaborative music game.

Formatting follows the [documentation style guide](DOCS_STYLE_GUIDE.md).

## What We Know So Far

- <details> <summary> <b>What We Know So Far</b> </summary>

    - **Owner context:** the usual group was four friends, with the website hosted
      on a Raspberry Pi behind a DDNS address. Listening happened in a separate tab.
    - **Verified in code:** Rails maintains station membership, selection order,
      songs, and queue entries. Adding a track sends it to a shared Spotify player
      and moves the selector to the back of the turn order.
    - **Verified on Pi:** librespot is configured to feed ALSA loopback, then
      DarkIce encodes MP3 for Icecast at `/rapi.mp3`. The radio is currently
      stopped by owner context; the encoder and stream server remain active.
    - **Still to establish:** working end-to-end playback, current external
      access, complete protected configuration, and the newest authoritative data.

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
    | Development | [Development and code map](development.md) | Historical toolchain, source navigation, and verification status |
    | Operations | [Raspberry Pi recovery](operations.md) | Preserve data and recover missing host configuration |
    | Host | [Pi overview](pi-overview.md) | Recovered web/audio setup and current state |
    | Evidence | [Pi inspection records](pi/README.md) | Dated observations and selected configuration copies |
    | Network | [Xfinity setup](pi/network-setup.md) | Forwarding ports, DHCP requirements, and local versus internet access |
    | Future | [Hosting](hosting.md) | Constraints and inputs for a later cloud/cost comparison |
    | Discussion | [Questions and decisions](questions.md) | Open questions, owner corrections, and working decisions |

    Operational notes distinguish repository configuration from configuration that
    must be recovered from the Pi.

    - <details> <summary> <b>Evidence Labels and Scope</b> </summary>

        Throughout these docs:

        - **Verified in code** means an implementation was inspected, not that it was
          successfully exercised against Spotify or the old host.
        - **Owner context** means information supplied by a project participant.
        - **Verified on Pi** means directly observed through read-only SSH or a
          documented status check; configured wiring alone does not prove playback.
        - **Inference** means an interpretation that still needs confirmation.
        - **Open question** means the answer is not yet established.

        This is a recovery-oriented starting point, not a claim that the legacy app
        currently runs. Cloud hosting and pricing are future work, after the runtime
        and audio dependencies are understood.

      </details>

  </details>

## Initial Code Anchors

- <details> <summary> <b>Initial Code Anchors</b> </summary>

    - [Station model](../app/models/station.rb): sends selections to Spotify,
      records queue entries, and tracks the current song.
    - [Stations controller](../app/controllers/stations_controller.rb): checks
      whose turn it is and advances the selection order.
    - [Queue entry model](../app/models/queue_entry.rb): connects a song, station,
      selector, and reactions.
    - [Original README](../README.rdoc): historical setup and deployment notes.

  </details>
