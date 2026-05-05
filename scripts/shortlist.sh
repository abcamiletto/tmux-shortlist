#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-shortlist"
state_file="$state_dir/panes"

mkdir -p "$state_dir"
touch "$state_file"

pane_alive() {
  tmux display-message -p -t "$1" "#{pane_id}" >/dev/null 2>&1
}

list_items() {
  while IFS=$'\t' read -r pane_id name; do
    [ -n "${pane_id:-}" ] || continue
    pane_alive "$pane_id" || continue
    tmux display-message -p -t "$pane_id" \
      "$pane_id	$name	#{session_name}:#{window_index}.#{pane_index}	#{pane_current_path}"
  done <"$state_file"
}

add_current() {
  name="$(printf '%s' "${1:-}" | tr '\t\n\r' '   ' | sed 's/^ *//; s/ *$//')"
  [ -n "$name" ] || name="$(tmux display-message -p '#{window_name}')"
  pane_id="$(tmux display-message -p '#{pane_id}')"
  tmp_file="$(mktemp "$state_file.XXXXXX")"

  # shellcheck disable=SC2016
  awk -F '\t' -v pane_id="$pane_id" '$1 != pane_id' "$state_file" >"$tmp_file"
  mv "$tmp_file" "$state_file"
  printf '%s\t%s\n' "$pane_id" "$name" >>"$state_file"
  tmux display-message "shortlisted: $name"
}

remove_item() {
  pane_id="${1:-}"
  [ -n "$pane_id" ] || exit 0
  tmp_file="$(mktemp "$state_file.XXXXXX")"

  # shellcheck disable=SC2016
  awk -F '\t' -v pane_id="$pane_id" '$1 != pane_id' "$state_file" >"$tmp_file"
  mv "$tmp_file" "$state_file"
}

move_item() {
  pane_id="${1:-}"
  direction="${2:-}"
  [ -n "$pane_id" ] || exit 0

  tmp_file="$(mktemp "$state_file.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v pane_id="$pane_id" -v direction="$direction" '
    { rows[++n] = $0 }
    END {
      for (i = 1; i <= n; i++) {
        split(rows[i], fields, FS)
        if (fields[1] == pane_id) {
          target = i + (direction == "down" ? 1 : -1)
          if (target >= 1 && target <= n) {
            tmp = rows[target]
            rows[target] = rows[i]
            rows[i] = tmp
          }
          break
        }
      }
      for (i = 1; i <= n; i++) print rows[i]
    }
  ' "$state_file" >"$tmp_file"
  mv "$tmp_file" "$state_file"
}

jump_to() {
  pane_id="${1:-}"
  [ -n "$pane_id" ] || exit 0

  if ! pane_alive "$pane_id"; then
    remove_item "$pane_id"
    tmux display-message "shortlisted pane is gone"
    exit 1
  fi

  session_id="$(tmux display-message -p -t "$pane_id" "#{session_id}")"
  window_id="$(tmux display-message -p -t "$pane_id" "#{window_id}")"
  tmux switch-client -t "$session_id"
  tmux select-window -t "$window_id"
  tmux select-pane -t "$pane_id"
}

open_picker() {
  command -v fzf >/dev/null 2>&1 || die "tmux-shortlist requires fzf"

  popup_width="$(tmux show-option -gqv "@shortlist-popup-width")"
  popup_height="$(tmux show-option -gqv "@shortlist-popup-height")"
  popup_width="${popup_width:-80%}"
  popup_height="${popup_height:-70%}"

  # shellcheck disable=SC2016
  picker_command='
selected="$(
  "$SHORTLIST_SCRIPT" list |
    fzf --prompt="Filter " --delimiter="\t" --with-nth="{2}  {3}  {4}" --nth=2,3,4 \
      --height=100% --layout=reverse --border=rounded \
      --border-label=" tmux shortlist " --header="enter: jump | j/k: reorder | ctrl-x: remove | esc: close" \
      --info=inline-right --pointer=">" --marker="+" \
      --preview="tmux capture-pane -ep -t {1} -S -60" \
      --preview-window=down,60%,border-top \
      --bind="ctrl-x:execute-silent(\"$SHORTLIST_SCRIPT\" remove {1})+reload(\"$SHORTLIST_SCRIPT\" list)" \
      --bind="k:execute-silent(\"$SHORTLIST_SCRIPT\" move {1} up)+reload(\"$SHORTLIST_SCRIPT\" list)" \
      --bind="j:execute-silent(\"$SHORTLIST_SCRIPT\" move {1} down)+reload(\"$SHORTLIST_SCRIPT\" list)" \
      --bind="esc:abort"
)"
[ -n "$selected" ] && "$SHORTLIST_SCRIPT" jump "${selected%%	*}"
'

  printf -v tmux_command '%q ' env "SHORTLIST_SCRIPT=$0" "$SHELL" -lc "$picker_command"

  tmux display-popup -E -w "$popup_width" -h "$popup_height" "$tmux_command"
}

die() {
  tmux display-message "$1"
  echo "$1" >&2
  exit 1
}

case "${1:-open}" in
  add) shift; add_current "$*" ;;
  list) list_items ;;
  remove) remove_item "${2:-}" ;;
  move) move_item "${2:-}" "${3:-}" ;;
  jump) jump_to "${2:-}" ;;
  open) open_picker ;;
  *) echo "usage: $0 [add NAME|list|remove PANE|move PANE up|move PANE down|jump PANE|open]" >&2; exit 2 ;;
esac
