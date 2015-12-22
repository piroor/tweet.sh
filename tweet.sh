#!/usr/bin/env bash
#
# Original: from https://github.com/ryuichiueda/TomoTool
# ===============================================================
# The MIT License
#
# Copyright (C) 2013-2015 Ryuichi Ueda
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# ===============================================================
#
# See also:
#   https://dev.twitter.com/oauth/overview/authentication-by-api-family
#   https://dev.twitter.com/oauth/overview
#   https://dev.twitter.com/oauth/overview/creating-signatures
#
# If you hope to see detailed logs, set an environment variable "DEBUG" to 1 or something.

work_dir="$(pwd)"
tools_dir="$(cd "$(dirname "$0")" && pwd)"

tmp="/tmp/$$"

prepare_tempfile() {
  local key="$1"
  mktemp "$tmp-$key.XXXXXX"
}

cleanup() {
  rm -f "$tmp-*"
}

log() {
  [ "$DEBUG" = '' ] && return 0
  echo "$*" 1>&2
}

exist_command() {
  type "$1" > /dev/null 2>&1
}


if [ "$CONSUMER_KEY" = '' -a \
     -f "$work_dir/tweet.client.key" ]
then
  log 'Using client key at the current directory.'
  source "$work_dir/tweet.client.key"
fi

if [ "$CONSUMER_KEY" = '' -a \
     -f ~/.tweet.client.key ]
then
  log 'Using client key at the home directory.'
  source ~/.tweet.client.key
fi

if [ "$CONSUMER_KEY" = '' -a \
     -f "$tools_dir/tweet.client.key" ]
then
  log 'Using client key at the tools directory.'
  source "$tools_dir/tweet.client.key"
fi


ensure_available() {
  local fatal_error=0

  if [ "$CONSUMER_KEY" = '' ]
  then
    echo 'FATAL ERROR: You need to specify a consumer key via an environment variable "CONSUMER_KEY".' 1>&2
    fatal_error=1
  fi

  if [ "$CONSUMER_SECRET" = '' ]
  then
    echo 'FATAL ERROR: You need to specify a consumer secret via an environment variable "CONSUMER_SECRET".' 1>&2
    fatal_error=1
  fi

  if [ "$ACCESS_TOKEN" = '' ]
  then
    echo 'FATAL ERROR: You need to specify an access token via an environment variable "ACCESS_TOKEN".' 1>&2
    fatal_error=1
  fi

  if [ "$ACCESS_TOKEN_SECRET" = '' ]
  then
    echo 'FATAL ERROR: You need to specify an access token secret via an environment variable "ACCESS_TOKEN_SECRET".' 1>&2
    fatal_error=1
  fi

  if ! exist_command nkf
  then
    echo 'FATAL ERROR: A required command "nkf" is missing.' 1>&2
    fatal_error=1
  fi

  if ! exist_command curl
  then
    echo 'FATAL ERROR: A required command "curl" is missing.' 1>&2
    fatal_error=1
  fi

  if ! exist_command openssl
  then
    echo 'FATAL ERROR: A required command "openssl" is missing.' 1>&2
    fatal_error=1
  fi

  if ! exist_command jq
  then
    echo 'FATAL ERROR: A required command "jq" is missing.' 1>&2
    fatal_error=1
  fi

  [ $fatal_error = 1 ] && exit 1
}


#================================================================
# sub commands

help() {
  local command="$1"
  shift

  case "$command" in
    '' )
      echo 'Usage:'
      echo '  ./tweet.sh [command] [...arguments]'
      echo ''
      echo 'Available commands:'
      echo '  post           : posts a new tweet.'
      echo '  search         : searches tweets.'
      echo '  watch-mentions : watches mentions as a stream.'
      echo ''
      echo 'For more details, see also: "./tweet.sh help [command]"'
      ;;
    post )
      echo 'Usage:'
      echo '  ./tweet.sh post A tweet from command line'
      echo '  ./tweet.sh post 何らかのつぶやき'
      ;;
    search )
      echo 'Usage:'
      echo '  ./tweet.sh search -q "queries" -l "ja" -c 10'
      echo '  ./tweet.sh search -q "Bash OR Shell Script"'
      ;;
    watch-mentions )
      echo 'Usage:'
      echo "  ./tweet.sh watch-mentions -m \"echo 'MENTION'; cat\" -r \"echo 'RT'; cat\" -q \"echo 'QT'; cat\""
      ;;
  esac
}

