# tweet.sh, a pure Bash script Twitter client

## Setup

You need to prepare API keys at first.
Go to [the front page](https://apps.twitter.com/), create a new app, and generate a new access token.
Then put them as a key file at `~/.tweet.client.key`, with the format:

~~~
CONSUMER_KEY=xxxxxxxxxxxxxxxxxxx
CONSUMER_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACCESS_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ACCESS_TOKEN_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
~~~

If there is a key file named `tweet.client.key` in the current directory, `tweet.sh` will load it.
Otherwise, the file `~/.tweet.client.key` will be used as the default key file.

## Usage

~~~
$ ./tweet.sh [command] [...arguments]
~~~

Available commands are:

 * `post`: posts a new tweet.
 * `search`: searches tweets.
 * `watch-mentions`: watches mentions and executes handlers for each mention.
 * `favorite` (`fav`): marks a tweet as a favorite.

If you hope to see detailed logs, run the script with an environment variable `DEBUG`, like:

~~~
$ env DEBUG=1 ./tweet.sh search -q "Bash"
~~~

## How to post a tweet?

For example:

~~~
$ ./tweet.sh post A tweet from command line
$ ./tweet.sh post 何らかのつぶやき
~~~

All rest arguments are posted as a tweet.

## How to search tweets?

For example:

~~~
$ ./tweet.sh search -q "queries" -l "ja" -c 10
$ ./tweet.sh search -q "Bash OR Shell Script"
~~~

Available options:

 * `-q`: queries.
 * `-l`: language.
 * `-c`: count of tweets to be responded. 10 by default.

## How to watch search results with a handler?

For example:

~~~
$ ./tweet.sh search -q "queries" -h "cat"
~~~

Available options:

 * `-q`: queries.
 * `-h`: command line to run for each search result.

Handler command line will receive result via the standard input.

## How to watch mentions?

For example:

~~~
$ ./tweet.sh watch-mentions -r "echo 'REPLY'; cat" \
                            -t "echo 'RT'; cat" \
                            -q "echo 'QT'; cat"
~~~

Available options:

 * `-m`: command line to run for each reply or mention.
 * `-r`: command line to run for each retweet.
 * `-q`: command line to run for each quotation.

Handler command lines will receive mention via the standard input.

## How to mark a tweet as a favorite?

You must give the ID of the tweet.

~~~
$ ./tweet.sh favorite 0123456789
$ ./tweet.sh fav 0123456789
~~~
