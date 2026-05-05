#!/usr/bin/env bash
set -euo pipefail

if ! command -v fzf >/dev/null 2>&1; then
  tmux choose-tree -Zw
  exit 0
fi

popup_width="$(tmux show-option -gqv "@shortlist-popup-width")"
popup_height="$(tmux show-option -gqv "@shortlist-popup-height")"
popup_width="${popup_width:-80%}"
popup_height="${popup_height:-70%}"

# shellcheck disable=SC2016
picker_command='
set -euo pipefail

selection="$(
  tmux list-panes -a -F "#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name} #{pane_current_path}" |
    fzf --prompt="tmux> " --height=100% --layout=reverse --border \
      --preview="tmux capture-pane -ep -t {1} -S -60" \
      --preview-window=down,60%,border-top
)"

pane_id="${selection%% *}"
if [ -n "$pane_id" ]; then
  session_id="$(tmux display-message -p -t "$pane_id" "#{session_id}")"
  window_id="$(tmux display-message -p -t "$pane_id" "#{window_id}")"
  tmux switch-client -t "$session_id"
  tmux select-window -t "$window_id"
  tmux select-pane -t "$pane_id"
fi
'

if tmux display-popup -E -w "$popup_width" -h "$popup_height" "$SHELL" -lc "$picker_command" 2>/dev/null; then
  exit 0
fi

tmux new-window -n shortlist "$SHELL" -lc "$picker_command"
