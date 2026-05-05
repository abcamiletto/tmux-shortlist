#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shortlist_key="$(tmux show-option -gqv "@shortlist-key")"
shortlist_key="${shortlist_key:-S}"

tmux bind-key "$shortlist_key" run-shell "$CURRENT_DIR/scripts/shortlist.sh"
