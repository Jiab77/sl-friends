#!/usr/bin/env bash
# shellcheck source=/dev/null disable=SC2034,SC2086

# Notify when a Second Life friend is connected (sl-notify.sh)
# Made by Jiab77
#
# References:
# - https://wiki.archlinux.org/title/Desktop_notifications
#
# Version: 0.1.1

# Options
[[ -r $HOME/.debug ]] && set -o xtrace || set +o xtrace

# Colors
NL="\n"
NC="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
ORANGE="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
LIGHTGRAY="\033[0;37m"
DARKGRAY="\033[1;30m"
LIGHTRED="\033[1;31m"
LIGHTGREEN="\033[1;32m"
YELLOW="\033[1;33m"
LIGHTBLUE="\033[1;34m"
LIGHTPURPLE="\033[1;35m"
LIGHTCYAN="\033[1;36m"
WHITE="\033[1;37m"

# Styles
ITALIC="\033[3m"
UNDERLINE="\033[4m"
STRIKETHROUGH="\033[9m"

# Default config
DEBUG_MODE=false
NOTIF_ICON=
NOTIF_TITLE="User connected"
NOTIF_BODY="The user {x} just connected..."
NOTIF_TIMEOUT=5000

# Internals
NOTIF_ID=
NOTIF_SENT=false
NOTIF_APP_SCRIPT="$(basename "$0")"
NOTIF_APP_NAME="${NOTIF_APP_SCRIPT//.sh/}"
NOTIF_ICON_INFO="dialog-information"
NOTIF_ICON_TERM="utilities-terminal"
NOTIF_STAT_FILE="/tmp/.sl-user-connected"

# User config (overrides default config)
[[ -r "$(dirname "$0")/sl-notify.conf" ]] && source "$(dirname "$0")/sl-notify.conf"

# Binaries
BIN_GDBUS=$(command -v gdbus 2>/dev/null)
BIN_NOTIFY=$(command -v notify-send 2>/dev/null)
BIN_ZENITY=$(command -v zenity 2>/dev/null)
# BIN_DBUS=$(command -v dbus-send 2>/dev/null)

