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

  export MY_SCREEN_NAME
  export MY_LANGUAGE
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

  if [ "$MY_SCREEN_NAME" = '' ]
  then
    echo 'FATAL ERROR: You need to specify your screen name via an environment variable "MY_SCREEN_NAME".' 1>&2
    fatal_error=1
  fi

  if [ "$MY_LANGUAGE" = '' ]
  then
    echo 'FATAL ERROR: You need to specify your language (like "en") via an environment variable "MY_LANGUAGE".' 1>&2
    fatal_error=1
  fi

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
      echo '  fetch          : fetches a JSON string of a tweet.'
      echo '  search         : searches tweets.'
      echo '  watch-mentions(watch)'
      echo '                 : watches mentions, retweets, DMs, etc.'
      echo '  type           : detects the type of the given input.'
      echo '  body           : extracts the body of a tweet.'
      echo '  owner          : extracts the owner of a tweet.'
      echo '  showme         : reports the raw information of yourself.'
      echo '  whoami         : reports the screen name of yourself.'
      echo '  language(lang) : reports the selected language of yourself.'
      echo ''
      echo '  post           : posts a new tweet.'
      echo '  reply          : replies to a tweet.'
      echo '  upload         : upload a media file.'
      echo '  delete(del)    : deletes a tweet.'
      echo '  favorite(fav)  : marks a tweet as a favorite.'
      echo '  unfavorite(unfav)'
      echo '                 : removes favorited flag of a tweet.'
      echo '  retweet(rt)    : retweets a tweet.'
      echo '  unretweet(unrt): deletes the retweet of a tweet.'
      echo '  follow         : follows a user.'
      echo '  unfollow       : unfollows a user.'
      echo ''
      echo '  fetch-direct-messages(fetch-dm)'
      echo '                 : fetches recent DMs.'
      echo '  direct-message(dm)'
      echo '                 : sends a DM.'
      echo ''
      echo 'For more details, see also: "./tweet.sh help [command]"'
      ;;

    fetch )
      echo 'Usage:'
      echo '  ./tweet.sh fetch 012345'
      echo '  ./tweet.sh fetch https://twitter.com/username/status/012345'
      ;;
    search )
      echo 'Usage:'
      echo '  ./tweet.sh search -q "queries" -c 10'
      echo '  ./tweet.sh search -q "Bash OR Shell Script" -s 0123456'
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
    type )
      echo 'Usage:'
      echo '  echo "$tweet_json" | ./tweet.sh type -k keyword1,keyword2'
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
    showme )
      echo 'Usage:'
      echo '  ./tweet.sh showme'
      ;;
    whoami )
      echo 'Usage:'
      echo '  ./tweet.sh whoami'
      ;;
    lang|language )
      echo 'Usage:'
      echo '  ./tweet.sh lang'
      echo '  ./tweet.sh language'
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
    upload )
      echo 'Usage:'
      echo '  ./tweet.sh upload /path/to/file.png'
      ;;
    del|delete )
      echo 'Usage:'
      echo '  ./tweet.sh del 012345'
      echo '  ./tweet.sh del https://twitter.com/username/status/012345'
      echo '  ./tweet.sh delete 012345'
      echo '  ./tweet.sh delete https://twitter.com/username/status/012345'
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

    fetch-dm|fetch-direct-messages )
      echo 'Usage:'
      echo '  ./tweet.sh fetch-dm -c 10'
      echo '  ./tweet.sh fetch-direct-messages -c 100 -s 0123456'
      ;;
    dm|direct-message )
      echo 'Usage:'
      echo '  ./tweet.sh dm frinedname Good morning.'
      echo '  ./tweet.sh direct-message frinedname "How are you?"'
      ;;
  esac
}

check_errors() {
  if echo "$1" | grep '^\[' > /dev/null
  then
    return 0
  fi
  if [ "$(echo "$1" | jq -r '.errors | length')" = '0' ]
  then
    return 0
  else
    return 1
  fi
}


fetch() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"
  local result="$(cat << FIN | call_api GET https://api.twitter.com/1.1/statuses/show.json
id $id
FIN
  )"
  echo "$result"
  check_errors "$result"
}

