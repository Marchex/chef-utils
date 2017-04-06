#!/bin/bash
dk_user=$1

chef_server=chefserver1.aws-us-west-2-vpc2.marchex.com

usage="Usage: $0 [Marchex user name]"

if [[ -z "$dk_user" ]]; then
    echo $usage
    exit 1
fi

set +e
echo "# Looking for $dk_user in Chef"
ssh "$chef_server" sudo chef-server-ctl user-show "$dk_user" >/dev/null
if [[ "$?" == 0 ]]; then
    echo "User found"
else
    set -e
    ssh "$chef_server" sudo chef-server-ctl user-create "$dk_user" User Name "$dk_user@marchex.com" nopass >"$dk_user.pem"
    echo "User created: '$dk_user.pem' written (send this file to $dk_user@marchex.com !)"
fi

set -e
echo "# Adding $dk_user to 'marchex' and 'outhouse' orgs in Chef"
ssh "$chef_server" sudo chef-server-ctl org-user-add marchex "$dk_user" --admin
ssh "$chef_server" sudo chef-server-ctl org-user-add outhouse "$dk_user" --admin

set -e
echo "# Adding $dk_user to vaults in Chef"
knife vault update escrow certificates -A "$dk_user" -s https://chef.marchex.com/organizations/marchex
knife vault update escrow certificates -A "$dk_user" -s https://chef.marchex.com/organizations/outhouse

echo "Complete!"
