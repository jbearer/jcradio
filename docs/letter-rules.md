# Letter Rules

## Meaning

- <details> <summary> <b>Meaning</b> </summary>

    - **Assigned letter:** the letter the next selector is asked to start with.
    - **First letter:** the computed starting letter of a candidate song title.
    - **Next letter:** the letter a selected song passes to the next selector.

    The assigned letter advances when a song is added, not when it starts playing.
    The Ruby implementation is in [SongsHelper](../app/helpers/songs_helper.rb).

  </details>

## Title Normalization

- <details> <summary> <b>Title Normalization</b> </summary>

    The implementation:

    1. Converts the title to uppercase.
    2. Removes the text between the first `(` and first `)`, when both exist.
       This is not a general parser for multiple or nested parenthetical groups.
    3. Discards text from the first hyphen or en dash onward.
    4. Removes characters other than ASCII `A` through `Z` and spaces. Punctuation
       is deleted, not replaced with spaces; digits and accented letters are not
       transliterated.
    5. Splits into words.
    6. Removes one leading article from `THE`, `A`, `AN`, `UN`, `UNE`, `LE`, `LES`.

    The first letter is the first character of the first remaining word. If none
    remains, it is `_`.

  </details>

## Computing the Next Letter

- <details> <summary> <b>Computing the Next Letter</b> </summary>

    For multiple words, use the first character of the last remaining word.

    For one word, the code uses `(4 % word.length) * -1` as a Ruby array index.
    For words longer than four letters this is the fourth character from the end.
    For short words, the exact results are:

    | Word Length | Chosen Character |
    | --- | --- |
    | 1 | First |
    | 2 | First |
    | 3 | Last |
    | 4 | First |

    For no remaining words, or an exception during next-letter calculation, it
    chooses a random letter from `A` through `Z`. These are the code's rules;
    whether the short-word cases match the group's intended house rules has not
    been confirmed by the owner.

  </details>

## Examples

- <details> <summary> <b>Examples</b> </summary>

    | Title | Normalized Words | First Letter | Next Letter |
    | --- | --- | --- | --- |
    | The Sound of Silence (Live) - Remastered | SOUND OF SILENCE | S | S |
    | Move Like You Want - Live | MOVE LIKE YOU WANT | M | W |
    | Radio | RADIO | R | A |
    | Love | LOVE | L | L |
    | ABC | ABC | A | C |
    | AB | AB | A | A |
    | X | X | X | X |
    | 123 | No words | _ | Random A-Z |

  </details>

## Warnings and Overrides

- <details> <summary> <b>Warnings and Overrides</b> </summary>

    The [selection dialog](../app/views/songs/_search_results.html.erb):

    - Warns when the song's first letter differs from the assigned letter, unless
      either is `_`.
    - Warns when `last_played` is within two days. The add-song controller writes
      this timestamp when a song is selected, so it is not a precise playback log.
    - Allows confirmation despite those warnings.
    - Prefills an editable next-letter input using the song's stored value.

    [StationsController#update](../app/controllers/stations_controller.rb) enforces
    whose turn it is, but does not independently reject a starting-letter mismatch.
    [Station#advance_turn](../app/models/station.rb) stores the assigned letter on
    the station from the first character of the submitted next-letter value,
    upcased, or the song's own `next_letter` when none was submitted. This is not
    strict `A-Z` validation.

    The override changes the current handoff, not the song's stored `next_letter`
    or a separate per-entry letter record. Historical plots therefore cannot be
    assumed to reconstruct every manual override.

  </details>

## Stored Values Versus Recalculation

- <details> <summary> <b>Stored Values Versus Recalculation</b> </summary>

    Song records store `first_letter` and `next_letter`. The Spotify conversion
    helper reuses existing records without recalculating those fields. Some browse
    paths filter stored values, while personal-library browsing recalculates the
    first letter from the title. The plots page also contains its own JavaScript
    normalization. Changes to one implementation do not automatically update all
    old data and views.

    Before changing these rules, agree on the intended examples and decide how to
    handle historical records.

  </details>