fetch_with_my_retweet() {
  ensure_available

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"
  local result="$(cat << FIN | call_api GET https://api.twitter.com/1.1/statuses/show.json
id $id
include_my_retweet true
FIN
  )"
  echo "$result"
  check_errors "$result"
}

search() {
  ensure_available
  local locale='en'
  local count=10
  local since_id=''
  local handler=''

  local OPTIND OPTARG OPT
  while getopts q:l:c:s:h: OPT
  do
    case $OPT in
      q )
        query="$OPTARG"
        ;;
      c )
        count="$OPTARG"
        ;;
      s )
        since_id="$(echo "$OPTARG" | extract_tweet_id)"
        [ "$since_id" != '' ] && since_id="since_id $since_id"
        ;;
      h )
        handler="$OPTARG"
        ;;
    esac
  done

  [ "$MY_LANGUAGE" = 'ja' ] && locale='ja'

  if [ "$handler" = '' ]
  then
    local result="$(cat << FIN | call_api GET https://api.twitter.com/1.1/search/tweets.json
q $query
lang $MY_LANGUAGE
locale $locale
result_type recent
count $count
$since_id
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

watch_mentions() {
  ensure_available

  local extra_keywords=''
  local OPTIND OPTARG OPT
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

  local keywords=''
  local mention_handler=''
  local retweet_handler=''
  local quoted_handler=''
  local followed_handler=''
  local dm_handler=''
  local search_handler=''

  local OPTIND OPTARG OPT
  while getopts k:m:r:q:f:d:s: OPT
  do
    case $OPT in
      k )
        keywords="$OPTARG"
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

  local type
  while read -r line
  do
    type="$(echo "$line" |
              detect_type -k "$keywords")"
    [ $? != 0 ] && continue;

    log "Detected: $type"

    case "$type" in
      event-follow )
        if [ "$followed_handler" != '' ]
        then
          echo "$line" |
            (cd "$work_dir"; eval "$followed_handler")
        fi
        continue
        ;;

      direct-message )
        if [ "$dm_handler" != '' ]
        then
          echo "$line" |
            jq -r -c .direct_message
            (cd "$work_dir"; eval "$dm_handler")
        fi
        continue
        ;;

      quotation )
        if [ "$quoted_handler" != '' ]
        then
          echo "$line" |
            (cd "$work_dir"; eval "$quoted_handler")
        fi
        continue
        ;;

      retweet )
        if [ "$retweet_handler" != '' ]
        then
          echo "$line" |
            (cd "$work_dir"; eval "$retweet_handler")
        fi
        continue
        ;;

      mention )
        if [ "$mention_handler" != '' ]
        then
          echo "$line" |
            (cd "$work_dir"; eval "$mention_handler")
        fi
        continue
        ;;

      search-result )
        if [ "$search_handler" != '' ]
        then
          echo "$line" |
            (cd "$work_dir"; eval "$search_handler")
        fi
        continue
        ;;
    esac
  done
}

