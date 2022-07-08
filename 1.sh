#!/usr/bin/env bash

set -v

export getSpec='rev=$(git rev-parse HEAD); \
fullref=$(git for-each-ref --contains $rev | sed -n "s/^.*refs\/\(heads\|remotes\/\)//p" | sort -k1.1,1.1 -rs | head -n1); \
remote=${fullref%/*}; remote=${remote:-origin};
ref=${fullref#*/}; \
url=$(git remote get-url $remote | sed "s/\(\.git\|\/\)$//"); \
alias=${url##*/}; con=${alias}_${rev::7}; '

submods() {
  git submodule --quiet foreach --recursive \
    "$getSpec"'printf %s\\n "$PWD $con"' \
    | sort -k2 -u
}
export -f submods

subdeps() {
  git submodule --quiet foreach "$getSpec"'printf %s "
        \"$alias\": \"$con\","'
}
export -f subdeps

spec() {
  (cd "$1"
    eval "$getSpec"
    deps=$(subdeps)
    name=$alias-${rev::7}
    printf %s "
    \"$con\": {
      \"name\": \"$alias\",
      \"deps\": {${deps%,}
      },
      \"repo\": {
        \"name\": \"$name\",
        \"url\": \"$url\",
        \"rev\": \"$rev\",
        \"ref\": \"${ref#refs/remotes/*/}\"
      }
    }"
  )
}
export -f spec

specs() {
  eval "$getSpec"

  local repos; repos="$1
$PWD $con"
  local root; root=$(realpath .)
  local deps;
  local sep; sep=""

  printf %s "{
  \"contracts\": {"

  echo >&2 "$repos"
  for path in $(cut -d " " -f1 <<<"$repos"); do

    if [[ $path != "$root" ]]; then
      printf %s "$sep"; sep=","
      if [[ -f "$path/.forge.json" ]]; then
        jq .contracts "$path/.forge.json" | sed '1d;$d'
      else
        spec "$path"
      fi
    fi
  done

  printf %s "
  },
  \"this\": {
$(spec "$path" | sed '1,2d;$d')
  }
}"
}
export -f specs

main() {
  local repos; repos=$(submods)

  [ -n "$repos" ] || { echo >&2 'Submodules not initiated? Run: `git submodule update --init --recursive`'; exit 1; }

  specs "$repos"
}
main 