#!/usr/bin/env bash
# shellcheck source=/dev/null disable=SC2034,SC2086

# Display Second Life friends from CLI (sl-friends.sh)
# Made by Jiab77
#
# Trimmed output with suggestions from:
# - https://unix.stackexchange.com/a/102021
#
# Update:
#
# 20230922 - Found interesting endpoint: https://secondlife.com/data/latest.json
# 20230922 - Updated endpoints:
#          ==> Friends: https://secondlife.com/my/widget-friends.php
#          ==> Groups: https://secondlife.com/my/widget-groups.php
#          ==> Lindens: https://secondlife.com/my/widget-linden-dollar.php
#
# Version: 1.1.0

# Options
set +o xtrace

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
DEBUG=false
SL_TOKEN=""
SL_TOKEN_ENCODED=false
# SL_FRIENDS_URL="https://secondlife.com/my/loadWidgetContent.php?widget=widgetFriends"
SL_FRIENDS_URL="https://secondlife.com/my/widget-friends.php"
SL_FRIENDS_HTML_ID="#widgetFriendsOnlineContent"
SL_LINDENS_URL="https://secondlife.com/my/widget-linden-dollar.php"
SL_LINDENS_HTML_CLASS=".main-widget-content"
SL_REFRESH_DELAY=5
SL_STATUS_FILTER="online"
SL_INTERNAL_NAMES=false
SL_LINDENS=false
CURL_USER_AGENTS=(
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.69 Safari/537.36"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0"
    "Mozilla/5.0 (X11; Linux x86_64; rv:95.0) Gecko/20100101 Firefox/95.0"
)
CURL_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.69 Safari/537.36"
WATCH_TITLE=true

# User config (overrides default config)
[[ -r "$(dirname "$0")/sl-friends.conf" ]] && source "$(dirname "$0")/sl-friends.conf"

# Internal config
# TMP_FILE="/tmp/$(basename "$0")"
TMP_FILE="/dev/shm/$(basename "$0")"

# Binaries
BIN_AWK=$(which awk)
BIN_CURL=$(which curl)
BIN_GREP=$(which grep)
BIN_HTMLQ=$(which htmlq)
BIN_SED=$(which sed)
BIN_WATCH=$(which watch)
BIN_WC=$(which wc)

