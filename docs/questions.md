# Open Questions and Decisions

Initial documentation pass: **2026-09-12**.

Use stable question IDs so answers can be incorporated into the relevant page
without losing track of what is confirmed. An observed implementation is not
automatically the intended product rule.

## Owner Context Already Supplied

- <details> <summary> <b>Owner Context Already Supplied</b> </summary>

    - JC Radio is a collaborative radio for friends in different locations.
    - The usual group was four people rotating song selections under a letter rule.
    - A Raspberry Pi served the website behind a DDNS address.
    - Listening happened in another tab while people used the queue/search UI.
    - Pi/router setup has become difficult after moving.
    - Cloud hosting and pricing are later investigations, not this pass's scope.
    - Follow-up: the radio is currently stopped; Austin normally starts it with
      `jcradio-start` and believes port forwarding is not configured on the new
      Xfinity `10.0.*` network, replacing the earlier `192.*` home network.

  </details>

## Questions for the Next Conversation

- <details> <summary> <b>Questions for the Next Conversation</b> </summary>

    | ID | Question | Why It Matters |
    | --- | --- | --- |
    | Q1 | Was the listening tab directly on `/rapi.mp3`, or a separate player page? | Pi inspection confirms librespot, ALSA loopback, DarkIce, and Icecast; exact historical browser workflow remains open |
    | Q2 | Are the documented title rules right, especially the fourth-from-last rule for one-word titles? Were wrong-letter and next-letter overrides intentional house rules? | Separates intended rules from implementation quirks |
    | Q3 | Is the Pi's approximately 25 MB development database the newest history? Are there other backups or newer working copies? | File presence and size are verified; contents and authority were not checked |
    | Q4 | Was a new participant meant to join immediately after the current selector, or at the end of the line? | The login code currently inserts after the first selector |
    | Q5 | Which features did you regularly use, and which were experiments: Buddy, recommendations, plots, chat, previews, library saving? | Prioritizes what must work when reviving the app |
    | Q6 | Was the shared Spotify account separate from everyone's personal accounts, and who owns the developer app? | Determines account and OAuth recovery steps; no credential values needed |
    | Q7 | Was queueing while playback was stopped reliable? How did you start the very first song or recover an empty queue? | The code makes populated-station and active-player assumptions |
    | Q8 | Should revival remain a private friends-only station, or eventually support more people or separate stations? | Sets future security, state-isolation, and hosting requirements |
    | Q9 | Is the router an Xfinity app-managed gateway or a personally owned router, and can it reserve an IPv4 DHCP lease for the Pi? | Xfinity's documented forwarding requires DHCP, while the current Pi Ethernet configuration is static |

  </details>

## Documentation Decisions

- <details> <summary> <b>Documentation Decisions</b> </summary>

    | ID | Decision | Status |
    | --- | --- | --- |
    | D1 | Use JC Radio as the short name and Jingle Churro Radio as the interface's expanded name | Working terminology; owner can correct |
    | D2 | Organize docs from product overview to architecture, workflows/rules, data, and operations | Adopted for this draft |
    | D3 | Label owner context, inspected behavior, inference, and open questions separately | Adopted for this draft |
    | D4 | Preserve the original README's historical notes rather than silently replacing them with an untested setup recipe | Adopted for this draft |
    | D5 | Defer cloud provider/pricing selection and application changes until recovery questions are answered | Scope of this pass |
    | D6 | Inspect the Pi only through read-only SSH, preserving local changes and withholding secrets | Owner-authorized inspection completed; no repairs or router changes made |

    See [Pi observations](pi/inspection-2026-09-12.md) and the
    [Xfinity guide](pi/network-setup.md) for newly established facts and proposed
    setup steps. Router instructions are not authorization to reconfigure the Pi.

  </details>

## How to Update This Record

- <details> <summary> <b>How to Update This Record</b> </summary>

    When an answer arrives, update the owning page and note the answer here with
    its source: owner recollection, a specific code path, or an observed Pi/runtime
    check. Keep intended behavior distinct from current behavior when they differ.

    Do not put passwords, OAuth tokens, client secrets, private keys, database dumps,
    or unredacted service configurations in this folder.

  </details>
