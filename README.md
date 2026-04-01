# sl-friends

A simple script to see your [Second Life](https://secondlife.com) friends connection status from terminal.

> [!NOTE]
> You can find a more modern and much better version of my work called __[sl-friends-tui](https://github.com/ohmymex/sl-friends-tui)__.
> It has been made by my very talented friend __[OhMyMex](https://github.com/ohmymex)__. Please take a look at his work :wink:

## Research

This script is based on the research published [here](https://gist.github.com/Jiab77/6c38f6566d68784f4591b60c0269a8f0).

## Features

* Show online or offline friends in your terminal
* Show subscribed groups and members count
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
SL_STATUS_FILTER="online"
SL_GROUPS_URL="https://secondlife.com/my/widget-groups.php"
SL_FRIENDS_URL="https://secondlife.com/my/widget-friends.php"
SL_LINDENS_URL="https://secondlife.com/my/widget-linden-dollar.php"
SL_GROUPS_LIST_HTML_FILTER=".group-status strong"
SL_GROUPS_MEMBERS_HTML_FILTER=".group-status td"
SL_FRIENDS_HTML_FILTER="#widgetFriendsOnlineContent .friend-status .trigger.${SL_STATUS_FILTER} span[title]"
SL_LINDENS_HTML_FILTER=".main-widget-content strong"
SL_INTERNAL_NAMES=false
SL_GROUPS=false
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
    -G|--show-groups-list (Show subscribed groups list. Default: false)
    -g|--show-groups (Show subscribed groups. Default: false)
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

## Notifications

There is now the possibility to send mobile notifications within the [ntfy.sh](https://ntfy.sh) service and the [ntfy](https://docs.ntfy.sh/#step-1-get-the-app) application.

All you need to do to enable this feature is the following:

1. Create a new config file called `sl-notify.conf` and place it inside your `~/.config` folder, with the following content:

```bash
MOBILE_NOTIF=true
```

2. Install the [ntfy](https://docs.ntfy.sh/#step-1-get-the-app) application and add the given channel name from the script:

```console
Notification sent to: https://ntfy.sh/sl-[REDACTED]
```

> [!NOTE]
> The `[REDACTED]` part will be replaced by your dedicated __User ID__, so keep it in private place and don't share it to anyone!

> [!IMPORTANT]
> If you share your generated __User ID__, anyone knowing it will have access to your connected friends from the notifications.

3. You can test the dedicated script __[sl-notify.sh](sl-notify.sh)__ to verify that the notifications are correctly sent that way:

```console
# Remove existing test file (used to avoid spamming you with tons of notifications)
rm -fv /tmp/.sl-user-connected

# Run the notification script
./sl-notify.sh "single-friend"

# OR multiple friends
./sl-notify.sh "first-friend|second-friend|third-friend|and-so-on"

# Remove the created test file again (to avoid conflicting with the main 'sl-friends.sh' script)
rm -fv /tmp/.sl-user-connected
```

> [!NOTE]
> You normally don't have to run the __[sl-notify.sh](sl-notify.sh)__ script manually as it is automatically called from the __[sl-friends.sh](sl-friends.sh)__ script when called with `-N "first-friend|second-friend|third-friend|and-so-on"`.

> [!IMPORTANT]
> This feature is still quite experimental and may not work properly yet.
> A better implementation might be added in the __[sl-friends-tui](https://github.com/ohmymex/sl-friends-tui)__ version made by my friend __[OhMyMex](https://github.com/ohmymex)__.

## Author

* __Jiab77__

## License

[WFTPL](LICENSE)