detect_type() {
  local keywords_matcher=''

  local OPTIND OPTARG OPT
  while getopts k: OPT
  do
    case $OPT in
      k )
        keywords_matcher="$(echo "$OPTARG" | \
                              sed -e 's/,/|/g' \
                                  -e 's/ +/.*/g')"
        ;;
    esac
  done

  local input="$(cat)"

  if [ "$input" = 'Exceeded connection limit for user' ]
  then
    return 1
  fi

  # Events
  case "$(echo "$input" | jq -r .event)" in
    null )
      : # do nothing for tweets at here
      ;;
    follow )
      local screen_name="$(echo "$input" | \
                             jq -r .source.screen_name | \
                             tr -d '\n')"
      if [ "$screen_name" != "$MY_SCREEN_NAME" ]
      then
        echo "event-follow"
        return 0
      fi
      return 1
      ;;
    * ) # ignore other unknown events
      return 1
      ;;
  esac

  # DM
  local sender="$(echo "$input" | jq -r .sender_screen_name)"
  [ "$sender" = '' ] && sender="$(echo "$input" | jq -r .direct_message.sender_screen_name)"
  if [ "$sender" != '' \
       -a "$sender" != 'null' \
       -a "$sender" != "$MY_SCREEN_NAME" ]
  then
    echo "direct-message"
    return 0
  fi

  # Ignore self tweet or non-tweet object
  local owner="$(echo "$input" | extract_owner)"
  if [ "$owner" = "$MY_SCREEN_NAME" \
       -o "$owner" = 'null'  \
       -o "$owner" = '' ]
  then
    return 1
  fi

  # Detect quotation at first, because quotation can be
  # deteted as retweet or a simple mention unexpectedly.
  # NOTE: An RT of a QT can have both quoted_status and retweeted_status.
  #       We must ignore such case, because it is actually an RT not a QT.
  if [ "$(echo "$input" | \
            jq -r .quoted_status.user.screen_name | \
            tr -d '\n')" = "$MY_SCREEN_NAME" \
       -a \
       "$(echo "$input" | \
            jq -r .retweeted_status.user.screen_name | \
            tr -d '\n')" != "$MY_SCREEN_NAME" ]
  then
    echo "quotation"
    return 0
  fi

  local tweet_body="$(echo "$input" | body)"

  # Detect retweet before reqply, because "RT: @(screenname)"
  # can be deteted as a simple mention unexpectedly.
  if echo "$tweet_body" | grep "RT @$MY_SCREEN_NAME:" > /dev/null
  then
    echo "retweet"
    return 0
  fi
  if echo "$tweet_body" | egrep "^RT @[^:]+:" > /dev/null
  then
    # don't handle RT of RT
    return 1
  fi

  if echo "$tweet_body" | grep "@$MY_SCREEN_NAME" > /dev/null
  then
    echo "mention"
    return 0
  fi

  if echo "$tweet_body" | egrep -i "$keywords_matcher" > /dev/null
  then
    echo "search-result"
    return 0
  fi

  return 1
}

body() {
  local target="$1"
  if [ "$target" != '' ]
  then
    local id="$(echo "$target" | extract_tweet_id)"
    fetch "$id" | body
  else
    jq -r .text | unicode_unescape
  fi
}

owner_screen_name() {
  local target="$1"
  if [ "$target" != '' ]
  then
    local id="$(echo "$target" | extract_tweet_id)"
    echo "@$(fetch "$id" | extract_owner)"
  else
    echo "@$(extract_owner)"
  fi
}

# implementation of showme
my_information() {
  ensure_available
  call_api GET https://api.twitter.com/1.1/account/verify_credentials.json
}

# implementation of whoami
self_screen_name() {
  my_information |
    jq -r .screen_name |
    tr -d '\n'
}

# implementation of language
self_language() {
  local lang="$(my_information |
    jq -r .lang |
    tr -d '\n')"
  if [ "$lang" = 'null' -o "$lang" = '' ]
  then
    echo "en"
  else
    echo "$lang"
  fi
}


post() {
  ensure_available

  local media_params=''

  local OPTIND OPTARG OPT
  while getopts m: OPT
  do
    case $OPT in
      m )
        media_params="media_ids=$OPTARG"
        shift 2
        ;;
    esac
  done

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/statuses/update.json
status $*
$media_params
FIN
  )"

  echo "$result"
  check_errors "$result"
}

reply() {
  ensure_available

  local media_params=''

  local OPTIND OPTARG OPT
  while getopts m: OPT
  do
    case $OPT in
      m )
        media_params="media_ids=$OPTARG"
        shift 2
        ;;
    esac
  done

  local target="$1"
  shift

  local id="$(echo "$target" | extract_tweet_id)"

  local result="$(cat << FIN | call_api POST https://api.twitter.com/1.1/statuses/update.json
status $*
in_reply_to_status_id $id
$media_params
FIN
  )"
  echo "$result"
  check_errors "$result"
}

