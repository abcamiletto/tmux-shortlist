# tmux-shortlist

A small TPM plugin for jumping between tmux panes with a searchable shortlist.

`tmux-shortlist` binds a key that opens a tmux popup picker. If `fzf` is installed,
the picker lists every pane across every session with a live pane preview. If `fzf`
is not installed, it falls back to tmux's built-in `choose-tree`.

## Installation

Install with [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'abcamiletto/tmux-shortlist'
```

Then press `prefix` + `I` to install.

## Usage

Press `prefix` + `S` to open the shortlist, search for a pane, and press `Enter`
to jump to it.

## Options

```tmux
set -g @shortlist-key 'S'
set -g @shortlist-popup-width '80%'
set -g @shortlist-popup-height '70%'
```

## Requirements

- tmux
- Optional: `fzf` for the searchable popup picker

## License

MIT
