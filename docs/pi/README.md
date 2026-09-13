# Raspberry Pi Evidence

This folder records observations and selected Raspberry Pi system files to
provide a documentation trail for understanding and eventually reproducing the
installation. It is not a full backup.

## Start Here

- <details open> <summary> <b>Start Here</b> </summary>

    | Document | Purpose |
    | --- | --- |
    | [Repair journal](repair-2026-09-12.md) | Approved player recovery, exact commands, checks, and rollback notes |
    | [Pi overview](../pi-overview.md) | High-level setup and current state |
    | [SSH inspection](inspection-2026-09-12.md) | Dated findings, configuration paths, and limits |
    | [Xfinity setup](network-setup.md) | Required ports, DHCP/device-selection caveat, and staged verification |
    | [Recovery checklist](../operations.md) | Preservation and investigation boundaries |

  </details>

## Inspection Rules

- <details> <summary> <b>Inspection Rules</b> </summary>

    Use `ssh jcradio-pi '<command>'`. Keep the Pi read-only until explicitly
    approved otherwise. Do not source unknown shell files, run launchers, elevate
    privileges, install packages, write remote files, or run database tasks.

    Record timestamps and source paths. Distinguish installed software, configured
    startup, running processes, and tested functionality. Ordinary SSH and HTTP
    status reads can create service/access-log entries; this is not bit-for-bit
    preservation.

    Prefer allowlisted non-secret fields to raw dumps. The original proposal's
    full process arguments and cron/script output can expose credentials. The
    actual inspection used process names, selected configuration fields, and
    diagnostic labels instead. Keep raw snapshots and secrets outside commits.

  </details>

## System File Copies

- <details> <summary> <b>System File Copies</b> </summary>

    Raw copies of Pi system files are not kept in this repository. Record the
    relevant facts in the dated inspection or setup pages instead, citing the
    source path (for example `/etc/dhcpcd.conf`) so they can be re-read on the
    Pi. If a copy is ever needed, add a comment at the top with the copy time
    and full source path, and keep it outside the repository.

    Never commit passwords, OAuth tokens, private keys, databases, or unredacted
    credential-bearing launchers. Label redacted excerpts and omissions explicitly;
    do not present them as drop-in replacement configuration. Preserve originals
    privately.

  </details>

