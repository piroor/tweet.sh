# tweet.sh, a pure Bash script Twitter client

## Usage

~~~
$ ./tweet.sh [command] [...arguments]'
~~~

Available commands are:

 * `post`: posts a new tweet.'
 * `search`: searches tweets.'

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

