# tweet.sh, a Twitter client written in simple Bash script

## Setup

You need to prepare API keys at first.
Go to [the front page](https://apps.twitter.com/), create a new app, and generate a new access token.

Then put them as a key file at `~/.tweet.client.key`, with the format:

~~~
MY_SCREEN_NAME=xxxxxxxxxxxxxxxxxxx
MY_LANGUAGE=xx
CONSUMER_KEY=xxxxxxxxxxxxxxxxxxx
CONSUMER_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACCESS_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACCESS_TOKEN_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
~~~

If there is a key file named `tweet.client.key` in the current directory, `tweet.sh` will load it.
Otherwise, the file `~/.tweet.client.key` will be used as the default key file.

Moreover, you can give those information via environment variables without a key file.

~~~
$ export MY_SCREEN_NAME=xxxxxxxxxxxxxxxxxxx
$ export MY_LANGUAGE=xx
$ export CONSUMER_KEY=xxxxxxxxxxxxxxxxxxx
$ export CONSUMER_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ export ACCESS_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ export ACCESS_TOKEN_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ ./tweet.sh post "Hello!"
~~~

This form will be useful to implement a bot program.

And, this script uses some external commands.
You need to install them via package system on your environment: `apt`, `yum` or something.
Required commands are:

 * `curl`
 * `jq`
 * `nkf`
 * `openssl`

## Usage

~~~
$ ./tweet.sh [command] [...arguments]
~~~

Available commands are:

 * `help`: shows usage of the `tweet.sh` itself.
 * Reading existing tweets (require "Read" permission)
   * `fetch` (`get`, `show`): fetches a JSON string of a tweet.
   * `search`: searches tweets with queries.
   * `watch-mentions` (`watch`): watches mentions, retweets, DMs, etc., and executes handlers for each event.
   * `type`: detects the type of the given input.
   * `body`: extracts the body of a tweet.
   * `owner`: extracts the owner of a tweet.
   * `showme`: reports the raw information of yourself.
   * `whoami`: reports the screen name of yourself.
   * `language` (`lang`): reports the selected language of yourself.
 * Making some changes (require "Write" permission)
   * `post` (`tweet`, `tw`): posts a new tweet.
   * `reply`: replies to an existing tweet.
   * `upload`: uploads a media file.
   * `delete` (`del`, `remove`, `rm`): deletes a tweet.
   * `favorite` (`fav`): marks a tweet as a favorite.
   * `unfavorite` (`unfav`): removes favorited flag of a tweet.
   * `retweet` (`rt`): retweets a tweet.
   * `unretweet` (`unrt`): deletes the retweet of a tweet.
   * `follow`: follows a user.
   * `unfollow`: unfollows a user.
 * Operate direct messages (require "Access direct messages" permission)
   * `fetch-direct-messages` (`fetch-dm`, `get-direct-messages`, `get-dm`): fetches recent DMs.
   * `direct-message` (`dm`): sends a DM.
 * Misc.
   * `resolve`: resolves a shortened URL.
   * `resolve-all`: resolve all shortened URLs in the given input.

If you hope to handle DMs by the `watch-mentions` command, you have to permit the app to access direct messages.

Detailed logs can be shown with the `DEBUG` flag, like:

~~~
$ env DEBUG=1 ./tweet.sh search -q "Bash"
~~~

This script is mainly designed to be a client library to implement Twitter bot program, instead for daily human use.
For most cases this script reports response JSONs of Twitter's APIs via the standard output.
See descriptions of each JSON: [a tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid), [an event](https://dev.twitter.com/streaming/overview/messages-types#Events_event), and other responses also.

Some commands require URL of a tweet, and they accept shortened URLs like `http://t.co/***`. Such URLs are automatically resolved as actual URLs like `https://twitter.com/***/status/***`. The detectipn pattern for such shortened URLs is defined as `URL_REDIRECTORS` in the script, and it must be updated for new services.

## Reading existing tweets

### `fetch` (`get`, `show`): fetches a JSON string of a tweet

 * Parameters
   * 1st argument: the ID or the URL of the tweet.
 * Standard output
   * [A JSON string of the fetched tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid).
 * Example
   
   ~~~
   $ ./tweet.sh fetch 0123456789
   $ ./tweet.sh fetch https://twitter.com/username/status/0123456789
   $ ./tweet.sh get 0123456789
   $ ./tweet.sh show 0123456789
   ~~~

### `search`: searches tweets with queries.

 * Parameters
   * `-q`: queries.
     If you specify no query, then you'll see [sample tweets](https://dev.twitter.com/streaming/reference/get/statuses/sample) as results.
   * `-c`: maximum number of tweets to be responded. 10 by default. (optional)
   * `-s`: the id of the last tweet already known. (optional)
     If you specify this option, only tweets newer than the given tweet will be returned.
   * `-m`: the id of the tweet you are searching tweets older than it. (optional)
     If you specify this option, only tweets older than the given tweet will be returned.
   * `-t`: type of results. (optional)
     Possible values: `recent`  (default), `popular`, or `mixed`.
   * `-h`: command line to run for each search result. (optional)
     (It will receive [tweets](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid) via the standard input.)
   * `-w`: start watching without handler. (optional)
 * Standard output
   * [A JSON string of the search result](https://dev.twitter.com/rest/reference/get/search/tweets).
 * Example
   
   ~~~
   $ ./tweet.sh search -q "queries" -c 10
   $ ./tweet.sh search -q "Bash OR Shell Script"
   $ ./tweet.sh search -q "Bash OR Shell Script" -h 'echo "found!"; cat'
   $ ./tweet.sh search -q "Bash OR Shell Script" -w |
       while read -r tweet; do echo "found!: ${tweet}"; done
   ~~~

#### Streaming

Basically this command provides ability to get search result based on the given query.

If you hope to observe new tweets matched to the query continuously, specify a callback command line as the handler via the `-h` option.

~~~
$ ./tweet.sh search -q "queries" -h "echo 'FOUND'; cat"
~~~

In this case, only `-q` and `-h` options are available.
The script doesn't exit automatically if you specify the `-h` option.
To stop the process, you need to send the `SIGINT` signal via Ctrl-C or something.

*Important note: you cannot use this feature together with `watch-mentions` command. Only one streaming API is allowed for you at once.*
*If you hope to watch search results with mentions, use the `-k` and `-s` options of the `watch-mentions` command.*

### `watch-mentions` (`watch`): watches mentions, retweets, DMs, etc., and executes handlers for each event.

 * Parameters
   * `-k`: comma-separated list of tracking keywords.
   * `-m`: command line to run for each reply or mention. (optional)
     (It will receive [mention tweets](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid) via the standard input.)
   * `-r`: command line to run for each retweet. (optional)
     (It will receive [retweet tweets](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid) via the standard input.)
   * `-q`: command line to run for each quotation. (optional)
     (It will receive [quotation tweets](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid) via the standard input.)
   * `-f`: command line to run when a user follows you. (optional)
     (It will receive [`follow` event](https://dev.twitter.com/streaming/overview/messages-types#Events_event) via the standard input.)
   * `-d`: command line to run when a DM is received. (optional)
     (It will receive [quotation tweets](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid) via the standard input.)
   * `-s`: command line to run for each search result, matched to the keywords given via the `-k` option. (optional)
 * Standard output
   * Nothing.
 * Example 1: without handlers
   
   ~~~
   $ ./tweet.sh watch-mentions -k "keyword1,keyword2,..." |
       while read -r event; do echo "event: ${event}"; done
   ~~~
 * Example 2: with handlers
   
   ~~~
   $ ./tweet.sh watch-mentions -k "keyword1,keyword2,..." \
                               -r "echo 'REPLY'; cat" \
                               -t "echo 'RT'; cat" \
                               -q "echo 'QT'; cat" \
                               -f "echo 'FOLLOWED'; cat" \
                               -d "echo 'DM'; cat" \
                               -s "echo 'SEARCH-RESULT'; cat"
   ~~~

This command provides ability to observe various events around you or any keyword.

In this case this script stays running.
To stop the process, you need to send the `SIGINT` signal via Ctrl-C or something.

*Important note: you cannot use this feature together with `search` command with a handler. Only one streaming API is allowed for you at once.*
*If you hope to watch search results with mentions, use the `-k` and `-s` options instead of the `search` command.*

### `type`: detects the type of the given input.

 * Parameters
   * The standard input: [a JSON string of a tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid).
   * `-k`: comma-separated list of keywords which are used for "search".
 * Standard output
   * The data type detected from the input.
     Possible values:
     * `event-follow`: An event when you are followed.
     * `direct-message`: A direct message. It can be wrapped with a key `direct_message`.
     * `quotation`: A commented RT.
     * `retweet`: An RT.
     * `mention`: A mention or reply.
     * `search-result`: A tweet which is matched to the given keywords.
 * Example
   
   ~~~
   $ echo "$tweet_json" | ./tweet.sh type -k keyword1,keyword2
   ~~~

This command provides ability to detect the type of each object returned from the [user stream](https://dev.twitter.com/streaming/userstreams).
For unknown type input, this returns an exit status `1` and reports nothing.

### `body`: extracts the body of a tweet.

 * Parameters
   * The standard input: [a JSON string of a tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid). (optional)
   * 1st argument: the ID or the URL of a tweet. (optional)
 * Standard output
   * The body string of the tweet.
 * Example
   
   ~~~
   $ ./tweet.sh body 0123456789
   $ ./tweet.sh body https://twitter.com/username/status/0123456789
   $ echo "$tweet_json" | ./tweet.sh body
   ~~~

### `owner`: extracts the owner of a tweet.

 * Parameters
   * The standard input: [a JSON string of a tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid). (optional)
   * 1st argument: the ID or the URL of a tweet. (optional)
 * Standard output
   * The screen name of the owner.
 * Example
   
   ~~~
   $ ./tweet.sh owner 0123456789
   $ ./tweet.sh owner https://twitter.com/username/status/0123456789
   $ echo "$tweet_json" | ./tweet.sh owner
   ~~~

### `showme`: reports the raw information of yourself.

 * Parameters
   * Nothing.
 * Standard output
   * [A JSON string of the credentials API](https://dev.twitter.com/rest/reference/get/account/verify_credentials).
 * Example
   
   ~~~
   $ ./tweet.sh showme
   ~~~

This will be useful if you hope to get both informations `whoami` and `language` at once.

### `whoami`: reports the screen name of yourself.

 * Parameters
   * Nothing.
 * Standard output
   * The screen name of yourself.
 * Example
   
   ~~~
   $ ./tweet.sh whoami
   username
   ~~~

*Important note: the rate limit of the [API used by this command](https://dev.twitter.com/rest/reference/get/account/verify_credentials) is very low. If you hope to call another `language` command together, then you should use `showme` command instead.*

### `language` (`lang`): reports the selected language of yourself.

 * Parameters
   * Nothing.
 * Standard output
   * The language code selected by yourself.
 * Example
   
   ~~~
   $ ./tweet.sh language
   en
   $ ./tweet.sh lang
   en
   ~~~

*Important note: the rate limit of the [API used by this command](https://dev.twitter.com/rest/reference/get/account/verify_credentials) is very low. If you hope to call another `whoami` command together, then you should use `showme` command instead.*


## Making some changes

### `post` (`tweet`, `tw`): posts a new tweet.

 * Parameters
   * `-m`: comma-separated list of uploaded media IDs. See also the `upload` command.
   * All rest arguments: the body of a new tweet to be posted.
 * Standard output
   * [A JSON string of the posted tweet](https://dev.twitter.com/rest/reference/post/statuses/update).
 * Example
   
   ~~~
   $ ./tweet.sh post A tweet from command line
   $ ./tweet.sh post 何らかのつぶやき
   $ ./tweet.sh tweet @friend Good morning.
   $ ./tweet.sh tw -m 123,456,789 My Photos!
   ~~~

All rest arguments following to the command name are posted as a tweet.
If you include a user's screen name manually in the body, it will become a mention (not a reply).

### `reply`: replies to an existing tweet.

 * Parameters
   * `-m`: comma-separated list of uploaded media IDs. See also the `upload` command.
   * 1st rest argument: the ID or the URL of a tweet to be replied.
   * All other rest arguments: the body of a new reply to be posted.
 * Standard output
   * [A JSON string of the posted reply tweet](https://dev.twitter.com/rest/reference/post/statuses/update).
 * Example
   
   ~~~
   $ ./tweet.sh reply 0123456789 @friend A regular reply
   $ ./tweet.sh reply 0123456789 A silent reply
   $ ./tweet.sh reply https://twitter.com/username/status/0123456789 @friend A regular reply
   $ ./tweet.sh reply https://twitter.com/username/status/0123456789 A silent reply
   $ ./tweet.sh reply 0123456789 -m 123,456,789 Photo reply
   ~~~

Note that you have to include the user's screen name manually if it is needed.
This command does not append it automatically.

### `upload`: uploads a file.

 * Parameters
   * 1st argument: absolute path to a local file.
 * Standard output
   * [A JSON string of the uplaod result](https://dev.twitter.com/rest/media/uploading-media).
 * Example
   
   ~~~
   $ ./tweet.sh upload /path/to/file.png
   ~~~

### `delete` (`del`, `remove`, `rm`): deletes a tweet.

 * Parameters
   * 1st argument: the ID or the URL of a tweet to be deleted.
 * Standard output
   * [A JSON string of the deleted tweet](https://dev.twitter.com/rest/reference/post/statuses/destroy/%3Aid).
 * Example
   
   ~~~
   $ ./tweet.sh delete 0123456789
   $ ./tweet.sh del https://twitter.com/username/status/0123456789
   $ ./tweet.sh remove 0123456789
   $ ./tweet.sh rm https://twitter.com/username/status/0123456789
   ~~~

### `favorite` (`fav`): marks a tweet as a favorite.

 * Parameters
   * 1st argument: the ID or the URL of a tweet to be favorited.
 * Standard output
   * [A JSON string of the favorited tweet](https://dev.twitter.com/rest/reference/post/favorites/create).
 * Example
   
   ~~~
   $ ./tweet.sh favorite 0123456789
   $ ./tweet.sh favorite https://twitter.com/username/status/0123456789
   $ ./tweet.sh fav 0123456789
   $ ./tweet.sh fav https://twitter.com/username/status/0123456789
   ~~~

### `unfavorite` (`unfav`): removes favorited flag of a tweet.

 * Parameters
   * 1st argument: the ID or the URL of a tweet to be unfavorited.
 * Standard output
   * [A JSON string of the unfavorited tweet](https://dev.twitter.com/rest/reference/post/favorites/destroy).
 * Example
   
   ~~~
   $ ./tweet.sh unfavorite 0123456789
   $ ./tweet.sh unfavorite https://twitter.com/username/status/0123456789
   $ ./tweet.sh unfav 0123456789
   $ ./tweet.sh unfav https://twitter.com/username/status/0123456789
   ~~~

### `retweet` (`rt`): retweets a tweet.

 * Parameters
   * 1st argument: the ID or the URL of a tweet to be retweeted.
 * Standard output
   * [A JSON string of the new tweet for a retweet](https://dev.twitter.com/rest/reference/post/statuses/retweet/%3Aid).
 * Example
   
   ~~~
   $ ./tweet.sh retweet 0123456789
   $ ./tweet.sh retweet https://twitter.com/username/status/0123456789
   $ ./tweet.sh rt 0123456789
   $ ./tweet.sh rt https://twitter.com/username/status/0123456789
   ~~~

Note, you cannot add extra comment for the retweet.
Instead, if you hope to "quote" the tweet, then you just have to `post` with the URL of the original tweet.

~~~
$ ./tweet.sh post Good news! https://twitter.com/username/status/0123456789
~~~

### `unretweet` (`unrt`): deletes the retweet of a tweet.

 * Parameters
   * 1st argument: the ID or the URL of a tweet to be unretweeted.
 * Standard output
   * [A JSON string of the deleted tweet for a retweet](https://dev.twitter.com/rest/reference/post/statuses/destroy/%3Aid).
 * Example
   
   ~~~
   $ ./tweet.sh unretweet 0123456789
   $ ./tweet.sh unretweet https://twitter.com/username/status/0123456789
   $ ./tweet.sh unrt 0123456789
   $ ./tweet.sh unrt https://twitter.com/username/status/0123456789
   ~~~

### `follow`: follows a user.

 * Parameters
   * 1st argument: the screen name of a user to be followed, or a URL of a tweet.
 * Standard output
   * [A JSON string of the followed user](https://dev.twitter.com/rest/reference/post/friendships/create).
 * Example
   
   ~~~
   $ ./tweet.sh follow @username
   $ ./tweet.sh follow username
   $ ./tweet.sh follow https://twitter.com/username/status/012345
   ~~~

### `unfollow`: unfollows a user.

 * Parameters
   * 1st argument: the screen name of a user to be unfollowed, or a URL of a tweet.
 * Standard output
   * [A JSON string of the unfollowed user](https://dev.twitter.com/rest/reference/post/friendships/destroy).
 * Example
   
   ~~~
   $ ./tweet.sh unfollow @username
   $ ./tweet.sh unfollow username
   $ ./tweet.sh unfollow https://twitter.com/username/status/012345
   ~~~


#Operate direct messages

### `fetch-direct-messages` (`fetch-dm`, `get-direct-messages`, `get-dm`): fetches recent DMs.

 * Parameters
   * `-c`: maximum number of messages to be fetched. 10 by default.
   * `-s`: the id of the last message already known. If you specify this option, only messages newer than the given id will be fetched.
 * Standard output
   * [A JSON string of fetched direct messages](https://dev.twitter.com/rest/reference/get/direct_messages).
 * Example
   
   ~~~
   $ ./tweet.sh fetch-direct-messages -c 20
   $ ./tweet.sh fetch-dm -c 10 -s 0123456789
   $ ./tweet.sh get-direct-messages -c 20
   $ ./tweet.sh get-dm -c 10 -s 0123456789
   ~~~

### `direct-message` (`dm`): sends a DM.

 * Parameters
   * All arguments: the body of a new direct message to be sent.
 * Standard output
   * [A JSON string of the sent direct message](https://dev.twitter.com/rest/reference/post/direct_messages/new).
 * Example
   
   ~~~
   $ ./tweet.sh direct-message @friend Good morning.
   $ ./tweet.sh direct-message friend Good morning.
   $ ./tweet.sh dm @friend Good morning.
   $ ./tweet.sh dm friend Good morning.
   ~~~


#Misc.

### `resolve`: resolves a shortened URL.

 * Parameters
   * 1st argument: a shortened URL.
 * Standard output
   * The resolved original URL.
 * Example
   
   ~~~
   $ ./tweet.sh resolve https://t.co/xxxx
   ~~~

### `resolve-all`: resolve all shortened URLs in the given input.

 * Parameters
   * Nothing.
 * Standard output
   * The given input with resolved URLs.
 * Example
   
   ~~~
   $ cat ./tweet-body.txt | ./tweet.sh resolve-all
   ~~~

