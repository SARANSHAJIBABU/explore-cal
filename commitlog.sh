#!/bin/sh

changeFile="mychangelog.md"
nl="
"

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

getCommitHash() {
  type=$1
  if [ "$type" = "first" ] ; then
      git log --oneline | tail -1 | cut -d " " -f 1
  else
      git rev-parse HEAD
  fi
}

generateChangeLog() {
  [ ! -d .git ] && { echo "Not  a valid git repo."; return 1;}

  latestTag=$(getTags | head -1)
  echo $latestTag
}

filterMajorCommits() {
    args="-e" # "-v" to return not major commit
    [ "$1" ] && args="${1}e"

    grep "$args" "^[A-z]*!: " \
        -e "^[A-z]*(.*)!: " \
        -e "^[*-] *[A-z]*!: " \
        -e "^[*-] *[A-z]*(.*)!: " \
        -e "^BREAKING[ -]CHANGE: " \
        -e "^[*-] *BREAKING[ -]CHANGE: " \
        -e "^BREAKING[ -]CHANGE"
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

fmt_conv_type() {
    sed -e "s|^[A-z]*: \(.*$\)|\1|g" \
        -e "s|^[A-z]*(\(.*\)): \(.*$\)|\2 for \1|g" \
        -e "s|^[*-] *[A-z]*: \(.*$\)|\1|g" \
        -e "s|^[*-] *[A-z]*(\(.*\)): \(.*$\)|\2 for \1|g" \
        -e "s|^[A-z]*!: \(.*$\)|\1|g" \
        -e "s|^[A-z]*(\(.*\))!: \(.*$\)|\2 for \1|g" \
        -e "s|^[*-] *[A-z]*!: \(.*$\)|\1|g" \
        -e "s|^[*-] *[A-z]*(\(.*\))!: \(.*$\)|\2 for \1|g" \
        -e "s|^BREAKING[ -]CHANGE: \(.*$\)|\1|g" \
        -e "s|^[*-] *BREAKING[ -]CHANGE: \(.*$\)|\1|g" \
        -e "s|^BREAKING[ -]CHANGE|a breaking change|g"
}

generateFormattedLogs() {
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


#Get current hash
commitHashCurrent=$(getCommitHash "cur")

#Get latest first hash in the branch
commitHashFirst=$(getCommitHash "first")

#Generate all commit hashes
commits=$(generateLog "$commitHashCurrent" "$commitHashFirst")

echo "$commits" > commits.txt

formattedLogs=$(generateFormattedLogs "$commits" | fmt_conv_type)

toprint="# Changelog

## [$(getCurrentVersion)]

$(formatCommits "$formattedLogs")
**********"

if [ ! -e $changeFile ]; then
  echo "no changelog => create and append"
  echo "$toprint"  > "$changeFile"
elif grep -q "$(getCurrentVersion)" "$changeFile"  ; then
    echo "changelog exist. current version exist => overwrite"
    regex="/^.*Changelog/,/^\*/d"
    sed -i.backup -e "$regex" "$changeFile" && rm "${changeFile}.backup"
    echo "$toprint" | cat - "$changeFile" > temp && mv temp "$changeFile"
else
    echo "changelog exist. new version => append"
    regex="/^.*Changelog/d"
    sed -i.backup -e "$regex" "$changeFile" && rm "${changeFile}.backup"
    echo "$toprint" | cat - "$changeFile" > temp && mv temp "$changeFile"
fi