upload() {
  ensure_available

  local target="$1"

  local result="$(call_api POST https://upload.twitter.com/1.1/media/upload.json media="$target")"
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

  local retweet_id="$(fetch_with_my_retweet "$id" | jq -r .current_user_retweet.id_str)"
  delete "$retweet_id"
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


fetch_direct_messages() {
  ensure_available
  local count=10
  local since_id=''

  local OPTIND OPTARG OPT
  while getopts c:s: OPT
  do
    case $OPT in
      c )
        count="$OPTARG"
        ;;
      s )
        since_id="$(echo "$OPTARG" | extract_tweet_id)"
        [ "$since_id" != '' ] && since_id="since_id $since_id"
        ;;
    esac
  done

  local result="$(cat << FIN | call_api GET https://api.twitter.com/1.1/direct_messages.json
count $count
$since_id
FIN
  )"
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
  jq -r .user.screen_name
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
  local file=$3

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

  local file_params=''
  if [ "$file" != '' ]
  then
    local file_param_name="$(echo "$file" | $esed 's/=.+$//')"
    local file_path="$(echo "$file" | $esed 's/^[^=]+=//')"
    file_params="--form $file_param_name=@$file_path"
    log "FILE   : $file_path (as $file_param_name)"
  fi

  local debug_params=''
  if [ "$DEBUG" != '' ]
  then
    # this is a bad way I know, but I don't know how to output only headers to the stderr...
    debug_params='--dump-header /dev/stderr  --verbose'
  fi

  local curl_params
  if [ "$method" = 'POST' ]
  then
    local main_params=''
    if [ "$params" = '' ]
    then
      params='""'
    fi
    if [ "$file_params" = '' ]
    then
      main_params="--data \"$params\""
    else
      main_params="--form \"$params\""
    fi
    curl_params="--header \"$headers\" \
         --silent \
         $main_params \
         $file_params \
         $debug_params \
         $url"
  else
    curl_params="--get \
         --header \"$headers\" \
         --data \"$params\" \
         --silent \
         $debug_params \
         $url"
  fi
  curl_params="$(echo "$curl_params" | tr -d '\n' | $esed 's/  +/ /g')"
  log "curl $curl_params"
  # Command line string for logging couldn't be executed directly because
  # quotation marks in the command line will be passed to curl as is.
  # To avoid sending of needless quotation marks, the command line must be
  # executed via "eval".
  eval "curl $curl_params"

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

  local signature_key="${CONSUMER_SECRET}&${ACCESS_TOKEN_SECRET}"

  local encoded_url="$(echo "$url" | url_encode)"
  local signature_source="${method}&${encoded_url}&$( \
    to_encoded_list |
    url_encode |
    # Remove last extra line-break
    tr -d '\n')"
  log "SIGNATURE SOURCE: $signature_source"

  # generate signature
  local signature=$(echo -n "$signature_source" |
    #エンコード
    openssl sha1 -hmac $signature_key -binary |
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

# Orphan processes can be left after Ctrl-C or something,
# because there can be detached. We manually find them and kill all.
kill_descendants() {
  local target_pid=$1
  local children=$(ps --no-heading --ppid $target_pid -o pid)
  for child in $children
  do
    kill_descendants $child
  done
  if [ $target_pid != $$ ]
  then
    kill $target_pid 2>&1 > /dev/null
  fi
}

if [ "$(basename "$0")" = "tweet.sh" ]
then
  command="$1"
  shift

  self_pid=$$
  trap 'kill_descendants $self_pid; exit 0' HUP INT QUIT KILL TERM

  case "$command" in
    fetch )
      fetch "$@"
      ;;
    search )
      search "$@"
      ;;
    watch|watch-mentions )
      watch_mentions "$@"
      ;;
    type )
      detect_type "$@"
      ;;
    body )
      body "$@"
      ;;
    owner )
      owner_screen_name "$@"
      ;;
    showme )
      my_information
      ;;
    whoami )
      self_screen_name
      ;;
    lang|language )
      self_language
      ;;

    post )
      post "$@"
      ;;
    reply )
      reply "$@"
      ;;
    upload )
      upload "$@"
      ;;
    del|delete )
      delete "$@"
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

    fetch-dm|fetch-direct-messages )
      fetch_direct_messages "$@"
      ;;
    dm|direct-message )
      direct_message "$@"
      ;;

    help|* )
      help "$@"
      ;;
  esac
fi
