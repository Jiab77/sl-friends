# sl-friends

A simple script to see your [Second Life](https://secondlife.com) friends connection status from terminal.

## Research

This script is based on the research published [here](https://gist.github.com/Jiab77/6c38f6566d68784f4591b60c0269a8f0).

## Features

* Show online or offline friends in your terminal
* Create desktop notification when given friend is connected
* Print your owned L$ (_can be disabled_)

## Screenshot

![image](https://user-images.githubusercontent.com/9881407/136857941-cd9e5248-d325-45d5-bcbc-144769e23f67.png)

> The screenshot might be outdated.

## Dependencies

Normally `awk`, `grep`, `sed` and `watch` should be already available by default on every __Linux__ distributions but not [`htmlq`](https://github.com/mgdm/htmlq). To install it, simply run the following commands:

```bash
# Install 'cargo' (the Rust installer)
sudo apt install -y cargo

# Install 'htmlq' (the required Rust binary)
cargo install htmlq

# Create required symlink
sudo ln -sfvn $(which htmlq) /usr/bin/htmlq
```

## Configuration

You can edit the script and modify the following values:

```conf
DEBUG=true
SL_TOKEN=""
SL_TOKEN_ENCODED=false
SL_FRIENDS_URL="https://secondlife.com/my/widget-friends.php"
SL_FRIENDS_HTML_ID="#widgetFriendsOnlineContent"
SL_LINDENS_URL="https://secondlife.com/my/widget-linden-dollar.php"
SL_LINDENS_HTML_CLASS=".main-widget-content"
SL_REFRESH_DELAY=5
SL_STATUS_FILTER="online"
SL_INTERNAL_NAMES=false
SL_LINDENS=false
SL_NOTIFY=false
CURL_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36"
WATCH_TITLE=true
USE_TOR=false
```

Or simply rename the config template from `sl-friends.template.conf` to __`sl-friends.conf`__ at the root of the script.

You can also use the `-c` or `--config` argument to specifiy another path or config filename.

Most of the configuration values can be also changed with the arguments described in the [usage](#usage) section.

## Installation

```bash
# Make the script executable
chmod -v +x sl-friends.sh

# Make a symlink to /usr/bin (optional)
sudo ln -sfvn `pwd`/sl-friends.sh /usr/bin/sl-friends
```

## Usage

```
$ ./sl-friends.sh -h

Usage: ./sl-friends.sh

Arguments:

    -c|--config </path/to/config/file> (Default: ./sl-friends.conf)
    -t|--token [session-token] (Warning: should not be used as the token will be stored in the command history!)
    -f|--filter <online|offline> (Default: online)
    -u|--url <second-life-friends-url> (Default: https://secondlife.com/my/widget-friends.php)
    -q|--html-id <second-life-html-id-to-target> (Default: #widgetFriendsOnlineContent)
    -a|--user-agent <user-agent string> (Default: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.69 Safari/537.36)
    -b|--base64 (Decode base64 encoded session token. [implies -t|--token] - Default: false)
    -i|--show-internal-names (Show Second Life internal names. Default: false)
    -l|--show-lindens (Show amount of owned linden dollars. Default: false)
    -n|--no-title (Remove 'watch' command title displayed. Default: false)
    -N|--notify <user> (Notify when given user is connected.)
    -r|--refresh <seconds> (Define 'watch' command refresh rate. Default: 5 seconds)
    -h|--help (Show this message)
    --tor (Proxy all requests to Tor using the SOCKS5 Hostname protocol)
    --debug (Enable debug output when disabled by default)
    -D (Disable debug output when enabled by default)

Examples:

    sl-friends.sh
    sl-friends.sh -inr 10
    sl-friends.sh --show-internal-names --no-title --refresh 10
    sl-friends.sh --refresh 10 --notify john.doe
    sl-friends.sh -r 10 -N john.doe
    sl-friends.sh -t (it will ask for session-token)
    sl-friends.sh --token (it will ask for session-token)
    sl-friends.sh -bt <base64 encoded session-token>
    sl-friends.sh --base64 --token <base64 encoded session-token>
    sl-friends.sh -f offline
    sl-friends.sh --filter offline

Note:

As I am still pretty bad in arguments parsing, you might need to place arguments at the right position if you want to chain them...

Error codes:

    1 - Missing required binary
    2 - Missing Second Life session token
    3 - Given config file does not exist

Author:

Jiab77

```

## Author

* __Jiab77__
