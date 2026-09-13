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
    | [SSH planning notes](Pi_SSH_Intructions.txt) | Original proposal, not a record of executed commands |
    | [Network copy](file_copy/dhcpcd.conf) | Existing timestamped copy of `/etc/dhcpcd.conf` |
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

## file_copy

- <details> <summary> <b>file_copy</b> </summary>

    For a safe file copy, add a comment at the top with the copy time and full
    source path, using the file format's comment syntax. Preserve the rest of
    the file when it contains no secrets.

    Example for [the existing network copy](file_copy/dhcpcd.conf):

    ```text
    # Copied: 2026-09-12 12:53 PDT
    # Full Path: /etc/dhcpcd.conf

    ... the rest of the actual file
    ```

    Never commit passwords, OAuth tokens, private keys, databases, or unredacted
    credential-bearing launchers. Label redacted excerpts and omissions explicitly;
    do not present them as drop-in replacement configuration. Preserve originals
    privately.

    The existing network copy was not modified. No new raw configuration copies
    or database backups were made during the SSH inspection.

  </details>

