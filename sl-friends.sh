#!/usr/bin/env bash

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

# Config
DEBUG=true
SL_TOKEN=""
SL_TOKEN_ENCODED=false
SL_FRIENDS_URL="https://secondlife.com/my/loadWidgetContent.php?widget=widgetFriends"
SL_HTML_ID="#widgetFriendsOnlineContent"
SL_REFRESH_DELAY=5
SL_STATUS_FILTER="online"
SL_INTERNAL_NAMES=false
WATCH_TITLE=true
# TMP_FILE="/tmp/`basename $0`"
TMP_FILE="/dev/shm/`basename $0`"

# Source config file if exist
[[ -f "`dirname $0`/sl-friends.conf" ]] && source "`dirname $0`/sl-friends.conf"

# Binaries
BIN_CURL=`which curl`
BIN_GREP=`which grep`
BIN_HTMLQ=`which htmlq`
BIN_SED=`which sed`
BIN_WATCH=`which watch`

# Test binaries
if [[ $BIN_CURL == "" ]]; then
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
fi

# Functions
function make_temp_script {
    if [[ $DEBUG == true ]]; then
        echo -e "${NL}${LIGHTPURPLE}[DEBUG]${WHITE} Received: ${LIGHTGREEN}${1}${NC}${NL}"
    fi

    echo "#!/usr/bin/env bash" > $TMP_FILE
    echo -e "$1" >> $TMP_FILE
    chmod +x $TMP_FILE
}
function show_help {
    cat <<EOF

Usage: $0

Arguments:

    -c|--config </path/to/config/file> (Default: ./sl-friends.conf)
    -t|--token <session-token> (Warning: should not be used as the token will be stored in the command history!)
    -f|--filter <online|offline> (Default: $SL_STATUS_FILTER)
    -u|--url <second-life-friends-url> (Default: $SL_FRIENDS_URL)
    -q|--html-id <second-life-html-id-to-target> (Default: $SL_HTML_ID)
    -b|--base64 (Decode base64 encoded session token. [implies -t|--token] - Default: $SL_TOKEN_ENCODED)
    -i|--show-internal-names (Show Second Life internal names. Default: false)
    -n|--no-title (Remove 'watch' command title displayed. Default: false)
    -r|--refresh <seconds> (Define 'watch' command refresh rate. Default: $SL_REFRESH_DELAY seconds)
    -h|--help (Show this message)
    --debug (Enable debug output when disabled by default)
    -D (Disable debug output when enabled by default)

Examples:

    `basename $0`
    `basename $0` -inr 10
    `basename $0` --show-internal-names --no-title --refresh 10
    `basename $0` -t [ask for session-token]
    `basename $0` --token [ask for session-token]
    `basename $0` -bt <base64 encoded session-token>
    `basename $0` --base64 --token <base64 encoded session-token>
    `basename $0` -f offline
    `basename $0` --filter offline

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
# watch -n${SL_REFRESH_DELAY} "curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
    MAGIC_COMMAND="curl --silent -b session-token=`echo $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
else
    MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
fi

# Arguments
WATCHOPTS="-n${SL_REFRESH_DELAY}"
SHORTOPTS="b,c:,n,r:,t::,u:,q:,f:,i,h,D"
LONGOPTS="base64,config:,no-title,refresh,token::,url:,html-id:,filter:,show-internal-names,help,debug,thc"
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

            if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -b session-token=`echo -n $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            else
                MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            fi

            # make_temp_script "$MAGIC_COMMAND"

            # shift
            ;;
        -c|--config)
            unset MAGIC_COMMAND
            SL_CONFIG_FILE="$2"
            [[ ! -f $SL_CONFIG_FILE ]] && echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Specified config file '${YELLOW}${2}${WHITE}' does not exist.${NC}${NL}" && exit 3
            source $SL_CONFIG_FILE

            if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -b session-token=`echo -n $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            else
                MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            fi

            # make_temp_script "$MAGIC_COMMAND"

            shift
            ;;
        -t|--token)
            unset MAGIC_COMMAND
            unset SL_TOKEN

            if [[ $4 == "" && $2 == "" ]]; then
                if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                    SL_TOKEN=$(read -sp "Enter your session token (output hidden for security reason): " TMP_TOKEN && echo -n $TMP_TOKEN)
                else
                    SL_TOKEN=$(read -sp "Enter your session token (output hidden for security reason): " TMP_TOKEN && echo -n $TMP_TOKEN | base64 -)
                fi
                MAGIC_COMMAND="curl --silent -b session-token=`echo -n $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            else
                if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                    MAGIC_COMMAND="curl --silent -b session-token=`echo -n $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
                else
                    MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
                fi
            fi

            # make_temp_script "$MAGIC_COMMAND"

            clear

            shift
            ;;
        -f|--filter)
            unset MAGIC_COMMAND
            unset SL_STATUS_FILTER
            SL_STATUS_FILTER="$2"

            if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -b session-token=`echo $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            else
                MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            fi

            # make_temp_script "$MAGIC_COMMAND"

            shift
            ;;
        -u|--url)
            unset MAGIC_COMMAND
            unset SL_FRIENDS_URL
            SL_FRIENDS_URL="$2"

            if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -b session-token=`echo $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            else
                MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            fi

            # make_temp_script "$MAGIC_COMMAND"

            shift
            ;;
        -q|--html-id)
            unset MAGIC_COMMAND
            unset SL_HTML_ID
            SL_HTML_ID="$2"

            if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -b session-token=`echo $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            else
                MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||' | sed -e 's/ Resident//'"
            fi

            # make_temp_script "$MAGIC_COMMAND"

            shift
            ;;
        -r|--refresh)
            unset SL_REFRESH_DELAY
            unset WATCHOPTS
            SL_REFRESH_DELAY="$2"
            WATCHOPTS="-n${2}"
            
            [[ $WATCH_TITLE == false ]] && WATCHOPTS="${WATCHOPTS} -t"
            # if [[ $SL_INTERNAL_NAMES == true ]]; then
            #     if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
            #         MAGIC_COMMAND="curl --silent -b session-token=`echo $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||'"
            #     else
            #         MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||'"
            #     fi
            # fi

            # make_temp_script "$MAGIC_COMMAND"

            shift
            ;;
        -i|--show-internal-names)
            unset MAGIC_COMMAND
            unset SL_INTERNAL_NAMES
            SL_INTERNAL_NAMES=true

            if [[ ! -z $SL_TOKEN_ENCODED && $SL_TOKEN_ENCODED == true ]]; then
                MAGIC_COMMAND="curl --silent -b session-token=`echo $SL_TOKEN | base64 -d` $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||'"
            else
                MAGIC_COMMAND="curl --silent -b session-token=${SL_TOKEN} $SL_FRIENDS_URL | htmlq '${SL_HTML_ID}' | grep -i -A2 'trigger ${SL_STATUS_FILTER}' | grep -i 'span' | grep -v '<br>' | sed -e 's/<span title=\"/(/' | sed -e 's/\">/) /' | sed -e 's|</span>||'"
            fi

            # make_temp_script "$MAGIC_COMMAND"

            # shift
            ;;
        -n|--no-title)
            unset WATCH_TILE
            WATCH_TITLE=false
            [[ $WATCH_TITLE == false ]] && WATCHOPTS="${WATCHOPTS} -t"

            # make_temp_script "$MAGIC_COMMAND"

            # shift
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
            echo -e "${NL}${WHITE}!!Greets to ${LIGHTGREEN}Van Hauser${WHITE}, ${YELLOW}Plasmoid${WHITE}, ${LIGHTRED}Skyper${WHITE} and the rest of ${LIGHTGREEN}T${YELLOW}H${LIGHTRED}C${WHITE}!! - by Jiab77${NC}${NL}"
            exit 3
            ;;
    esac

    shift
