#!/bin/bash
outhouse_user=$1
inhouse_user=$2

if [[ -z "$outhouse_user" || -z "$inhouse_user" ]]; then
    echo "Usage: $0 [Out-house Chef user name] [In-house Chef user name]"
    exit 1
fi

# the way we want to do this is use knife_hosted to get the key, and
# knife_prem to set it.  unfortunately, before Chef 12.4.1 we don't have
# privileges to do that for normal admins.  so instead, we have a workaround
# to use chef-server-ctl on the in-house chef.  it is not as nice to do it
# that way, mostly because it's more commands, munges JSON files, and has race
# conditions with temp files.


echo 'REQUREMENTS:'
echo '  * User has accounts on both out-house, and in-house, Chef server'
echo '  * User wants to used key from out-house Chef, for in-house Chef'
echo '  * `knife_hosted` command is configured to use out-house Chef'
#echo '  * `knife_prem` command is configured to use in-house Chef'
echo ''

if [[ -z "$(type -t jq 2>/dev/null)" ]]; then
    echo "jq not installed, exiting"
    exit
fi

function check_knife {
    local knife_cmd=$1
    if [[ -z "$(type $knife_cmd 2>/dev/null)" ]]; then
        echo "$knife_cmd not installed, exiting; try running something like this:"
        echo "  function $knife_cmd { knife \"\$@\" --config ~/.chef/$knife_cmd.rb }"
        echo "  export -f $knife_cmd"
        exit
    fi
}

check_knife 'knife_hosted'
# check_knife 'knife_prem'


set -e

## "good" way to do it
# mytemp=$(tempfile)
# echo "# Getting $outhouse_user's key from out-house Chef server"
# knife_hosted user key show $outhouse_user default -F json | jq -r '.public_key' > $mytemp
# echo "# Setting $inhouse_user's key on in-house Chef server"
# knife_prem user key edit $inhouse_user default -p $mytemp -d


## use this workaround until permissions problem solved to enable the above code to work
echo "# Getting $outhouse_user's key from out-house Chef server"
mytempkey=$(knife_hosted user key show $outhouse_user default -F json | jq -r '.public_key')
echo "# Getting $inhouse_user's config from in-house Chef server"
ssh chef.marchex.com "sudo chef-server-ctl user-show $inhouse_user -F json" | jq ".public_key = \"$mytempkey\"" > $inhouse_user.json
echo "# Copying $inhouse_user's config to in-house Chef server"
scp $inhouse_user.json chef.marchex.com:
echo "# Setting $inhouse_user's key on in-house Chef server"
ssh chef.marchex.com "sudo chef-server-ctl user-edit $inhouse_user -i $inhouse_user.json"
echo "# Cleaning up files"
ssh chef.marchex.com "rm $inhouse_user.json"
rm $inhouse_user.json
