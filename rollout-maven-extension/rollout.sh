#!/bin/bash

commit_msg="Apply latest Develocity configuration"
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
repositories=$basedir/repositories.txt
checkout_area=

yellow='\033[1;33m'
nc='\033[0m'

# process arguments
while getopts "ufp" opt; do
    case $opt in
    u) do_update=true ;;
    f) force=true ;;
    p) push=true ;;
    \?) ;;
    esac
done

function prepare() {
  checkout_area=$( mktemp -d )
}

function process_repositories() {
  numOfRepos=$( sed "/^[[:blank:]]*#/d;s/^[[:blank:]]*//;s/#.*//" "$repositories" | wc -l )
  current=1
  while IFS= read -r repo
  do
    echo -e "${yellow}($current/$numOfRepos) Processing ${repo}...${nc}"
    process_repository "$repo"
    ((current++))
  done < <(sed "/^[[:blank:]]*#/d;s/^[[:blank:]]*//;s/#.*//" "$repositories")
}

function process_repository() {
  repository_name="${1##*/}"

  # clone the Git epository without actually downloading files or history
  git clone -n "$1" "$checkout_area/$repository_name" --depth 1 >& /dev/null
  pushd "$checkout_area/$repository_name" >& /dev/null || return
  git reset HEAD . >& /dev/null

  # ensure it is a Maven project
  if ! git ls-tree -r HEAD --name-only | grep -q 'pom.xml'
  then
    # no pom.xml found in the project  
    echo "$repository_name repository is not a Maven project, skipping..." >&2
    return
  fi

  # ensure .mvn folder exists
  if ! git ls-tree -r HEAD --name-only | grep -q '^.mvn/'
  then
    # .mvn folder not found 
    if [ "$do_update" ]; then
      # script invoked with -u (update) flag, thus .mvn folder expected to already exist
      echo "$repository_name repository does not contain existing .mvn directory, skipping..." >&2
      return
    else
      # script invoked without -u (update) flag, thus .mvn folder will be created
      mkdir .mvn
    fi
  fi

  # Check out .mvn folder and recursively copy Develocity configuration into it
  git checkout .mvn >& /dev/null
  if [ "$force" ]; then 
    # override existing files
    cp -a "$basedir"/.mvn/. .mvn
  else
    # do not override existing files
    cp -na "$basedir"/.mvn/. .mvn
  fi

  # update .gitignore file to ignore the .mvn/.develocity folder
  if git checkout -- .gitignore >& /dev/null
  then
    # .gitignore file already exists
    if ! grep -Fxq ".mvn/.develocity/" .gitignore ; then
      echo ".mvn/.develocity/" >> .gitignore
    fi
  else
    # .gitignore file does not already exist
    echo ".mvn/.develocity/" > .gitignore
  fi

  # add changes to staging and commit
  git add .mvn/. 
  git add .gitignore
  git commit -m "$commit_msg"

  # push change if script was invoked with -p (push) flag
  if [ "$push" ]; then
     git push >& /dev/null
     echo "Changes pushed to $repository_name repository"
  else
     echo "Changes to $repository_name repository available at $PWD"
  fi

  popd >& /dev/null || return
}

function cleanup() {
  if [ "$push" ]; then
    rm -rf "$checkout_area"
  else
    echo "All cloned repositories available at $checkout_area"
  fi
}

# entry point
if [ ! -d ".mvn" ]; then
  echo ".mvn directory is missing" >&2
  exit 1
elif [ ! -f "repositories.txt" ]; then
  echo "repositories.txt file is missing" >&2
  exit 1
else
  prepare
  process_repositories
  cleanup
  exit 0
fi