post() {
  ensure_available
  echo "status $*" | call_api POST https://api.twitter.com/1.1/statuses/update.json
}

search() {
  ensure_available
  local lang='en'
  local locale='en'
  local count=10

  OPTIND=1
  while getopts q:l:c: OPT
  do
    case $OPT in
      q )
        query="$OPTARG"
        ;;
      l )
        lang="$OPTARG"
        ;;
      c )
        count="$OPTARG"
        ;;
    esac
  done

  [ "$lang" = 'ja' ] && locale='ja'

  cat << FIN | call_api GET https://api.twitter.com/1.1/search/tweets.json
q $query
lang $lang
locale $locale
result_type recent
count $count
FIN
}

watch_mentions() {
  ensure_available

  local credentials="$(call_api GET https://api.twitter.com/1.1/account/verify_credentials.json)"
  local user_screen_name="$(echo "$credentials" | jq -r .screen_name | tr -d '\n')"
  echo "Tracking mentions for $user_screen_name..." 1>&2

  cat << FIN | call_api GET https://userstream.twitter.com/1.1/user.json | handle_mentions "$user_screen_name" "$@"
replies all
track $user_screen_name
FIN
}

handle_mentions() {
  local user_screen_name=$1
  shift

  local mention_handler=''
  local retweet_handler=''
  local quoted_handler=''

  OPTIND=1
  while getopts m:r:q: OPT
  do
    case $OPT in
      m )
        mention_handler="$OPTARG"
        ;;
      r )
        retweet_handler="$OPTARG"
        ;;
      q )
        quoted_handler="$OPTARG"
        ;;
    esac
  done

  local mentions_filter="\"text\":\"[^\"]*@$user_screen_name"
  local retweets_filter="\"text\":\"RT @$user_screen_name:"
  local quoteds_filter="\"quoted_status\":\{[^{]\*\"user\":\{[^{}]\*\"screen_name\":\"$user_screen_name\""

  local filters=''
  [ "$mention_handler" != '' ] && filters="$filters|$mentions_filter"
  [ "$retweet_handler" != '' ] && filters="$filters|$retweets_filter"
  [ "$quoted_handler" != '' ] && filters="$filters|$quoteds_filter"
  filters="$(echo "$filters" | sed 's/^|//')"

  log "FILTERS $filters"
  if [ "$filters" = '' ]
  then
    echo "ERROR: No handler is supplied." 1>&2
    exit 1
  fi

  local self_tweet_filter="^\{[^{]\*\"user\":\{[^{}]\*\"screen_name\":\"$user_screen_name\""
  local filtered
  local owner
  while read line
  do
    filtered="$(echo "$line" |
                  egrep "($filters)" |
                  egrep -v "$self_tweet_filter")"
    [ "$filtered" = '' ] && continue

    # Detect quotation at first, because quotation can be
    # deteted as retweet or a simple mention unexpectedly.
    if [ "$(echo "$filtered" | egrep "$quoteds_filter")" != '' ]
    then
      log "QUOTATION"
      echo "$filtered" |
        (cd "$work_dir"; eval "$quoted_handler")
    # Detect retweet before reqply, because "RT: @(screenname)"
    # can be deteted as a simple mention unexpectedly.
    elif [ "$(echo "$filtered" | egrep "$retweet_filter")" != '' ]
    then
      log "RETWEET"
      echo "$filtered" |
        (cd "$work_dir"; eval "$retweet_handler")
    else
      log "MENTION"
      echo "$filtered" |
        (cd "$work_dir"; eval "$mention_handler")
    fi
  done
}



#================================================================
# utilities to operate text

url_encode() {
  nkf -wMQx | \
    sed 's/=$//' | \
    tr '=' '%' | \
    tr -d '\n' |
    sed -e 's/%7E/~/g' \
        -e 's/%5F/_/g' \
        -e 's/%2D/-/g' \
        -e 's/%2E/./g'
}

# usage:
#   $ cat params
#   param1 aaa
#   param2 b b b
#   $ cat params | to_encoded_list
#   param1=aaa&param2=b%20b%20b
#   $ cat params | to_encoded_list ','
#   param1=aaa,param2=b%20b%20b
to_encoded_list() {
  local delimiter="$1"
  [ "$delimiter" = '' ] && delimiter='\&'
  transformed=$(sort -k 1 -t ' ' |
    sed '/^$/d' |
    while read param
    do
      echo "$param" |
        url_encode |
        sed -e 's/%20/=/' \
            -e "s/\$/${delimiter}/"
    done |
    tr -d '\n' |
    sed "s/${delimiter}\$//")

  echo -n "$transformed"
  log "TRANSFORMED $transformed"
}


