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

load_keys() {
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

  export CONSUMER_KEY
  export CONSUMER_SECRET
  export ACCESS_TOKEN
  export ACCESS_TOKEN_SECRET
}

case $(uname) in
  Darwin|*BSD|CYGWIN*)
    esed="sed -E"
    ;;
  *)
    esed="sed -r"
    ;;
esac


ensure_available() {
  local fatal_error=0

  load_keys

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
      echo '  reply          : replies to a tweet.'
      echo '  delete(del)    : deletes a tweet.'
      echo '  direct-message(dm)'
      echo '                 : sends a DM.'
      echo '  search         : searches tweets.'
      echo '  watch-mentions(watch)'
      echo '                 : watches mentions, retweets, DMs, etc.'
      echo '  favorite(fav)  : marks a tweet as a favorite.'
      echo '  unfavorite(unfav)'
      echo '                 : removes favorited flag of a tweet.'
      echo '  retweet(rt)    : retweets a tweet.'
      echo '  unretweet(unrt): deletes the retweet of a tweet.'
      echo '  follow         : follows a user.'
      echo '  unfollow       : unfollows a user.'
      echo '  body           : extracts the body of a tweet.'
      echo '  owner          : extracts the owner of a tweet.'
      echo '  whoami         : reports the screen name of yourself.'
      echo ''
      echo 'For more details, see also: "./tweet.sh help [command]"'
      ;;
    post )
      echo 'Usage:'
      echo '  ./tweet.sh post A tweet from command line'
      echo '  ./tweet.sh post 何らかのつぶやき'
      ;;
    reply )
      echo 'Usage:'
      echo '  ./tweet.sh reply 012345 a reply'
      echo '  ./tweet.sh reply https://twitter.com/username/status/012345 a reply'
      ;;
    del|delete )
      echo 'Usage:'
      echo '  ./tweet.sh del 012345'
      echo '  ./tweet.sh del https://twitter.com/username/status/012345'
      echo '  ./tweet.sh delete 012345'
      echo '  ./tweet.sh delete https://twitter.com/username/status/012345'
      ;;
    dm|direct-message )
      echo 'Usage:'
      echo '  ./tweet.sh dm frinedname Good morning.'
      echo '  ./tweet.sh direct-message frinedname "How are you?"'
      ;;
    search )
      echo 'Usage:'
      echo '  ./tweet.sh search -q "queries" -l "ja" -c 10'
      echo '  ./tweet.sh search -q "Bash OR Shell Script"'
      echo '  ./tweet.sh search -q "queries" -h "cat"'
      ;;
    watch|watch-mentions )
      echo 'Usage:'
      echo '  ./tweet.sh watch-mentions -k keyword1,keyword2'
      echo "                            -m \"echo 'MENTION'; cat\""
      echo "                            -r \"echo 'RT'; cat\""
      echo "                            -q \"echo 'QT'; cat\""
      echo "                            -f \"echo 'FOLLOWED'; cat\""
      echo "                            -d \"echo 'DM'; cat\""
      echo "                            -s \"echo 'SEARCH-RESULT'; cat\""
      ;;
    fav|favorite )
      echo 'Usage:'
      echo '  ./tweet.sh fav 012345'
      echo '  ./tweet.sh fav https://twitter.com/username/status/012345'
      echo '  ./tweet.sh favorite 012345'
      echo '  ./tweet.sh favorite https://twitter.com/username/status/012345'
      ;;
    unfav|unfavorite )
      echo 'Usage:'
      echo '  ./tweet.sh unfav 012345'
      echo '  ./tweet.sh unfav https://twitter.com/username/status/012345'
      echo '  ./tweet.sh unfavorite 012345'
      echo '  ./tweet.sh unfavorite https://twitter.com/username/status/012345'
      ;;
    rt|retweet )
      echo 'Usage:'
      echo '  ./tweet.sh rt 012345'
      echo '  ./tweet.sh rt https://twitter.com/username/status/012345'
      echo '  ./tweet.sh retweet 012345'
      echo '  ./tweet.sh retweet https://twitter.com/username/status/012345'
      ;;
    unrt|unretweet )
      echo 'Usage:'
      echo '  ./tweet.sh unrt 012345'
      echo '  ./tweet.sh unrt https://twitter.com/username/status/012345'
      echo '  ./tweet.sh unretweet 012345'
      echo '  ./tweet.sh unretweet https://twitter.com/username/status/012345'
      ;;
    follow )
      echo 'Usage:'
      echo '  ./tweet.sh follow username'
      echo '  ./tweet.sh follow @username'
      ;;
    unfollow )
      echo 'Usage:'
      echo '  ./tweet.sh unfollow username'
      echo '  ./tweet.sh unfollow @username'
      ;;
    body )
      echo 'Usage:'
      echo '  ./tweet.sh body 012345'
      echo '  ./tweet.sh body https://twitter.com/username/status/012345'
      echo '  echo "$tweet_json" | ./tweet.sh body'
      ;;
    owner )
      echo 'Usage:'
      echo '  ./tweet.sh owner 012345'
      echo '  ./tweet.sh owner https://twitter.com/username/status/012345'
      echo '  echo "$tweet_json" | ./tweet.sh owner'
      ;;
  esac
}

