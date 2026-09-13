# Future Hosting

## Status

- <details> <summary> <b>Status</b> </summary>

    **Owner goal:** explore cloud hosting eventually, including its price.
    **Current decision:** no provider, migration design, or budget is selected.
    The radio runs again on the Pi as of September 2026, so there is a working
    baseline to compare against; see [Pi overview](pi-overview.md).

  </details>

## What Must Be Hosted

- <details> <summary> <b>What Must Be Hosted</b> </summary>

    The scope is more than a Rails website:

    - Rails requests and long-lived Server-Sent Event connections.
    - Persistent database storage and private backups.
    - A shared Spotify playback device and its authentication state.
    - ALSA loopback capture, DarkIce MP3 encoding, and Icecast stream delivery,
      or an explicitly chosen replacement for that pipeline.
    - DNS, HTTPS, secrets, supervision, logging, and recovery after reboot.

    See [architecture](architecture.md) and [operating the Pi](operations.md) for
    the known boundaries. Check Spotify's current API access, account requirements,
    and terms for the intended playback/distribution model before choosing a
    deployment design. No service-policy or pricing research has been done.

    [Pi overview](pi-overview.md) records the current 320 kbps MP3 configuration.
    This is a useful future bandwidth input, not a measured usage profile or a
    cloud-price estimate. For home hosting, see
    [Xfinity setup](pi/network-setup.md).

  </details>

## Options to Compare Later

- <details> <summary> <b>Options to Compare Later</b> </summary>

    | Option | Reason to Consider It | Unresolved Constraint |
    | --- | --- | --- |
    | One VM for the existing stack | Closest conceptual match to a single host with local services | Can the audio chain run headlessly there, and be secured and maintained? |
    | Managed Rails service plus separate audio host | Delegates some web operations | Long-lived connections, persistent state, local command calls, and audio integration still need solutions |
    | Keep playback on Pi, move web access elsewhere | Could retain working audio/device configuration | Does not automatically remove home-network dependency; splits a tightly coupled system |

    These are comparison candidates, not recommendations to implement now.

  </details>

## Inputs for a Cost Estimate

- <details> <summary> <b>Inputs for a Cost Estimate</b> </summary>

    Record expected simultaneous listeners, hours per month, stream bitrate,
    required availability, database/backup size, region, and whether the Pi stays
    involved. Estimate audio outbound bandwidth separately from ordinary web/API
    traffic, then compare provider allowances, storage, backup, and transfer costs.
    Include domain and relevant account/subscription costs where applicable.

    An inexpensive Rails plan is not a total-radio price until the audio path is
    included. Conversely, the current four-person use case does not itself imply
    a need for multiple application replicas.

  </details>

## Proposed Sequence

- <details> <summary> <b>Proposed Sequence</b> </summary>

    1. Keep the Pi baseline healthy and backed up.
    2. Confirm which historical features and rules should be preserved.
    3. Define security and dependency updates needed for public exposure.
    4. Compare complete hosting options and measured cost inputs.
    5. Test migration, data restoration, and rollback before retiring the Pi.

    These steps are a proposed investigation order, not approval for a rewrite.

  </details>
