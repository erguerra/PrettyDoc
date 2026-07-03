# Integrating Pretty Doc with terminals and AI tools

Pretty Doc is designed to be the place your Markdown *renders*. Editors and AI
agents (Cursor, Claude Code, etc.) can hand off `.md` files to it for a clean,
responsive reading view - while you keep editing wherever you like.

There are three ways to open documents: the `prettydoc` CLI, the `prettydoc://`
URL scheme, and standard file opens (`open -a`, Finder "Open With", or setting
Pretty Doc as the default `.md` handler).

## The `prettydoc` CLI

Install it once (also available in-app via **Pretty Doc -> Install Command-Line
Tool...**):

```bash
./Scripts/install-cli.sh
```

Usage:

```bash
prettydoc README.md                 # open a file in a new tab
prettydoc a.md b.md c.md            # open several files as tabs
prettydoc plan.md#implementation    # open and scroll to a heading
prettydoc --theme sepia notes.md    # open with a specific theme
prettydoc --reuse next.md           # replace the current tab
prettydoc -n scratch.md             # prefer a new window
some-agent | prettydoc -            # stream stdin live (implies --follow)
prettydoc --help                    # full option list
```

Options: `-n/--new-window`, `--reuse`, `--anchor <slug>`, `--line <n>` (reserved),
`--theme <light|dark|sepia|system>`, `--follow`, `-` (stdin).

Headings are addressable by a GitHub-style slug of their text (lowercased,
spaces to `-`). So `## Implementation Plan` is `#implementation-plan`.

## The `prettydoc://` URL scheme

The CLI is a thin wrapper over this scheme, which any tool can call directly
(via `open` or an OS URL-open API). It works whether or not the app is already
running.

```
prettydoc://open?path=<abs-path>[&path=<abs-path>...]
                 [&tab=new|reuse]
                 [&window=new]
                 [&anchor=<slug>]
                 [&line=<n>]        (reserved; approximate for rendered Markdown)
                 [&theme=<light|dark|sepia|system>]
                 [&follow=1]
```

- `path` may be repeated to open multiple tabs. Values must be URL-encoded
  absolute paths.
- `anchor`, `line`, and `theme` apply to the first `path`.

Example:

```bash
open "prettydoc://open?path=/Users/me/plan.md&anchor=next-steps&theme=dark"
```

## Make Pretty Doc the default `.md` viewer (optional)

So that Finder and tools that "open" a file route to Pretty Doc:

- Manually: select a `.md` file in Finder -> Get Info -> "Open with" -> Pretty
  Doc -> "Change All...".
- With [`duti`](https://github.com/moretension/duti):

```bash
brew install duti
duti -s com.eduardoguerra.prettydoc net.daringfireball.markdown all
duti -s com.eduardoguerra.prettydoc .md all
```

## Recipes

### Cursor / VS Code

Add a shell alias so "view this rendered" is one command, and keep editing in
the IDE:

```bash
alias mdview='prettydoc'
```

You can also add a task or keybinding that runs `prettydoc ${file}` on the
current file for a live, responsive preview alongside the editor (Pretty Doc
live-reloads as you save).

### Claude Code / terminal agents

Tell the agent it can surface Markdown results to you visually. For example, in
your project instructions:

> When you produce a Markdown document (a plan, spec, or report), run
> `prettydoc <file>` so it opens in Pretty Doc. If you want me to look at a
> specific part, point me there with `prettydoc <file>#<section-slug>`.

For streaming output an agent is actively writing, pipe it:

```bash
my-agent --emit-markdown | prettydoc -
```

Pretty Doc opens a "stream" tab in follow mode and auto-scrolls as content
arrives, so you can watch the document being written in a nicely rendered view.