#================================================================
# utilities to generate API requests with OAuth authentication

# usage:
# echo 'status つぶやき' | call_api POST https://api.twitter.com/1.1/statuses/update.json
call_api() {
  local method=$1
  local url=$2

  # prepare list of all parameters
  local params_file="$(prepare_tempfile params)"
  if [ -p /dev/stdin ]
  then
    while read param
    do
      echo "$param" >> "$params_file"
    done
  fi

  local oauth="$(cat "$params_file" | generate_oauth_header "$method" "$url")"
  local headers="Authorization: OAuth $oauth"
  local params="$(cat "$params_file" | to_encoded_list)"

  log "METHOD: $method"
  log "URL: $url"
  log "HEADERS: $headers"
  log "PARAMS: $params"

  local debug_params=''
  if [ "$DEBUG" != '' ]
  then
    debug_params='--dump-header - --verbose'
  fi

  if [ "$method" = 'POST' ]
  then
    curl --header "$headers" \
         --data "$params" \
         --silent \
         $debug_params \
         "$url"
  else
    curl --get \
         --header "$headers" \
         --data "$params" \
         --silent \
         $debug_params \
         "$url"
  fi

  rm -f "$params_file"
}

# usage:
#   $ cat params
#   param1 aaa
#   param2 b b b
#   $ cat params | generate_oauth_header POST https://api.twitter.com/1.1/statuses/update.json
#   oauth_consumer_key=xxxxxxxxxxxxxx,oauth_nonce=xxxxxxxxxxxxxxxxx,oauth_signature_method=HMAC-SHA1,oauth_timestamp=xxxxxxxxx,oauth_token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx,oauth_version=1.0,oauth_signature=xxxxxxxxxxxxxxxxxx
generate_oauth_header() {
  local method=$1
  local url=$2

  # prepare list of all parameters
  local params="$(prepare_tempfile params)"

  common_params_file="$(prepare_tempfile common_params)"
  common_params > "$common_params_file"

  cat "$common_params_file" > "$params"

  while read extra_param
  do
    echo "$extra_param" >> "$params"
  done

  # generate OAuth header
  local signature=$(cat "$params" | generate_signature "$method" "$url")
  local header=$(echo "oauth_signature $signature" |
    cat "$common_params_file" - |
    #縦一列を今度は横一列にして 項目=値,項目=値,...の形式に
    to_encoded_list ',' |
    tr -d '\n')

  echo -n "$header"
  log "HEADER $header"

  rm -f "$common_params_file" "$params"
}

# usage:
#   $ cat params
#   param1 aaa
#   param2 b b b
#   $ cat params | generate_signature POST https://api.twitter.com/1.1/statuses/update.json
#   xxxxxxxxxxxxxxxxxxxxxxx
generate_signature() {
  local method=$1
  local url=$2
  local encoded_url="$(echo "$url" | url_encode)"

  # prepare signature key
  local signature_key="$(prepare_tempfile signature_key)"
  echo "${method}&${encoded_url}&" > "$signature_key"

  local signature_source=$(to_encoded_list |
    url_encode |
    #頭に署名キーをつける
    cat "$signature_key" - |
    #改行が一個入ってしまうので取る
    tr -d '\n')
  log "SIGNATURE SOURCE $signature_source"

  # generate signature
  local signature=$(echo -n "$signature_source" |
    #エンコード
    openssl sha1 -hmac $CONSUMER_SECRET'&'$ACCESS_TOKEN_SECRET -binary |
    openssl base64 |
    tr -d '\n')

  echo -n "$signature"
  log "SIGNATURE $signature"

  rm -f "$signature_key"
}

common_params() {
  cat << FIN
oauth_consumer_key $CONSUMER_KEY
oauth_nonce $(date +%s%N)
oauth_signature_method HMAC-SHA1
oauth_timestamp $(date +%s)
oauth_token $ACCESS_TOKEN
oauth_version 1.0
FIN
}


#================================================================

command="$1"
shift

case "$command" in
  post )
    post "$@"
    ;;
  search )
    search "$@"
    ;;
  watch-mentions )
    watch_mentions "$@"
    ;;
  help|* )
    help "$@"
    ;;
esac
