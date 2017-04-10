#!/bin/bash
# you probably need to have the "delivery" chef creds to unshare/delete cookbook
# (in .chef/knife.rb) and admin privileges to delete the repo from GitHub
# set token in GITHUB_TOKEN, and GITHUB_HOST=github.marchex.com), as well
# as github-api-tools.  also, don't use this script, it's dangerous.

repo=$1

if [[ -z "$repo" ]]; then
    echo "Need a name of a repository"
    exit 1
fi

set +e
set -x

knife supermarket unshare ${repo} --supermarket-site https://supermarket.marchex.com -V -y
knife cookbook delete ${repo} -a -V -y
github_api -m DELETE repos/marchex-chef/${repo}
github_api -m DELETE repos/marchex-chef/tests_${repo}
