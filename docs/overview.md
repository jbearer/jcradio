# Product Overview

## In One Sentence

JC Radio is a shared radio and a turn-based music game: friends build one
Spotify-backed queue, with each song handing a starting letter to the next
person.

The interface calls it **Jingle Churro Radio**. This documentation uses
**JC Radio** as the short name.

## A Typical Session

- <details> <summary> <b>A Typical Session</b> </summary>

    1. Join the website under your username.
    2. See who is next to choose, their assigned letter, and the current queue.
    3. Search Spotify or browse a collection for a suitable song.
    4. On your turn, confirm a song and the letter it passes to the next person.
    5. Your selection goes into the shared queue, and you move to the back of the
       selection order.
    6. Listen, see what others choose, react to songs, chat, and repeat.

    **Owner context:** the regular group was four friends in different locations.
    The website ran on a Raspberry Pi using a DDNS address, and people listened in
    a separate tab. [Pi inspection](pi-overview.md) recovered a configured
    librespot-to-ALSA-to-DarkIce-to-Icecast stream. The exact historical tab URL
    and current audible playback still need confirmation.

  </details>

## Two Different Orders

- <details> <summary> <b>Two Different Orders</b> </summary>

    The **selection order** is the line of people waiting to add songs. The **song
    queue** is the line of selections waiting to play, along with retained history.
    Adding a song advances the selection order immediately; it does not wait for
    that song to finish playing.

    The assigned letter follows the latest selection at the end of the queue, not
    necessarily the track currently playing. People can build the queue ahead of
    playback.

  </details>

## Feature Map

- <details> <summary> <b>Feature Map</b> </summary>

    These features have implementations in the repository. That does not establish
    that their external integrations still work today.

    | Area | What It Provides | Code Entry Point |
    | --- | --- | --- |
    | Home | Username login, shared Spotify login, personal Spotify linking, player startup | [Sessions controller](../app/controllers/sessions_controller.rb) |
    | Queue | Song order, recent history, selector names, current track and timing | [Station page](../app/views/stations/show.html.erb) |
    | Browse | Spotify search, saved library, previously chosen and upvoted songs, letter filters | [Songs controller](../app/controllers/songs_controller.rb) |
    | Recommendations | Spotify suggestions based on seeds and audio features | [Recommendations controller](../app/controllers/recommendations_controller.rb) |
    | Buddy | Automated selector using configured song collections | [Stations controller](../app/controllers/stations_controller.rb) |
    | Social | Chat, custom emoji, upvotes, and notifications | [Routes](../config/routes.rb) |
    | Plots | Letter frequencies, letter transitions, and title-word analysis | [Plots page](../app/views/stations/plots.html.erb) |
    | Playback controls | Skip, refresh current-track state, save a track to personal Spotify | [Stations controller](../app/controllers/stations_controller.rb) |

  </details>

## Rules and Flexibility

- <details> <summary> <b>Rules and Flexibility</b> </summary>

    Turn order is checked on the server. Starting-letter mismatches and recent
    repeats produce browser warnings, not hard rejection. The confirmation dialog
    also permits editing the letter passed onward. See [letter rules](letter-rules.md).

  </details>

## What This Is Not Yet

- <details> <summary> <b>What This Is Not Yet</b> </summary>

    - Not a verified general-purpose, multi-station service: central paths use
      station ID `1` and process-wide state.
    - Not a self-contained audio streaming implementation: Rails controls a
      Spotify player, while the listening stream uses separate Pi audio services.
    - Not a ready-to-deploy cloud application: the old runtime, local commands,
      credentials, and audio chain need recovery and validation first.

  </details>

Next: [Architecture](architecture.md).
