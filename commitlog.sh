#!/bin/bash

changeFile="mychangelog.md"
nl="
"
message="fix: Fix broken button\n"

getCurrentBranchName(){
  git branch --show-current
}

# Platform dependent
getCurrentVersion() {
  grep "artifact.version=" gradle.properties | cut -d = -f 2
}

generateLog() {
  firstCommit=$1
  currentCommit=$2
  commitRange="$currentCommit..$firstCommit"
  git log --pretty=format:"%s" "$commitRange"
}

getFirstOrRecentCommitHash() {
  type=$1
  if [ "$type" = "first" ] ; then
      git log --oneline | tail -1 | cut -d " " -f 1
  else
      git rev-parse HEAD
  fi
}
#test
generateChangeLog() {
  [ ! -d .git ] && { echo "Not  a valid git repo."; return 1;}

  latestTag=$(getTags | head -1)
  echo "$latestTag"
}

filterMajorCommits() {
    args="-e" # "-v" to return not major commit
    [ "$1" ] && args="${1}e"

    grep -i "$args" "^major: " \
        -e "^major(.*): " \
        -e "^[*-] *major: "\
        -e "^[*-] *major(.*): "
}

filterMinorCommits() {
    args="-e" # "-v" to return not minor commit
    [ "$1" ] && args="${1}e"

    grep -i "$args" "^feat: " \
        -e "^feat(.*): " \
        -e "^[*-] *feat: " \
        -e "^[*-] *feat(.*): "
}

filterPatchCommits() {
    args="-e" # "-v" to return not patch commit
    [ "$1" ] && args="${1}e"

    grep -i "$args" "^fix: " \
        -e "^fix(.*): " \
        -e "^[*-] *fix: "\
        -e "^[*-] *fix(.*): "
}

formatCommitTypes() {
    sed -e "s|^[A-z]*: \(.*$\)|\1|g" \
        -e "s|^[A-z]*(\(.*\)): \(.*$\)|\2 for \1|g" \
        -e "s|^[*-] *[A-z]*: \(.*$\)|\1|g" \
        -e "s|^[*-] *[A-z]*(\(.*\)): \(.*$\)|\2 for \1|g" \
        -e "s|^[A-z]*!: \(.*$\)|\1|g" \
        -e "s|^[A-z]*(\(.*\))!: \(.*$\)|\2 for \1|g" \
        -e "s|^[*-] *[A-z]*!: \(.*$\)|\1|g" \
        -e "s|^[*-] *[A-z]*(\(.*\))!: \(.*$\)|\2 for \1|g"
}

arrangeCommitLogs() {
  commits=$1

  #Filter major
  major=$(echo "$commits" | filterMajorCommits)

  commits=$(echo "$commits" | filterMajorCommits -v)

  #Filter minor
  minor=$(echo "$commits" | filterMinorCommits)

  commits=$(echo "$commits" | filterMinorCommits -v)

  #Filter patch
  patch=$(echo "$commits" | filterPatchCommits)

  commits=$(echo "$commits" | filterPatchCommits -v)

  #Output major/minor/patch/others to file
  [ "$major" ] && echo "### MAJOR CHANGE" && echo "$major"
  [ "$minor" ] && echo "### Added" && echo "$minor"
  [ "$patch" ] && echo "### Fixed" && echo "$patch"
  [ "$commits" ] && echo "### Changed" && echo "$commits"
}

formatCommits() {
  commits=$1
    IFS="$nl"
    for commit in $commits; do
      header=$(echo "$commit" | grep "^#")

      if [ -z "$header" ] ; then
        first_char=$(echo "$commit" | cut -c 1 | tr "[:lower:]" "[:upper:]")
        echo "$commit" | sed -e "s|^.\(.*$\)|- $first_char\1.|"
      else
        echo "$commit"
      fi

    done
}

replaceLogs(){
  logsToPrint=$1
  regex=$2
  sed -i.backup -e "$regex" "$changeFile" && rm "${changeFile}.backup"
  echo "$logsToPrint" | cat - "$changeFile" > temp && mv temp "$changeFile"
}

#Get current hash
commitHashCurrent=$(getFirstOrRecentCommitHash "cur")

#Get latest first hash in the branch
commitHashFirst=$(getFirstOrRecentCommitHash "first")

#Generate all commit hashes
commits=$(generateLog "$commitHashCurrent" "$commitHashFirst")

commits="$message$commits"

formattedLogs=$(arrangeCommitLogs "$commits" | formatCommitTypes)

logsToPrint="# Changelog

## [$(getCurrentVersion)]

$(formatCommits "$formattedLogs")
**********"

if [ ! -e $changeFile ]; then
  echo "no changelog => create and append"
  echo "$logsToPrint"  > "$changeFile"
elif grep -q "$(getCurrentVersion)" "$changeFile"  ; then
    echo "changelog exist. current version exist => overwrite"
    replaceLogs "$logsToPrint" "/^.*Changelog/,/^\*/d"
else
    echo "changelog exist. new version => append"
    replaceLogs "$logsToPrint" "/^.*Changelog/d"
fi
