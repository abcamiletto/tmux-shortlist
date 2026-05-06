#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-shortlist"
state_file="$state_dir/panes"
last_file="$state_dir/last"

mkdir -p "$state_dir"
touch "$state_file" "$last_file"

pane_alive() {
  [ "$(tmux display-message -p -t "$1" "#{pane_id}" 2>/dev/null)" = "$1" ]
}

clean_name() {
  printf '%s' "${1:-}" | tr '\t\n\r' '   ' | sed 's/^ *//; s/ *$//'
}

replace_state() {
  tmp_file="$(mktemp "$state_file.XXXXXX")"
  "$@" >"$tmp_file"
  mv "$tmp_file" "$state_file"
}

prune_items() {
  replace_state keep_live_items
  pane_alive "$(cat "$last_file")" || : >"$last_file"
}

keep_live_items() {
  while IFS=$'\t' read -r pane_id name; do
    [ -n "${pane_id:-}" ] || continue
    pane_alive "$pane_id" || continue
    printf '%s\t%s\n' "$pane_id" "$name"
  done <"$state_file"
}

list_items() {
  while IFS=$'\t' read -r pane_id name; do
    [ -n "${pane_id:-}" ] || continue
    metadata="$(tmux display-message -p -t "$pane_id" "#{session_name}:#{window_index}.#{pane_index}	#{pane_current_path}")"
    printf '%s\t%s\t%s\n' "$pane_id" "$name" "$metadata"
  done <"$state_file"
}

find_position() {
  position=0
  while IFS=$'\t' read -r pane_id _; do
    [ -n "${pane_id:-}" ] || continue
    pane_alive "$pane_id" || continue
    position=$((position + 1))
    [ "$pane_id" = "$1" ] && return
  done <"$state_file"
  position=1
}

add_current() {
  name="$(clean_name "$*")"
  [ -n "$name" ] || name="$(tmux display-message -p '#{window_name}')"
  pane_id="$(tmux display-message -p '#{pane_id}')"

  # shellcheck disable=SC2016
  replace_state awk -F '\t' -v pane_id="$pane_id" '$1 != pane_id' "$state_file"
  printf '%s\t%s\n' "$pane_id" "$name" >>"$state_file"
  tmux display-message "shortlisted: $name"
}

remove_item() {
  pane_id="${1:-}"
  [ -n "$pane_id" ] || exit 0

  # shellcheck disable=SC2016
  replace_state awk -F '\t' -v pane_id="$pane_id" '$1 != pane_id' "$state_file"
  [ "$(cat "$last_file")" = "$pane_id" ] && : >"$last_file"
}

rename_item() {
  pane_id="${1:-}"
  shift || true
  name="$(clean_name "$*")"
  [ -n "$pane_id" ] || exit 0
  [ -n "$name" ] || exit 0

  # shellcheck disable=SC2016
  replace_state awk -F '\t' -v OFS='\t' -v pane_id="$pane_id" -v name="$name" '
    $1 == pane_id { $2 = name }
    { print }
  ' "$state_file"
}

move_item() {
  pane_id="${1:-}"
  direction="${2:-}"
  [ -n "$pane_id" ] || exit 0

  # shellcheck disable=SC2016
  replace_state awk -F '\t' -v OFS='\t' -v pane_id="$pane_id" -v direction="$direction" '
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
  ' "$state_file"
}

move_and_focus() {
  pane_id="${1:-}"
  direction="${2:-}"
  move_item "$pane_id" "$direction"
  find_position "$pane_id"
  printf 'reload-sync(%q list)+pos(%s)\n' "$0" "$position"
}

jump_to() {
  pane_id="${1:-}"
  [ -n "$pane_id" ] || exit 0

  if ! pane_alive "$pane_id"; then
    remove_item "$pane_id"
    tmux display-message "shortlisted pane is gone"
    exit 1
  fi

  printf '%s\n' "$pane_id" >"$last_file"

  session_id="$(tmux display-message -p -t "$pane_id" "#{session_id}")"
  window_id="$(tmux display-message -p -t "$pane_id" "#{window_id}")"
  tmux switch-client -t "$session_id"
  tmux select-window -t "$window_id"
  tmux select-pane -t "$pane_id"
}

open_picker() {
  if ! command -v fzf >/dev/null 2>&1; then
    tmux display-message "tmux-shortlist requires fzf"
    echo "tmux-shortlist requires fzf" >&2
    exit 1
  fi

  popup_width="$(tmux show-option -gqv "@shortlist-popup-width")"
  popup_height="$(tmux show-option -gqv "@shortlist-popup-height")"
  popup_width="${popup_width:-80%}"
  popup_height="${popup_height:-70%}"
  prune_items
  shortlist_file="$(mktemp)"
  list_items >"$shortlist_file"

  if [ ! -s "$shortlist_file" ]; then
    rm -f "$shortlist_file"
    tmux display-message "tmux-shortlist is empty"
    exit 0
  fi

  find_position "$(cat "$last_file")"

  # shellcheck disable=SC2016
  picker_command='
selected="$(
  FZF_DEFAULT_COMMAND= fzf <"$SHORTLIST_FILE" \
      --prompt="Filter " --delimiter="\t" --with-nth="{2}  {3}  {4}" --nth=2,3,4 \
      --height=100% --layout=reverse --cycle --padding=0,1 \
      --footer="enter: jump | j/k: reorder | ctrl-x: remove | esc: close" \
      --info=inline-right --pointer=">" \
      --preview="tmux capture-pane -ep -t {1} -S -60" \
      --preview-window=right,55%,border-left \
      --bind="ctrl-r:execute-silent(tmux command-prompt -p rename: \"run-shell \\\"$SHORTLIST_SCRIPT rename {1} %%\\\"\")+abort" \
      --bind="ctrl-x:execute-silent(\"$SHORTLIST_SCRIPT\" remove {1})+reload(\"$SHORTLIST_SCRIPT\" list)" \
      --bind="k:transform(\"$SHORTLIST_SCRIPT\" move-focus {1} up)" \
      --bind="j:transform(\"$SHORTLIST_SCRIPT\" move-focus {1} down)" \
      --bind="load:pos($SHORTLIST_POSITION)" \
      --bind="esc:abort"
)" || exit 0
"$SHORTLIST_SCRIPT" jump "${selected%%	*}"
'

  printf -v tmux_command '%q ' env "SHORTLIST_SCRIPT=$0" "SHORTLIST_FILE=$shortlist_file" "SHORTLIST_POSITION=$position" "$SHELL" -lc "$picker_command"

  tmux display-popup -E -b rounded -w "$popup_width" -h "$popup_height" "$tmux_command"
  rm -f "$shortlist_file"
}

case "${1:-open}" in
  add) shift; add_current "$*" ;;
  list) prune_items; list_items ;;
  remove) remove_item "${2:-}" ;;
  rename) shift; rename_item "$@" ;;
  move) move_item "${2:-}" "${3:-}" ;;
  move-focus) move_and_focus "${2:-}" "${3:-}" ;;
  jump) jump_to "${2:-}" ;;
  open) open_picker ;;
  *) echo "usage: $0 [add NAME|list|remove PANE|rename PANE NAME|move PANE up|move PANE down|jump PANE|open]" >&2; exit 2 ;;
esac