check_errors() {
  if [ "$(echo "$1" | jq -r '.errors | length')" = '0' ]
  then
    return 0
  else
    return 1
  fi
}

post() {
  ensure_available
  local result="$(echo "status $*" | call_api POST https://api.twitter.com/1.1/statuses/update.json)"
  echo "$result"
  check_errors "$result"
}

reply() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/statuses/update.json
status $*
in_reply_to_status_id $id
FIN
  )"
  echo "$result"
  check_errors "$result"
}

delete() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  local result="$(call_api POST "https://api.twitter.com/1.1/statuses/destroy/$id.json")"
  echo "$result"
  check_errors "$result"
}

direct_message() {
  ensure_available

  local target="$1"
  shift

  target="$(echo "$target" | sed 's/^@//')"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/direct_messages/new.json
screen_name $target
text $*
FIN
  )"
  echo "$result"
  check_errors "$result"
}

search() {
  ensure_available
  local lang='en'
  local locale='en'
  local count=10
  local handler=''

  OPTIND=1
  while getopts q:l:c:h: OPT
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
      h )
        handler="$OPTARG"
        ;;
    esac
  done

  [ "$lang" = 'ja' ] && locale='ja'

  if [ "$handler" = '' ]
  then
    local result="$(cat << FIN | call_api GET https://api.twitter.com/1.1/search/tweets.json
q $query
lang $lang
locale $locale
result_type recent
count $count
FIN
    )"
    echo "$result"
    check_errors "$result"
  else
    watch_search_results "$query" "$handler"
  fi
}

watch_search_results() {
  local query="$1"
  local handler="$2"
  echo "Tracking tweets with the query: $query..." 1>&2
  local user_screen_name="$(self_screen_name)"
  cat << FIN | call_api POST https://stream.twitter.com/1.1/statuses/filter.json | handle_search_results "$user_screen_name" "$handler"
track $query
FIN
}

handle_search_results() {
  local user_screen_name="$1"
  local handler="$2"

  local separator='--------------------------------------------------------------'

  local owner
  while read -r line
  do
    if [ "$line" = 'Exceeded connection limit for user' ]
    then
      echo "$line" 1>&2
      exit 1
    fi

    # Ignore self tweet
    owner="$(echo "$line" | extract_owner)"
    [ "$owner" = "$user_screen_name" \
      -o "$owner" = 'null' \
      -o "$owner" = '' ] && continue

    log "$separator"
    log "TWEET DETECTED: Matched to the given query"

    [ "$handler" = '' ] && continue
    echo "$line" |
      (cd "$work_dir"; eval "$handler")
  done
}