# Test binaries
if [[ $BIN_AWK == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}awk${WHITE}' binary.${NC}${NL}"
    exit 1
elif [[ $BIN_CURL == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}curl${WHITE}' binary.${NC}${NL}"
    exit 1
elif [[ $BIN_GREP == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}grep${WHITE}' binary.${NC}${NL}"
    exit 1
elif [[ $BIN_HTMLQ == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}htmlq${WHITE}' binary.${NC}${NL}"
    exit 1
elif [[ $BIN_SED == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}sed${WHITE}' binary.${NC}${NL}"
    exit 1
elif [[ $BIN_WATCH == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}watch${WHITE}' binary.${NC}${NL}"
    exit 1
elif [[ $BIN_WC == "" ]]; then
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}wc${WHITE}' binary.${NC}${NL}"
    exit 1
fi

# Functions
# Generate temporary script
make_temp_script() {
    if [[ $DEBUG == true ]]; then
        echo -e "${NL}${LIGHTPURPLE}[DEBUG]${WHITE} Received: ${LIGHTGREEN}${1}${NC}${NL}"
    fi

    cat > "$TMP_FILE" <<EOF
#!/usr/bin/env bash

# Available user-agents
CURL_USER_AGENTS=(
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.69 Safari/537.36"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0"
    "Mozilla/5.0 (X11; Linux x86_64; rv:95.0) Gecko/20100101 Firefox/95.0"
)

# generate a random number from 0 to (\$1-1)
# GLOBALS: _RANDOM.
rand() {
    local max=$\((32768 / \$1 * \$1)\)
    if (( max > 0 )); then
        while (( (_RANDOM=RANDOM) >= max )); do :; done
        _RANDOM=$\(( _RANDOM % \$1 )\)
    else
        return 1
    fi
}

# shuffle an array using the rand function
# GLOBALS: _array, _RANDOM
shuffle() {
    local i tmp size
    size=\${#_array[*]}
    for ((i=size-1; i>0; i--)); do
        if ! rand \$((i+1)); then exit 1; fi
        tmp=\${_array[i]} _array[i]=\${_array[\$_RANDOM]} _array[\$_RANDOM]=\$tmp
    done
}

# Generate random user-agent for each requests
gen_rand_ua() {
    # Shuffle user-agents array
    _array=("\${CURL_USER_AGENTS[@]}"); shuffle ; CURL_USER_AGENTS=("\${_array[@]}")

    # Assign random user-agent
    CURL_USER_AGENT="\${CURL_USER_AGENTS[0]}"

    echo "\${CURL_USER_AGENT}"
}

# Store generated magic commands
FRIENDS=$\(${1}\)
LINDENS=$\(${2}\)

# Display result and count
echo -e "\${FRIENDS}"
echo ; echo -n "Connected: "
[[ \$FRIENDS == "" ]] && echo "0" || echo "\${FRIENDS}" | wc -l ; echo
[[ -n \$LINDENS ]] && echo "Total Linden Dollars owned: \$LINDENS"
EOF
    sed -e 's|\\||g' -i "$TMP_FILE"

    chmod +x "$TMP_FILE"
}

# Generate script usage instructions
show_help() {
    cat <<EOF

Usage: $0

Arguments:

    -c|--config </path/to/config/file> (Default: ./sl-friends.conf)
    -t|--token [session-token] (Warning: should not be used as the token will be stored in the command history!)
    -f|--filter <online|offline> (Default: $SL_STATUS_FILTER)
    -u|--url <second-life-friends-url> (Default: $SL_FRIENDS_URL)
    -q|--html-id <second-life-html-id-to-target> (Default: $SL_FRIENDS_HTML_ID)
    -a|--user-agent <user-agent string> (Default: $CURL_USER_AGENT)
    -b|--base64 (Decode base64 encoded session token. [implies -t|--token] - Default: $SL_TOKEN_ENCODED)
    -i|--show-internal-names (Show Second Life internal names. Default: false)
    -l|--show-lindens (Show amount of owned linden dollars. Default: false)
    -n|--no-title (Remove 'watch' command title displayed. Default: false)
    -r|--refresh <seconds> (Define 'watch' command refresh rate. Default: $SL_REFRESH_DELAY seconds)
    -h|--help (Show this message)
    --debug (Enable debug output when disabled by default)
    -D (Disable debug output when enabled by default)

Examples:

    $(basename "$0")
    $(basename "$0") -inr 10
    $(basename "$0") --show-internal-names --no-title --refresh 10
    $(basename "$0") -t (it will ask for session-token)
    $(basename "$0") --token (it will ask for session-token)
    $(basename "$0") -bt <base64 encoded session-token>
    $(basename "$0") --base64 --token <base64 encoded session-token>
    $(basename "$0") -f offline
    $(basename "$0") --filter offline

Note:

As I am still pretty bad in arguments parsing, you might need to place arguments at the right position if you want to chain them...

Error codes:

    1 - Missing required binary
    2 - Missing Second Life session token
    3 - Given config file does not exist

Credit:

Jiab77 - https://twitter.com/jiab77

EOF

}

# Initial command
if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
    MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
else
    MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
fi

# Arguments
WATCHOPTS="-n${SL_REFRESH_DELAY}"
SHORTOPTS="b,c:,n,r:,t::,u:,q:,a:,f:,i,l,h,D"
LONGOPTS="base64,config:,no-title,refresh,token::,url:,html-id:,user-agent:,filter:,show-internal-names,show-lindens,help,debug,thc"
ARGS=$(getopt -l "${LONGOPTS}" -o "${SHORTOPTS}" -- "$@")
eval set -- "$ARGS"
while [ $# -ge 1 ]; do
    case "$1" in
        --)
            # No more options left.
            shift
            break
            ;;
        -b|--base64)
            unset MAGIC_COMMAND
            unset SL_TOKEN_ENCODED
            SL_TOKEN_ENCODED=true

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo -n $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi
            ;;
        -c|--config)
            unset MAGIC_COMMAND
            SL_CONFIG_FILE="$2"
            [[ ! -r $SL_CONFIG_FILE ]] && echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Specified config file '${YELLOW}${2}${WHITE}' does not exist.${NC}${NL}" && exit 3
            source $SL_CONFIG_FILE

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo -n $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi

            shift
            ;;
        -a|--user-agent)
            unset MAGIC_COMMAND
            unset CURL_USER_AGENT
            CURL_USER_AGENT="$2"

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '${CURL_USER_AGENT}' -b session-token=$(echo -n $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '${CURL_USER_AGENT}' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi

            shift
            ;;
        -t|--token)
            unset MAGIC_COMMAND
            unset SL_TOKEN

            if [[ $4 == "" && $2 == "" ]]; then
                if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                    SL_TOKEN=$(read -rsp "Enter your session token (output hidden for security reason): " TMP_TOKEN && echo -n $TMP_TOKEN)
                else
                    SL_TOKEN=$(read -rsp "Enter your session token (output hidden for security reason): " TMP_TOKEN && echo -n $TMP_TOKEN | base64 -)
                fi
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo -n $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                    MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo -n $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
                else
                    MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
                fi
            fi

            clear

            shift
            ;;
        -f|--filter)
            unset MAGIC_COMMAND
            unset SL_STATUS_FILTER
            SL_STATUS_FILTER="$2"

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi

            shift
            ;;
        -u|--url)
            unset MAGIC_COMMAND
            unset SL_FRIENDS_URL
            SL_FRIENDS_URL="$2"

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi

            shift
            ;;
        -q|--html-id)
            unset MAGIC_COMMAND
            unset SL_FRIENDS_HTML_ID
            SL_FRIENDS_HTML_ID="$2"

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi

            shift
            ;;
        -r|--refresh)
            unset SL_REFRESH_DELAY
            unset WATCHOPTS
            SL_REFRESH_DELAY="$2"
            WATCHOPTS="-n${2}"
            
            [[ $WATCH_TITLE == false ]] && WATCHOPTS="${WATCHOPTS} -t"

            shift
            ;;
        -i|--show-internal-names)
            unset MAGIC_COMMAND
            unset SL_INTERNAL_NAMES
            SL_INTERNAL_NAMES=true

            # if [[ $SL_INTERNAL_NAMES == true ]]; then
            #     if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
            #         MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=`echo $SL_TOKEN | base64 -d 2>/dev/null` $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            #     else
            #         MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            #     fi
            # fi

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi
            ;;
        -l|--show-lindens)
            unset MAGIC_COMMAND
            unset SL_INTERNAL_NAMES
            SL_LINDENS=true

            if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            else
                MAGIC_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_FRIENDS_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed 's/^[[:blank:]]*/    /;s/[[:blank:]]*$//'"
            fi
            ;;
        -n|--no-title)
            unset WATCH_TILE
            WATCH_TITLE=false
            [[ $WATCH_TITLE == false ]] && WATCHOPTS="${WATCHOPTS} -t"
            ;;
        --debug)
            unset DEBUG
            DEBUG=true
            ;;
        -D)
            unset DEBUG
            DEBUG=false
            ;;
        -h|--help)
            show_help

            exit 0
            ;;
        --thc)
            echo -e "${NL}${WHITE}!!Greetings to Van Hauser, ${LIGHTGREEN}Skyper${WHITE}, ${YELLOW}Viking${WHITE}, ${LIGHTRED}0xD1G${WHITE}, ${LIGHTCYAN}Sam Lowry${WHITE}, ${LIGHTBLUE}LouCipher${WHITE}, ${LIGHTPURPLE}M ${WHITE}&${LIGHTPURPLE} L${WHITE} and the rest of ${LIGHTGREEN}T${YELLOW}H${LIGHTRED}C${WHITE} from ${ITALIC}${STRIKETHROUGH}Doctor${NC} ${DARKGRAY}Who${WHITE}!!${NC}${NL}"
            exit 187
            ;;
    esac

    shift