# Functions
function die() {
  echo -e "\nError: $*\n" >&2
  exit 255
}
function print_usage() {
  echo -e "\nUsage: $NOTIF_APP_SCRIPT [flags] <username> -- Create notification when given user is connected."
  echo -e "\nFlags:"
  echo -e "  -h | --help\tPrint this message and exit"
  echo
  exit
}
function make_bold() {
  echo -n "<b>$1</b>"
}
function make_italic() {
  echo -n "<i>$1</i>"
}
function make_italic_bold() {
  echo -n "<i><b>$1</b></i>"
}
function make_underlined() {
  echo -n "<u>$1</u>"
}
function make_underlined_bold() {
  echo -n "<u><b>$1</b></u>"
}
function make_underlined_italic() {
  echo -n "<u><i>$1</i></u>"
}
function make_underlined_italic_bold() {
  echo -n "<u><i><b>$1</b></i></u>"
}
function replace() {
  if [[ $# -eq 3 ]]; then
    case $3 in
      bold)
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</b> or <b>'}"
          echo -n "${2//'{x}'/$(make_bold "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_bold "$1")}"
        fi
      ;;
      italic)
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</i> or <i>'}"
          echo -n "${2//'{x}'/$(make_italic "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_italic "$1")}"
        fi
      ;;
      underline)
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</u> or <u>'}"
          echo -n "${2//'{x}'/$(make_underlined "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_underlined "$1")}"
        fi
      ;;
      "underline bold"|"bold underline")
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</b></u> or <u><b>'}"
          echo -n "${2//'{x}'/$(make_underlined_bold "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_underlined_bold "$1")}"
        fi
      ;;
      "italic bold"|"bold italic")
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</b></i> or <i><b>'}"
          echo -n "${2//'{x}'/$(make_italic_bold "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_italic_bold "$1")}"
        fi
      ;;
      "italic underline"|"underline italic")
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</i></u> or <u><i>'}"
          echo -n "${2//'{x}'/$(make_underlined_italic "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_underlined_italic "$1")}"
        fi
      ;;
      "bold italic underline"|"underline italic bold"|"italic underline bold"|"italic bold underline")
        if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
          local OR_STR ; OR_STR="${1//'|'/'</b></i></u> or <u><i><b>'}"
          echo -n "${2//'{x}'/$(make_underlined_italic_bold "$OR_STR")}"
        else
          echo -n "${2//'{x}'/$(make_underlined_italic_bold "$1")}"
        fi
      ;;
      *)
        echo -e "\nError: Invalid style given.\n"
        exit 1
      ;;
    esac
  else
    if [[ $(echo -n "$1" | grep -c '|') -ne 0 ]]; then
      local OR_STR ; OR_STR="${1//'|'/' or '}"
      echo -n "${2//'{x}'/"$OR_STR"}"
    else
      echo -n "${2//'{x}'/"$1"}"
    fi
  fi
}
function get_notify_send_version() {
  local NS_VER ; NS_VER=$(notify-send -v 2>/dev/null | cut -d" " -f2)
  if [[ -n $NS_VER ]]; then
    echo -n "$NS_VER"
  else
    return 1
  fi
}
function notify() {
  # Avoid displaying notification if already done
  [[ -f $NOTIF_STAT_FILE ]] && NOTIF_SENT=true

  # Displaying notification if not done yet
  if [[ $NOTIF_SENT == false ]]; then
    # The command below is not working due to 'variant' type
    # not supported by 'dbus-send'.
    #
    # See: https://stackoverflow.com/questions/8846671/how-to-use-a-variant-dictionary-asv-in-dbus-send
    #
    # dbus-send --session --print-reply \
    #           --dest=org.freedesktop.Notifications \
    #           --type=method_call \
    #           --reply-timeout=10000 \
    #           /org/freedesktop/Notifications \
    #           org.freedesktop.Notifications.Notify \
    #           string:'sl-notify' \
    #           uint32:0 \
    #           string:'dialog-information' \
    #           string:'Hello world!' \
    #           string:'This is an example notification.' \
    #           array:string: \
    #           dict:string:variant: \
    #           uint32:0
    #
    # But this one is functional:
    #
    # gdbus call --session \
    #            --dest org.freedesktop.Notifications \
    #            --object-path /org/freedesktop/Notifications \
    #            --method org.freedesktop.Notifications.Notify \
    #            sl-notify \
    #            0 \
    #            utilities-terminal \
    #            "User connected" \
    #            "The user [x] just connected.." \
    #            [] \
    #            {} \
    #            0
    #
    #
    # Here is a functional implementation for several backends.
    # Some others might be added in the future.

    # notify-send
    if [[ -n $BIN_NOTIFY ]]; then
      if [[ -n "$(get_notify_send_version)" && "$(get_notify_send_version)" == "0.7.9" ]]; then
        notify-send "$1" "$2" --icon="$3" --app-name="$NOTIF_APP_NAME" --expire-time=$NOTIF_TIMEOUT && NOTIF_SENT=true
      else
        if [[ $DEBUG_MODE == true ]]; then
          notify-send "$1" "$2" --icon="$3" --app-name="$NOTIF_APP_NAME" --expire-time=$NOTIF_TIMEOUT --replace-id=${NOTIF_ID:-0} --print-id && NOTIF_SENT=true
        else
          notify-send "$1" "$2" --icon="$3" --app-name="$NOTIF_APP_NAME" --expire-time=$NOTIF_TIMEOUT --replace-id=${NOTIF_ID:-0} && NOTIF_SENT=true
        fi
      fi

    # zenity
    elif [[ -n $BIN_ZENITY ]]; then
      zenity --notification --window-icon="$3" --text "$1\\n$2" && NOTIF_SENT=true

    # gdbus
    elif [[ -n $BIN_GDBUS ]]; then
      gdbus call --session \
                 --dest org.freedesktop.Notifications \
                 --object-path /org/freedesktop/Notifications \
                 --method org.freedesktop.Notifications.Notify \
                 "$NOTIF_APP_NAME" \
                 ${NOTIF_ID:-0} \
                 "$3" \
                 "$1" \
                 "$2" \
                 [] \
                 {} \
                 $NOTIF_TIMEOUT && NOTIF_SENT=true

    # error
    else
      echo -e "\nError: Unable to find proper notification backend.\n"
      exit 1
    fi
  fi

  # save notification display status
  [[ $NOTIF_SENT == true ]] && touch $NOTIF_STAT_FILE
}

# Checks
[[ $# -eq 0 ]] && print_usage

# Flags
[[ $1 == "-h" || $1 == "--help" ]] && print_usage

# Init
NOTIF_REPLACE=$1
NOTIF_REPLACE_STYLE=${2:-'bold'}

# Main
if [[ -n $NOTIF_REPLACE ]]; then
  notify "$NOTIF_TITLE" "$(replace "$NOTIF_REPLACE" "$NOTIF_BODY" "$NOTIF_REPLACE_STYLE")" "$NOTIF_ICON_TERM"
else
  notify "$NOTIF_TITLE" "$NOTIF_BODY" "$NOTIF_ICON_TERM"
fi