self_screen_name() {
  call_api GET https://api.twitter.com/1.1/account/verify_credentials.json |
    jq -r .screen_name |
    tr -d '\n'
}

watch_mentions() {
  ensure_available

  local extra_keywords=''
  OPTIND=1
  while getopts k:m:r:q:f:d:s: OPT
  do
    case $OPT in
      k )
        extra_keywords="$OPTARG"
        ;;
    esac
  done

  local user_screen_name="$(self_screen_name)"
  local tracking_keywords="$user_screen_name"
  [ "$extra_keywords" != '' ] && tracking_keywords="$tracking_keywords,$extra_keywords"

  echo "Tracking mentions for $tracking_keywords..." 1>&2

  cat << FIN | call_api GET https://userstream.twitter.com/1.1/user.json | handle_mentions "$user_screen_name" "$@"
replies all
track $tracking_keywords
FIN
}

handle_mentions() {
  local user_screen_name=$1
  shift

  local keywords_matcher=''
  local mention_handler=''
  local retweet_handler=''
  local quoted_handler=''
  local followed_handler=''
  local dm_handler=''
  local search_handler=''

  OPTIND=1
  while getopts k:m:r:q:f:d:s: OPT
  do
    case $OPT in
      k )
        keywords_matcher="$(echo "$OPTARG" | \
                              sed -e 's/,/|/g' \
                                  -e 's/ +/.*/g')"
        ;;
      m )
        mention_handler="$OPTARG"
        ;;
      r )
        retweet_handler="$OPTARG"
        ;;
      q )
        quoted_handler="$OPTARG"
        ;;
      f )
        followed_handler="$OPTARG"
        ;;
      d )
        dm_handler="$OPTARG"
        ;;
      s )
        search_handler="$OPTARG"
        ;;
    esac
  done

  local separator='--------------------------------------------------------------'

  local sender
  local owner
  local tweet_body
  while read -r line
  do
    if [ "$line" = 'Exceeded connection limit for user' ]
    then
      echo "$line" 1>&2
      exit 1
    fi

    # Events
    case "$(echo "$line" | jq -r .event)" in
      null )
        : # do nothing for tweets at here
        ;;
      follow )
        [ "$followed_handler" = '' ] && continue
        local screen_name="$(echo "$line" | \
                               jq -r .source.screen_name | \
                               tr -d '\n')"
        [ "$screen_name" = "$user_screen_name" ] && continue
        log "$separator"
        log "EVENT DETECTED: Followed by $screen_name"
        echo "$line" |
          (cd "$work_dir"; eval "$followed_handler")
        continue
        ;;
      * ) # ignore other unknown events
        continue
        ;;
    esac

    # handle DM
    sender="$(echo "$line" | jq -r .direct_message.sender_screen_name)"
    if [ "$sender" != '' \
         -a "$sender" != 'null' \
         -a "#sender" != "$user_screen_name" ]
    then
      log "$separator"
      log "DM DETECTED: Sent by @$sender"
      if [ "$dm_handler" != '' ]
      then
        echo "$line" |
          (cd "$work_dir"; eval "$dm_handler")
        continue
      fi
    fi

    # Ignore self tweet or non-tweet object
    owner="$(echo "$line" | extract_owner)"
    log "Tweeted by $owner"
    [ "$owner" = "$user_screen_name" \
      -o "$owner" = 'null'  \
      -o "$owner" = '' ] && continue

    # Detect quotation at first, because quotation can be
    # deteted as retweet or a simple mention unexpectedly.
    if [ "$(echo "$line" | \
              jq -r .quoted_status.user.screen_name | \
              tr -d '\n')" = "$user_screen_name" ]
    then
      log "$separator"
      log "TWEET DETECTED: Retweeted with quotation"
      if [ "$quoted_handler" != '' ]
      then
        echo "$line" |
          (cd "$work_dir"; eval "$quoted_handler")
        continue
      fi
    fi

    tweet_body="$(echo "$line" | body)"

    # Detect retweet before reqply, because "RT: @(screenname)"
    # can be deteted as a simple mention unexpectedly.
    if echo "$tweet_body" | grep "RT @$user_screen_name:" > /dev/null
    then
      log "$separator"
      log "TWEET DETECTED: Retweeted"
      if [ "$retweet_handler" = '' ]
      then
        echo "$line" |
          (cd "$work_dir"; eval "$retweet_handler")
        continue
      fi
    fi

    if echo "$tweet_body" | grep "@$user_screen_name" > /dev/null
    then
      log "$separator"
      log "TWEET DETECTED: Mentioned or Replied"
      [ "$mention_handler" = '' ] && continue
      echo "$line" |
        (cd "$work_dir"; eval "$mention_handler")
    fi

    if echo "$tweet_body" | grep "$keywords_matcher" > /dev/null
    then
      log "$separator"
      log "TWEET DETECTED: Matched to the given keywords"
      if [ "$search_handler" != '' ]
      then
        echo "$line" |
          (cd "$work_dir"; eval "$search_handler")
        continue
      fi
    fi
  done
}


