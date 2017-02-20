#!/bin/bash
dk_user=$1
ssh_pub_key_file=$2

echo "REQUIREMENTS:"
echo "  * Admin created user's account in Delivery, with LDAP auth and role 'admin'"
echo ""
echo "OPTIONAL:"
echo "  * User's public SSH key file saved locally"
echo ""

usage="Usage: $0 [marchex user name] [ssh pub key file]"

if [[ -z "$dk_user" ]]; then
    echo $usage
    exit 1
fi

set -e
if [[ -z "$ssh_pub_key_file" ]]; then
    read -p 'Continue without user SSH public key? [yN] ' yn
    case $yn in
      [Yy]* ) ssh_pub_key='';;
          * ) echo $usage; exit;;
    esac
else
    ssh_pub_key=$(cat $ssh_pub_key_file)
fi

set -e
echo "# Verifying Delivery API is working"
delivery token --verify

set +e
echo "# Looking for $dk_user in Chef"
ssh chefserver1.aws-us-west-2-vpc2.marchex.com sudo chef-server-ctl user-show "$dk_user" >/dev/null
if [[ -z "$?" ]]; then
    echo "User found"
else
    set -e
    ssh chefserver1.aws-us-west-2-vpc2.marchex.com sudo chef-server-ctl user-create "$dk_user" User Name "$dk_user@marchex.com" nopass >"$dk_user.pem"
    echo "User created: '$dk_user.pem' written (send this file to $dk_user@marchex.com !)"
fi


set -e
echo "# Adding $dk_user to 'marchex' org in Chef"
ssh chefserver1.aws-us-west-2-vpc2.marchex.com sudo chef-server-ctl org-user-add marchex "$dk_user"

set -e
echo "# Looking for $dk_user in Delivery"
# ideally we could create the user from the CLI, but automate/delivery doesn't
# allow us to create an LDAP user from CLI, apparently.

# we can use the delivery api to do this.  this is not a public API, so we
# shouldn't do it. but ... whatever.  if it breaks we can fix.  that is why
# we are leaving the ssh method commented out, in case we need it again.

##set +e
##found_user=$(ssh chefdelivery1.aws-us-west-2-vpc2.marchex.com sudo automate-ctl list-users marchex | grep -c "$dk_user")
## if [[ "$found_user" == "1" ]]; then
##     echo "User found"

found_user=$(delivery api get "users/$dk_user" | jq -c 'del(._links)')
if [[ ! -z "$found_user" && $( echo $found_user | jq -r .name ) == "$dk_user" ]]; then
    echo "User found"
else
    echo "User $dk_user not found in Delivery"
    exit 1
fi

set -e
if [[ ! -z "$ssh_pub_key" ]]; then
    echo "# Adding SSH key for $dk_user to Delivery"
    new_user=$( echo $found_user | jq -r ".ssh_pub_key=\"$ssh_pub_key\"" )
    delivery api put users/$dk_user -d "$new_user"
fi

echo "Complete!"