done

# Debug
if [[ $DEBUG == true ]]; then
    echo -e "${NL}${LIGHTPURPLE}[DEBUG]${WHITE} Config:${NC}${NL}"
    echo "ARGS: $ARGS"
    echo "SL_FRIENDS_URL: $SL_FRIENDS_URL"
    echo "SL_HTML_ID: $SL_HTML_ID"
    echo "SL_STATUS_FILTER: $SL_STATUS_FILTER"
    echo "SL_INTERNAL_NAMES: $SL_INTERNAL_NAMES"
    echo "SL_TOKEN: $SL_TOKEN"
    echo "SL_TOKEN_ENCODED: $SL_TOKEN_ENCODED"
    echo "SL_REFRESH_DELAY: $SL_REFRESH_DELAY"
    echo "WATCHOPTS: $WATCHOPTS"
    echo "REMAINING ARGS: $*"
    echo "MAGIC_COMMAND: $MAGIC_COMMAND"
    # exit 0
fi

# Check if the required session-token is defined
if [[ ! -z $SL_TOKEN && ! -z $MAGIC_COMMAND ]]; then
    # Create initial temp script
    make_temp_script "$MAGIC_COMMAND"

    # Run magic command in temp script
    # watch $WATCHOPTS "$MAGIC_COMMAND"
    watch $WATCHOPTS $TMP_FILE
else
    echo -e "${NL}${LIGHTRED}[ERROR]${WHITE} Missing '${YELLOW}SL_TOKEN${WHITE}' value.${NC}${NL}"
    ERROR_CODE=2
fi

# Delete created temp file
[[ -f $TMP_FILE ]] && rm -f $TMP_FILE

# Check if 'ERROR_CODE' has been defined before exit
if [[ ! -z $ERROR_CODE ]]; then
    exit $ERROR_CODE
else
    exit 0
fi