done

# Debug
if [[ $DEBUG == true ]]; then
    echo -e "${NL}${LIGHTPURPLE}[DEBUG]${WHITE} Config:${NC}${NL}"
    echo "ARGS: $ARGS"
    echo "SL_FRIENDS_URL: $SL_FRIENDS_URL"
    echo "SL_FRIENDS_HTML_ID: $SL_FRIENDS_HTML_ID"
    echo "SL_STATUS_FILTER: $SL_STATUS_FILTER"
    echo "SL_INTERNAL_NAMES: $SL_INTERNAL_NAMES"
    echo "SL_LINDENS: $SL_LINDENS"
    echo "SL_TOKEN: $SL_TOKEN"
    echo "SL_TOKEN_ENCODED: $SL_TOKEN_ENCODED"
    echo "SL_REFRESH_DELAY: $SL_REFRESH_DELAY"
    echo "WATCHOPTS: $WATCHOPTS"
    echo "REMAINING ARGS: $*"
    echo "MAGIC_COMMAND: $MAGIC_COMMAND"
    # exit 0
fi

# Generate Lindens related command
if [[ $SL_LINDENS == true ]]; then
    if [[ -n $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
        LINDENS_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=$(echo $SL_TOKEN | base64 -d 2>/dev/null) $SL_LINDENS_URL | htmlq '${SL_LINDENS_HTML_CLASS}' | awk '{print $5}' | sed -e 's/<strong>//' -e 's|</strong></span>||'"
    else
        LINDENS_COMMAND="curl --silent -A '\$(gen_rand_ua)' -b session-token=${SL_TOKEN} $SL_LINDENS_URL | htmlq '${SL_LINDENS_HTML_CLASS}' | awk '{print \$5}' | sed -e 's/<strong>//' -e 's|</strong></span>||'"
    fi
else
    LINDENS_COMMAND=""
fi

# Check if the required session-token is defined
if [[ -n $SL_TOKEN && -n $MAGIC_COMMAND ]]; then
    # Create initial temp script
    make_temp_script "$MAGIC_COMMAND" "$LINDENS_COMMAND"

    # Run magic command in temp script
    watch $WATCHOPTS "$TMP_FILE"
else
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}SL_TOKEN${WHITE}' value.${NC}${NL}"
    ERROR_CODE=2
fi

# Delete created temp file
[[ -f "$TMP_FILE" ]] && rm -f "$TMP_FILE"

# Check if 'ERROR_CODE' has been defined before exit
if [[ -n $ERROR_CODE ]]; then
    exit $ERROR_CODE
else
    exit 0
fi
