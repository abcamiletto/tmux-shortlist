# tmux-shortlist

A small TPM plugin for starring tmux panes and jumping between them from a
named shortlist.

`tmux-shortlist` lets you mark important panes, give them names, reorder them,
remove them, and jump back to them from a scrollable popup list.

## Installation

Install with [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'abcamiletto/tmux-shortlist'
```

Then press `prefix` + `I` to install.

## Usage

Press `prefix` + `A` to add the current pane to the shortlist. You will be
prompted for a name.

Press `prefix` + `S` to open the shortlist:

- `Enter`: jump to the selected pane
- `ctrl-u`: move the selected pane up
- `ctrl-d`: move the selected pane down
- `ctrl-x`: remove the selected pane

## Options

```tmux
set -g @shortlist-key 'S'
set -g @shortlist-add-key 'A'
set -g @shortlist-popup-width '80%'
set -g @shortlist-popup-height '70%'
```

## Requirements

- tmux
- `fzf`

## License

MIT