favorite() {
  ensure_available

  local target="$1"
  local id="$(echo "$target" | extract_tweet_id)"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/favorites/create.json
id $id
FIN
  )"
  echo "$result"
  check_errors "$result"
}

unfavorite() {
  ensure_available

  local target="$1"
  local id="$(echo "$target" | extract_tweet_id)"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/favorites/destroy.json
id $id
FIN
  )"
  echo "$result"
  check_errors "$result"
}

retweet() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  local result="$(call_api POST "https://api.twitter.com/1.1/statuses/retweet/$id.json")"
  echo "$result"
  check_errors "$result"
}

unretweet() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  local retweet_id="$(show_with_my_retweet "$id" | jq -r .current_user_retweet.id_str)"
  delete "$retweet_id"
}

show_with_my_retweet() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  cat << FIN | call_api GET https://api.twitter.com/1.1/statuses/show.json
id $id
include_my_retweet true
FIN
}

show() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  cat << FIN | call_api GET https://api.twitter.com/1.1/statuses/show.json
id $id
FIN
}

follow() {
  ensure_available

  local target="$1"
  local screen_name="$(echo "$target" | sed 's/^@//')"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/friendships/create.json
screen_name $screen_name
follow true
FIN
  )"
  echo "$result"
  check_errors "$result"
}

unfollow() {
  ensure_available

  local target="$1"
  local screen_name="$(echo "$target" | sed 's/^@//')"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/friendships/destroy.json
screen_name $screen_name
FIN
  )"
  echo "$result"
  check_errors "$result"
}

body() {
  local target="$1"
  if [ "$target" != '' ]
  then
    local id="$(echo "$target" | extract_tweet_id)"
    show "$id" | body
  else
    local input="$(cat)"
    local body_text="$(echo "$input" | jq -r .text | unicode_unescape)"
    # for DMs
    if [ "$body_text" = 'null' ]
    then
      body_text="$(echo "$input" | jq -r .direct_message.text | unicode_unescape)"
    fi
    echo "$body_text"
  fi
}

owner_screen_name() {
  local target="$1"
  if [ "$target" != '' ]
  then
    local id="$(echo "$target" | extract_tweet_id)"
    show | echo "@$(extract_owner)"
  else
    echo "@$(extract_owner)"
  fi
}



#================================================================
# utilities to operate text

url_encode() {
  # process per line, because nkf -MQ automatically splits
  # the output string to 72 characters per a line.
  while read -r line
  do
    echo "$line" |
      # convert to MIME quoted printable
      #  W8 => input encoding is UTF-8
      #  MQ => quoted printable
      nkf -W8MQ |
      sed 's/=$//' |
      tr '=' '%' |
      # reunify broken linkes to a line
      paste -s -d ''
  done |
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
  local transformed="$( \
    # sort params by their name
    sort -k 1 -t ' ' |
    # remove blank lines
    grep -v '^\s*$' |
    # "name a b c" => "name%20a%20b%20c"
    url_encode |
    # "name%20a%20b%20c" => "name=a%20b%20c"
    sed 's/%20/=/' |
    # connect lines with the delimiter
    paste -s -d "$delimiter" |
    # remove last line break
    tr -d '\n')"
  echo "$transformed"
  log "to_encoded_list: $transformed"
}

