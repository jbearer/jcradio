# Data Model

## Core Distinction

- <details> <summary> <b>Core Distinction</b> </summary>

    A **Song** is a reusable track record. A **QueueEntry** is one selection of
    that track by someone for the station. Selecting the same track again can
    create another entry referencing the same song.

    ```mermaid
    erDiagram
        STATION ||--o{ USER : has_members
        STATION ||--o{ QUEUE_ENTRY : has_selections
        USER o|--o{ QUEUE_ENTRY : selects
        SONG ||--o{ QUEUE_ENTRY : appears_in
        USER ||--o{ UPVOTE : gives
        QUEUE_ENTRY ||--o{ UPVOTE : receives
    ```

    This is a conceptual view of the main associations, not a diagram of enforced
    database foreign-key constraints. Some unmatched playback entries have no
    station, selector, or queue position.

  </details>

## Main Records

- <details> <summary> <b>Main Records</b> </summary>

    The [schema](../db/schema.rb) is the reference for tables and columns;
    the models and controllers explain how they are used.

    | Record | Important Fields | Role |
    | --- | --- | --- |
    | [Station](../app/models/station.rb) | `name`, `queue_pos`, `now_playing_id`, `now_playing_start_ms` | Shared queue cursor and current playback metadata |
    | [User](../app/models/user.rb) | `username`, `station_id`, `position`, `subscription`, `last_viewed_chat` | Identity, turn position, notification/chat state |
    | [Song](../app/models/song.rb) | Spotify source/ID/URI, title/artist/album, duration, first/next letter, `last_played`, preview URL | Cached track metadata reused across selections |
    | [QueueEntry](../app/models/queue_entry.rb) | `song_id`, `station_id`, `selector_id`, `position`, `was_recommended` | An individual selection and its place in the queue/history |
    | [Upvote](../app/models/upvote.rb) | `queue_entry_id`, `upvoter_id` | One person's reaction to one selection |
    | [ChatMessage](../app/models/chat_message.rb) | `sender_id`, `song_id`, message, version, timestamps | Conversation optionally associated with the current song |
    | [Notification](../app/models/notification.rb) | `user_id`, text, URL, timestamps | Stored notifications |
    | [Emoji](../app/models/emoji.rb) | name, content type, binary data | Custom emoji stored in the database |
    | [Vapid](../app/models/vapid.rb) | public/private keys | Sensitive web-push key material |

    Other schema tables include fuzzy-search trigrams, sessions, and a `chats`
    table with no model or columns beyond timestamps; the chat implementation
    uses `ChatMessage`.

  </details>

## Queue Cursor and History

- <details> <summary> <b>Queue Cursor and History</b> </summary>

    `QueueEntry.position` orders selections. `Station.queue_pos` is a cursor into
    that sequence. `Station.queue` returns entries at or beyond the cursor;
    `queue_before` also includes a chosen amount of preceding history.

    `Station.now_playing_id` points to a **queue entry**, not directly to a song.
    When Spotify reports a known upcoming song, the reconciliation code moves the
    cursor to that entry, so the current song can remain inside the cursor-based
    queue. The UI's relative index is `entry.position - station.queue_pos`.

    The model does not delete played entries as its normal advancement operation.
    History, letter statistics, and selector/upvote browsing depend on retained
    records. A queue entry has no creation/playback timestamp in the current schema;
    the song's `last_played` field cannot reconstruct every selection's time.

  </details>

## Persistence Limits

- <details> <summary> <b>Persistence Limits</b> </summary>

    - The actual manually submitted next letter is not stored per queue entry.
    - Spotify's live queue is external to SQLite.
    - Personal Spotify sessions, caches, the current assigned letter, and Buddy
      settings are process-local. See [architecture](architecture.md).
    - Emoji uploads and VAPID private keys are database contents, not just files
      in the assets directory. Database backups may contain private material.

  </details>

## Starting Data

- <details> <summary> <b>Starting Data</b> </summary>

    [Seeds](../db/seeds.rb) create four named users and an empty station only in
    development, then create VAPID keys outside that environment guard. They do not
    rebuild historical selections, create Buddy, establish a now-playing entry,
    or produce a complete production installation.

    The Pi's `db/development.sqlite3` is the live, authoritative history (about
    25 MB, roughly 11,000 queue entries). Do not run setup/reset/seed operations
    against it; work on a copy. See [operations](operations.md) for backups.

  </details>

Next: [Architecture](architecture.md).
