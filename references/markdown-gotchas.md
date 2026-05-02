# Markdown Gotchas for Hugo Sites

Things that look like they should work in markdown but don't, behave unexpectedly,
or differ between Hugo's renderer and GitHub's renderer. Read this before writing
any module content or Hugo layouts.

---

## Blockquotes

### Footnotes don't render inside blockquotes

This looks reasonable but produces broken output:

```markdown
> This is a note.[^1]

[^1]: The footnote definition.
```

Hugo's goldmark renderer processes footnotes before blockquote context, so the
`[^1]` reference inside the `>` block becomes plain text rather than a superscript
link. The footnote definition at the bottom of the page also may not render.

**Fix:** Move footnote-style asides outside the blockquote, or rewrite as inline
parenthetical text.

```markdown
> This is a note (see below for the full explanation).
```

### Tables inside blockquotes don't render

```markdown
> | Column A | Column B |
> |---|---|
> | value | value |
```

The pipe characters in a blockquote context confuse most renderers including Hugo.
The table renders as plain text.

**Fix:** Put tables outside blockquotes. If you need a table alongside a callout,
put the blockquote first, then the table after.

### Nested list items inside blockquotes need careful indentation

Hugo's goldmark requires the list marker inside a blockquote to be flush with the
`>` margin, not additionally indented. This works:

```markdown
> - First item
> - Second item
>   - Nested item (2 spaces extra inside the >)
```

This may not render the nesting:

```markdown
>   - Item with too much leading space
```

### Blockquotes do not support bold/italic nesting in all renderers

`> **Bold inside a blockquote**` works in Hugo, but some older or non-standard
renderers strip the formatting. When in doubt, test it.

---

## Footnotes

### Footnote definitions must be at the document root level

Place all `[^N]:` definitions at the very end of the document, with no other content
after them. Footnote definitions nested inside lists, tables, or blockquotes will not
render correctly.

### Footnote references in headings don't work

```markdown
## My Heading[^1]
```

The `[^1]` renders as literal text in a heading context, not a footnote link.
Keep footnote references in body paragraphs only.

---

## Code blocks

### Indented code blocks vs. fenced code blocks

Hugo supports both styles, but they behave differently:

- **Fenced** (triple backticks) — the reliable choice. Supports language hints for
  syntax highlighting. Use this everywhere.
- **Indented** (4 spaces) — works but doesn't support language hints and can interact
  badly with list indentation.

Always use fenced:
````markdown
```python
x = 1 + 1
```
````

### Language hints and syntax highlighting

Hugo uses Chroma for syntax highlighting. Common language identifiers: `python`,
`javascript`, `typescript`, `go`, `rust`, `sql`, `bash`, `sh`, `yaml`, `json`,
`html`, `css`, `markdown`, `text` (no highlighting).

Use `text` (not nothing) when you want a code block with no syntax highlighting —
a blank language hint causes Hugo to apply a default that may look wrong.

### Code blocks inside list items

A fenced code block inside a list item must be indented to match the list item's
content level (typically 4 spaces or 1 tab), otherwise it breaks the list:

````markdown
1. Here is a list item.

   ```bash
   echo "code inside a list item"
   ```

2. Next item continues normally.
````

The blank line before the code block is required.

---

## Tables

### Tables need blank lines before and after

```markdown
Some paragraph text.

| A | B |
|---|---|
| 1 | 2 |

More text.
```

A table immediately after a paragraph (no blank line) may render as plain text
rather than a table in some Hugo configurations.

### Pipe characters in table cells

If a cell value contains a pipe character (`|`), escape it as `\|`:

```markdown
| Command | Effect |
|---|---|
| `a \| b` | Runs a then b |
```

### Left/right/center alignment in tables

```markdown
| Left | Center | Right |
|:---|:---:|---:|
| text | text | text |
```

