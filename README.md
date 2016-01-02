# tweet.sh, a Twitter client written in simple Bash script

## Setup

You need to prepare API keys at first.
Go to [the front page](https://apps.twitter.com/), create a new app, and generate a new access token.
(If you hope to handle DMs by the `watch-mentions` command, you have to permit the app to access direct messages.)

Then put them as a key file at `~/.tweet.client.key`, with the format:

~~~
CONSUMER_KEY=xxxxxxxxxxxxxxxxxxx
CONSUMER_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACCESS_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACCESS_TOKEN_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
~~~

If there is a key file named `tweet.client.key` in the current directory, `tweet.sh` will load it.
Otherwise, the file `~/.tweet.client.key` will be used as the default key file.

Moreover, you can give those information via environment variables without a key file.

~~~
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
 * `post`: posts a new tweet.
 * `reply`: replies to an existing tweet.
 * `fetch-direct-messages` (`fetch-dm`): fetches recent DMs.
 * `direct-message` (`dm`): sends a DM.
 * `delete` (`del`): deletes a tweet.
 * `search`: searches tweets with queries.
 * `watch-mentions` (`watch`): watches mentions, retweets, DMs, etc., and executes handlers for each event.
 * `favorite` (`fav`): marks a tweet as a favorite.
 * `unfavorite` (`unfav`): removes favorited flag of a tweet.
 * `retweet` (`rt`): retweets a tweet.
 * `unretweet` (`unrt`): deletes the retweet of a tweet.
 * `follow`: follows a user.
 * `unfollow`: unfollows a user.
 * `fetch`: fetches a JSON string of a tweet.
 * `type`: detects the type of the given input.
 * `body`: extracts the body of a tweet.
 * `owner`: extracts the owner of a tweet.
 * `whoami`: reports the screen name of yourself.
 * `language` (`lang`): reports the selected language of yourself.

If you hope to see detailed logs, run the script with an environment variable `DEBUG`, like:

~~~
$ env DEBUG=1 ./tweet.sh search -q "Bash"
~~~

This script is mainly designed to be a client library to implement Twitter bot program, instead for daily human use.
For most cases this script reports response JSONs of Twitter's APIs via the standard output.
See descriptions of each JSON: [a tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid), [an event](https://dev.twitter.com/streaming/overview/messages-types#Events_event), and other responses also.

## How to post a new tweet?

The `post` command posts a new tweet to your timeline.

~~~
$ ./tweet.sh post A tweet from command line
$ ./tweet.sh post 何らかのつぶやき
~~~

All rest arguments following to the command name are posted as a tweet.

## How to reply to an existing tweet?

If you hope to mention to another user, simply you have to `post` a tweet including his/her screen name.

~~~
$ ./tweet.sh post @friend Good morning.
~~~

When you hope to reply to an existing tweet, you need to use another command `reply`.
You must specify the ID or the URL of the replied tweet.

~~~
$ ./tweet.sh reply 0123456789 @friend A regular reply
$ ./tweet.sh reply 0123456789 A silent reply
$ ./tweet.sh reply https://twitter.com/username/status/0123456789 @friend A regular reply
$ ./tweet.sh reply https://twitter.com/username/status/0123456789 A silent reply
~~~

All rest arguments following to the command name and the tweet's identifier are posted as a tweet.

Note that you have to include the user's screen name manually if it is needed.
The `reply` command does not append it automatically.

## How to delete a tweet?

You can delete your tweet via the `delete` (`del`) command.
You must specify the ID or the URL of the tweet which is deleted.

~~~
$ ./tweet.sh delete 0123456789
$ ./tweet.sh delete https://twitter.com/username/status/0123456789
$ ./tweet.sh del 0123456789
$ ./tweet.sh del https://twitter.com/username/status/0123456789
~~~

## How to search tweets?

You can search tweets based on queries with the command `search`.

~~~
$ ./tweet.sh search -q "queries" -l "ja" -c 10
$ ./tweet.sh search -q "Bash OR Shell Script"
~~~

Available options:

 * `-q`: queries.
 * `-l`: language.
 * `-c`: maximum number of tweets to be responded. 10 by default.
 * `-s`: the id of the last tweet already known. If you specify this option, only tweets newer than the given tweet will be returned.

Then matched tweets will be reported via the standard output.

If you hope to observe new tweets matched to the query continuously, specify a callback command line as the handler via the `-h` option.

~~~
$ ./tweet.sh search -q "queries" -h "echo 'FOUND'; cat"
~~~

In this case, only following options are available:

 * `-q`: queries.
 * `-h`: command line to run for each search result.

Handler command line will receive a JSON string of a [matched tweet](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid) via the standard input.

In this case this script stays running.
To stop the process, you need to send the `SIGINT` signal via Ctrl-C or something.

*Important note: you cannot use this feature together with `watch-mentions` command. Only one streaming API is allowed for you at once.*
*If you hope to watch search results with mentions, use the `-k` and `-s` options of the `watch-mentions` command.*

## How to watch various mentions?

If you hope to observe mentions and other events around you or any keyword, `watch-mentions` (`watch`) command will help you.

~~~
$ ./tweet.sh watch-mentions -k "keyword1,keyword2,..." \
                            -r "echo 'REPLY'; cat" \
                            -t "echo 'RT'; cat" \
                            -q "echo 'QT'; cat" \
                            -f "echo 'FOLLOWED'; cat" \
                            -d "echo 'DM'; cat" \
                            -s "echo 'SEARCH-RESUT'; cat"
~~~

Available options:

 * `-k`: comma-separated list of tracking keywords.
 * `-m`: command line to run for each reply or mention.
 * `-r`: command line to run for each retweet.
 * `-q`: command line to run for each quotation.
 * `-f`: command line to run when a user follows you.
 * `-d`: command line to run when a DM is received.
 * `-s`: command line to run for each search result, matched to the keywords given via the `-k` option.

Handler command lines will receive a JSON string of the [mention](https://dev.twitter.com/rest/reference/get/statuses/show/%3Aid), [DM](https://dev.twitter.com/rest/reference/get/direct_messages/show), or the [event](https://dev.twitter.com/streaming/overview/messages-types#Events_event) via the standard input.

In this case this script stays running.
To stop the process, you need to send the `SIGINT` signal via Ctrl-C or something.

*Important note: you cannot use this feature together with `search` command with a handler. Only one streaming API is allowed for you at once.*
*If you hope to watch search results with mentions, use the `-k` and `-s` options instead of the `search` command.*

## How to favorite/unfavorite a tweet?

You can mark an existing tweet as a favorited, by the `favorite` (`fav`) command.
You must give the ID or the URL of the tweet to be favorited.

~~~
$ ./tweet.sh favorite 0123456789
$ ./tweet.sh favorite https://twitter.com/username/status/0123456789
$ ./tweet.sh fav 0123456789
$ ./tweet.sh fav https://twitter.com/username/status/0123456789
~~~

To unfavorite a tweet, the inverted version command `unfavorite` (`unfav`) is also available.

~~~
$ ./tweet.sh unfavorite 0123456789
$ ./tweet.sh unfavorite https://twitter.com/username/status/0123456789
$ ./tweet.sh unfav 0123456789
$ ./tweet.sh unfav https://twitter.com/username/status/0123456789
~~~

## How to reweet a tweet?

You can retweet an existing tweet to your follwoers, by the `retweet` (`rt`) command.
You must give the ID or the URL of the tweet to be retweeted.

~~~
$ ./tweet.sh retweet 0123456789
$ ./tweet.sh retweet https://twitter.com/username/status/0123456789
$ ./tweet.sh rt 0123456789
$ ./tweet.sh rt https://twitter.com/username/status/0123456789
~~~

Note, you cannot add extra comment for the RT.
Instead, if you hope to "quote" the tweet, then you just have to `post` with the URL of the original tweet.

~~~
$ ./tweet.sh post Good news! https://twitter.com/username/status/0123456789
~~~

To cancel your retweet, the inverted version command `unretweet` (`unrt`) is also available.
You must give the ID or the URL of the tweet retweeted by you.

~~~
$ ./tweet.sh unretweet 0123456789
$ ./tweet.sh unretweet https://twitter.com/username/status/0123456789
$ ./tweet.sh unrt 0123456789
$ ./tweet.sh unrt https://twitter.com/username/status/0123456789
~~~

## How to follow/unfollow my friend?

There is a command `follow` to follow another user.
You must give the name of the user (sceen name). The "@" can be trimmed.

~~~
$ ./tweet.sh follow @username
$ ./tweet.sh follow username
~~~

To unfollow him/her, simply use the inverted command `unfollow`.

~~~
$ ./tweet.sh unfollow @username
$ ./tweet.sh unfollow username
~~~

## How to fetch a tweet itself?

You must give the ID or the URL of the tweet to the command `fetch`.

~~~
$ ./tweet.sh fetch 0123456789
$ ./tweet.sh fetch https://twitter.com/username/status/0123456789
~~~

Then a JSON string will be reported via the standard output.

## How to read the body of a tweet?

You must give the ID or the URL of the tweet, or a JSON string via the standard input.

~~~
$ ./tweet.sh body 0123456789
$ ./tweet.sh body https://twitter.com/username/status/0123456789
$ echo "$tweet_json" | ./tweet.sh body
~~~

## How to get the owner of a tweet?

You must give the ID or the URL of the tweet, or a JSON string via the standard input.

~~~
$ ./tweet.sh owner 0123456789
$ ./tweet.sh owner https://twitter.com/username/status/0123456789
$ echo "$tweet_json" | ./tweet.sh owner
~~~

## How to detect the type of the input JSON?

There is a command to detect the type of each line returned from the streaming API.
Give the JSON string via the standard input, with the command `type`.

~~~
$ echo "$tweet_json" | ./tweet.sh type -s my_screen_name -k keyword1,keyword2
~~~

Available options:

 * `-s`: the screen name of yourself
 * `-k`: comma-separated list of keywords which are used for "search".

Then the command will reports the detected type via the standard output, one of them:

 * `event-follow`: An event when you are followed.
 * `direct-message`: A direct message. It can be wrapped with a key `direct_message`.
 * `quotation`: A commented RT.
 * `retweet`: An RT.
 * `mention`: A mention or reply.
 * `search-result`: A tweet which is matched to the given keywords.

For unknown type input, this command returns an exit status `1` and reports nothing via the standard output,

## How to get the information of my account?

The `whoami` subcommand simply reports your screen name.

~~~
$ ./tweet.sh whoami
username
~~~

The `language` (`lang`) subcommand reports your language.

~~~
$ ./tweet.sh lang
en
~~~

## How to send a DM for my friend?

If you hope to send a DM to another user, run the `direct-message` (`dm`) command.

~~~
$ ./tweet.sh direct-message @friend Good morning.
$ ./tweet.sh direct-message friend Good morning.
$ ./tweet.sh dm @friend Good morning.
$ ./tweet.sh dm friend Good morning.
~~~

All rest arguments following to the command name and the recipient name are posted as a direct message.

Note that you have to allow to access direct messages to your app.

## How to fetch DMs?

Recent DMs can be fetched by the `fetch-direct-messages` (`fetch-dm`) command.

~~~
$ ./tweet.sh fetch-direct-messages -c 20
$ ./tweet.sh fetch-direct-messages -c 10 -s 0123456789
$ ./tweet.sh fetch-dm -c 20
$ ./tweet.sh fetch-dm -c 10 -s 0123456789
~~~

Available options:

 * `-c`: maximum number of messages to be fetched. 10 by default.
 * `-s`: the id of the last message already known. If you specify this option, only messages newer than the given id will be fetched.

Then fetched messages will be reported via the standard output.
For details of the format, see also the [API document](https://dev.twitter.com/rest/reference/get/direct_messages).

Note that you have to allow to access direct messages to your app.
