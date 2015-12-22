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

If there is a key file named `tweet.client.key` in the current directory, `tweet.js` will load it.
Otherwise, the file `~/.tweet.client.key` will be used as the default key file.

## Usage

~~~
$ ./tweet.sh [command] [...arguments]'
~~~

Available commands are:

 * `post`: posts a new tweet.
 * `search`: searches tweets.

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

