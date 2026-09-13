# Documentation Style Guide

## Collapsible Sections (`<details>`)

- <details> <summary> Rules </summary>

    - Use `<details>` liberally — readers should see a scannable page, not a wall of text
    - **`<summary>` must be on the same line as `<details>`** — when collapsed in source, you see the title:
      ```
      - <details> <summary> Docker Setup </summary>   ← collapsed: visible title
      ```
      vs.
      ```
      - <details>                                      ← collapsed: no context
      ```
    - Nest `<details>` for levels of abstraction (standard → advanced → edge cases)
    - Use `<details open>` sparingly — only for sections that should default-expand (e.g. Quick Start)

  </details>

---

## Source-Code Foldability (List-Item Pattern)

- <details> <summary> Why use <code>- &lt;details&gt;</code>? </summary>

    VS Code folds markdown by **headings** and **indentation**. A bare `<details>` block at root level is not foldable in the editor. Wrapping it in a list item (`- <details>`) forces indentation → foldable source code.

    **Template:**
    ```markdown
    ## Section Heading

    - <details> <summary> Section Heading </summary>

        Content here (indented 4 spaces under the list item).

        - <details> <summary> Nested Sub-Section </summary>

            Deeper content (indented 8 spaces).

          </details>

      </details>
    ```

    **Result:** Both source-code folding (via indentation) and rendered collapsibility (via `<details>`).

    **Note**: You can selectively decide not to indent, but do so sparingly (I sometimes like having the details not under a bullet in a section, and will tolerate the lack of source-code-foldability)

  </details>

---

## Headings

- <details> <summary> Heading conventions </summary>

    - `##` headings provide structure, TOC anchors, and source-level folding
    - Yes, the heading text will often **duplicate** the `<summary>` text — this is intentional:
      - Heading = always-visible anchor / TOC entry
      - Summary = collapse toggle in rendered output
    - Use `<b>` in summary for visual weight: `<summary><b>Section Title</b></summary>`
    - Don't go deeper than `###` in a README — use nested `<details>` instead

  </details>

---

## General Formatting

- <details> <summary> Quick rules </summary>

    - Tables for structured data (commands, arguments, directories)
    - Code blocks with language tags (` ```bash `, ` ```cpp `)
    - Blank line after `<summary>` line, before content
    - Closing `</details>` at same indent as opening `<details>`
    - No `<br>` hacks — blank lines handle spacing

  </details>

---

## Copy-Paste Template

```markdown
## Section Title

- <details> <summary> <b>Section Title</b> </summary>

    Brief intro or TL;DR visible immediately on expand.

    - <details> <summary> Sub-topic </summary>

        Detailed content here.

      </details>

    - <details> <summary> Another sub-topic </summary>

        More content.

      </details>

  </details>
```