extract_tweet_id() {
  $esed -e 's;https://[^/]+/[^/]+/status/;;' \
        -e 's;^([0-9]+)[^0-9].*$;\1;'
}

extract_owner() {
  local input="$(cat)"
  local owner="$(echo "$input" | jq -r .user.screen_name)"
  # for DMs
  if [ "$owner" = 'null' ]
  then
    owner="$(echo "$input" | jq -r .direct_message.sender.screen_name)"
  fi
  echo "$owner"
}

unicode_unescape() {
  sed 's/\\u\(....\)/\&#x\1;/g' |
    nkf --numchar-input
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
    cat - > "$params_file"
  fi

  local oauth="$(cat "$params_file" | generate_oauth_header "$method" "$url")"
  local headers="Authorization: OAuth $oauth"
  local params="$(cat "$params_file" | to_encoded_list)"

  log "METHOD : $method"
  log "URL    : $url"
  log "HEADERS: $headers"
  log "PARAMS : $params"

  local debug_params=''
  if [ "$DEBUG" != '' ]
  then
    # this is a bad way I know, but I don't know how to output only headers to the stderr...
    debug_params='--dump-header /dev/stderr  --verbose'
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

  local common_params_file="$(prepare_tempfile common_params)"
  common_params > "$common_params_file"

  local all_params_file="$(prepare_tempfile all_params)"
  cat "$common_params_file" - > "$all_params_file"

  # generate OAuth header
  local signature=$(cat "$all_params_file" | generate_signature "$method" "$url")
  local header=$(echo "oauth_signature $signature" |
    cat "$common_params_file" - |
    #縦一列を今度は横一列にして 項目=値,項目=値,...の形式に
    to_encoded_list ',' |
    tr -d '\n')

  echo -n "$header"
  log "HEADER: $header"

  rm -f "$common_params_file" "$all_params_file"
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

  local signature_key="${method}&${encoded_url}&"
  local signature_source="${signature_key}$( \
    to_encoded_list |
    url_encode |
    #改行が一個入ってしまうので取る
    tr -d '\n')"
  log "SIGNATURE SOURCE: $signature_source"

  # generate signature
  local signature=$(echo -n "$signature_source" |
    #エンコード
    openssl sha1 -hmac $CONSUMER_SECRET'&'$ACCESS_TOKEN_SECRET -binary |
    openssl base64 |
    tr -d '\n')

  echo -n "$signature"
  log "SIGNATURE: $signature"
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

if [ "$(basename "$0")" = "tweet.sh" ]
then
  command="$1"
  shift

  trap 'jobs="$(jobs -p)"; [ "$jobs" = "" ] || kill $jobs' QUIT KILL TERM

  case "$command" in
    post )
      post "$@"
      ;;
    reply )
      reply "$@"
      ;;
    del|delete )
      delete "$@"
      ;;
    dm|direct_message )
      direct_message "$@"
      ;;
    search )
      search "$@"
      ;;
    watch|watch-mentions )
      watch_mentions "$@"
      ;;
    fav|favorite )
      favorite "$@"
      ;;
    unfav|unfavorite )
      unfavorite "$@"
      ;;
    rt|retweet )
      retweet "$@"
      ;;
    unrt|unretweet )
      unretweet "$@"
      ;;
    follow )
      follow "$@"
      ;;
    unfollow )
      unfollow "$@"
      ;;
    body )
      body "$@"
      ;;
    owner )
      owner_screen_name "$@"
      ;;
    whoami )
      self_screen_name
      ;;
    help|* )
      help "$@"
      ;;
  esac
fi