The `:` placement controls alignment. Hugo's goldmark supports this, but some
preview tools (including VS Code's built-in markdown preview) may ignore it.

---

## Links and references

### Relative links in Hugo content

In Hugo content files, relative links work from the `content/` directory root —
not from the file's own location. A link in `content/modules/01-intro/index.md`
that says `[see module 2](../02-next/)` will resolve relative to the final URL,
not the source file.

The safest approach is to use Hugo's `ref` shortcode for cross-page links:

```markdown
See [Module 2]({{< ref "modules/02-next" >}}) for more.
```

This resolves correctly regardless of where the file is in the content hierarchy.

### Absolute URLs vs. relative URLs

Use absolute URLs for external links (`https://...`). Use Hugo `ref` shortcodes
for internal cross-page links. Don't mix up the two — a relative path like
`../../glossary/` that works in a file viewer won't work in the rendered site.

---

## Front matter

### YAML front matter requires the `---` delimiter on its own line

```yaml
---
title: "My Page"
weight: 1
---
```

A space before `---` or any content on the same line as `---` breaks front matter
parsing silently — the page renders without the metadata.

### Special characters in front matter values need quoting

```yaml
title: "Using ACID: What It Means for Your Data"   # colon in title — quote it
summary: "A quick intro"                             # fine unquoted too
```

The colon (`:`) after a word in an unquoted YAML value is interpreted as a key-value
separator. Always quote title, summary, and description values.

### The `blog_post` field should be left blank (not omitted) when unused

```yaml
blog_post:    # leave blank until published
```

Omitting the field entirely is fine, but leaving it as an empty key is cleaner for
the template — it's explicit that the field exists and will be filled in later.

---

## Hugo-specific markdown behaviors

### Inline HTML requires `unsafe: true` in the markup config

By default, Hugo's goldmark renderer strips inline HTML. If you need HTML in
markdown content — for example, a `<details>` disclosure element or a `<mark>` tag —
add this to `hugo.yaml`:

```yaml
markup:
  goldmark:
    renderer:
      unsafe: true
```

Without this, HTML tags in markdown silently disappear from output.

### HTML comments are stripped from output

`<!-- This is a comment -->` in a markdown file does not appear in the rendered HTML.
This is usually what you want, but if you're using comments as placeholders or
developer notes, they won't show up in the page source either.

### The `<!-- more -->` summary divider

Hugo uses `<!-- more -->` to split the page content into summary and full content:

```markdown
This is the summary paragraph.

<!-- more -->

This is the rest of the content, shown only on the full page.
```

In list templates, `.Summary` shows only the content before `<!-- more -->`.
If you use HTML comments for other purposes, avoid placing them at paragraph breaks.

### Shortcodes vs. raw markdown

Hugo shortcodes use `{{< >}}` or `{{% %}}` syntax. The difference:

- `{{< shortcode >}}` — passes content as-is; markdown inside is NOT processed
- `{{% shortcode %}}` — passes content through the markdown renderer first

For the `ref` shortcode (links), always use `{{< ref "..." >}}`.

### Don't accidentally write the *escaped* shortcode form

Hugo also has an **escaped** shortcode form, written `{{</* shortcode */>}}`
(note the `/*` and `*/`). This is meant for tutorials that need to *show*
shortcode syntax to a reader without invoking it — Hugo prints it back as
literal text instead of evaluating it.

You almost never want this in normal prose. If you write:

```markdown
The {{</* gloss "AMO standard" */>}} sets the wood-arrow spine convention.
```

…the page renders the literal string `{{< gloss "AMO standard" >}}` instead
of a glossary link, which looks like a build error to a reader.

**Rule:** in module body content, exercises, and validation pages, always
use the live form `{{< gloss "..." >}}`. Reserve `{{</* ... */>}}` for
documentation that genuinely needs to display shortcode syntax (e.g., a
markdown-gotchas reference like this one).

A quick audit when something is rendering as raw text:

```bash
grep -rn '{{</\*' site/content/
```

Any match outside an explicit "how to write a shortcode" passage is a bug.

---

## Mermaid diagrams

Hugo curricula render Mermaid via the standard mermaid.js CDN. As of v11
(2026), Mermaid rejects several patterns that older versions tolerated.
Each one renders as a cartoon-bomb "Syntax error in text" image instead of
the diagram you wrote.

### Quote any label that isn't pure ASCII alphanumeric

Mermaid v11 rejects unquoted node labels containing:

- Unicode (degree symbols, em-dashes, accented characters, etc.)
- Apostrophes (`Archer's paradox`)
- Literal `\n` (it's not interpreted as a newline)

Always quote the label and use `<br/>` for line breaks:

```
flowchart TD
    A["5° taper"] --> B["Hang to dry<br/>24 hrs min"]
    C["Archer's paradox"] --> D
```

Inside quoted labels you can use any character; outside, you cannot.

### Subgraph titles need the bracket form for multi-word names

```
subgraph Point end          # ❌ Mermaid v11 rejects this
subgraph PointEnd ["Point end"]   # ✅ correct
subgraph "Point end"              # ✅ also correct
```

### `flowchart LR` is for short comparisons, not long chains

`LR` (left-to-right) flowcharts compress horizontally on narrow site
columns. With more than ~6 nodes the diagram becomes a single row of
unreadable thumbnails. **For any chain longer than 5–6 nodes use
`flowchart TD`** (top-down). LR is the right call when you have two short
parallel branches you want to read side by side.

### Auditing existing diagrams

`scripts/check-mermaid.sh` flags all four patterns above. The reviewer
runs it as part of `mode=full`. Run it manually:

```bash
bash scripts/check-mermaid.sh <curriculum_root>
```

---

## Behavior differences: Hugo vs. GitHub markdown

When previewing `.md` files in GitHub's repository view, you're seeing GitHub's
renderer, not Hugo's. These differ in ways that matter:

| Feature | Hugo (goldmark) | GitHub |
|---|---|---|
| Footnotes | Yes, with config | Yes |
| Tables | Yes | Yes |
| Inline HTML | Stripped by default | Rendered |
| Task lists `- [ ]` | Yes | Yes |
| Emoji `:smile:` | Not by default | Yes |
| Blockquote table | Not rendered | Not rendered |
| Footnotes in blockquotes | Not rendered | Partially |

The practical rule: if something looks right in the GitHub file view but wrong in
`hugo server`, check this table and the sections above.

---

## Common mistakes to avoid

**Pasting content from a word processor or rich text editor.** Word processors
use "smart quotes" (`"` `"`) and em-dashes (`—`) that paste into markdown files
as Unicode characters. These usually render fine, but they can cause unexpected
behavior in code blocks and YAML front matter. Stick to straight quotes in YAML
values: `title: "My Title"` not `title: "My Title"`.

**Forgetting blank lines around block elements.** Paragraphs, headings, tables,
lists, code blocks, and blockquotes all need blank lines before and after them in
Hugo's renderer. When elements appear to merge unexpectedly, check for missing
blank lines first.

**Indenting content under headings.** Markdown headings don't create a "block"
that indents its children. Extra indentation under a heading is interpreted as
an indented code block, not as structural nesting.

**Using `##` headings inside a list item.** Headings inside list items don't
render as headings in most markdown processors including Hugo. Use bold text
(`**Term:**`) as a substitute for labels inside list items.
