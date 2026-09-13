# Raspberry Pi Records

Dated journals from the September 2026 inspection and repair. They describe
what was observed and done on those dates and are **not updated afterwards**.
For the current state and day-to-day commands, use
[Pi overview](../pi-overview.md) and [operating the Pi](../operations.md).

## Start Here

- <details open> <summary> <b>Start Here</b> </summary>

    | Document | Purpose |
    | --- | --- |
    | [Xfinity setup](network-setup.md) | Current guide: required ports, DHCP/device-selection caveat, and staged verification |
    | [Repair journal](repair-2026-09-12.md) | **Historical.** Player replacement, OAuth, queue/library fixes, exact commands, and rollback notes |
    | [SSH inspection](inspection-2026-09-12.md) | **Historical.** Pre-repair findings, configuration paths, and limits |

  </details>

## Working on the Pi

- <details> <summary> <b>Working on the Pi</b> </summary>

    Use `ssh jcradio-pi '<command>'`. Read-only inspection is always fine.
    Changes to the checkout are routine (pull, or `scp` the same files to the
    same paths). Anything needing `sudo`, package installation, service
    changes, database tasks, or router changes should be a deliberate, recorded
    step with a backup first; see [backups](../operations.md#backups).

    Prefer allowlisted non-secret fields to raw dumps. Full process arguments,
    `.bashrc` launcher functions, and the OAuth files contain credentials.
    Record process names, selected configuration fields, and diagnostic labels
    instead.

    Raw copies of Pi system files are not kept in this repository. Record the
    relevant facts in a dated page, citing the source path, so they can be
    re-read on the Pi. Never commit passwords, OAuth tokens, private keys,
    databases, or unredacted credential-bearing launchers.

  </details>

