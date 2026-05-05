#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shortlist_key="$(tmux show-option -gqv "@shortlist-key")"
shortlist_add_key="$(tmux show-option -gqv "@shortlist-add-key")"
shortlist_key="${shortlist_key:-S}"
shortlist_add_key="${shortlist_add_key:-A}"

tmux bind-key "$shortlist_key" run-shell "$CURRENT_DIR/scripts/shortlist.sh"
tmux bind-key "$shortlist_add_key" command-prompt -p "shortlist name:" "run-shell '$CURRENT_DIR/scripts/shortlist.sh add %%'"
