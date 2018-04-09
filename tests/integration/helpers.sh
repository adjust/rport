assert_success () {
  if [ $? -eq 0 ]; then
    printf '.'
  else
    echo "ERROR $1 $2\n"
    exit 1
  fi
}

assert_match_count () {
  # we don't use `grep -c` because the workers could write on the same line
  cnt=$(grep -o -E "$1" $2 | wc -l)
  if [[ $cnt != "$3" ]]; then
    echo "ERROR: $2 matched '$1' $cnt times and not $3"
    exit 1
  fi
  printf '.'
}

query () {
  R --slave --vanilla -e "library(rport, quietly=TRUE); $1"
}
