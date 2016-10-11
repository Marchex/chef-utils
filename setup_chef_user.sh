#!/bin/bash
dk_user=$1

if [[ -z "$dk_user" ]]; then
    echo "Usage: $0 [marchex user name]"
    exit 1
fi

echo "REQUREMENTS:"
echo "  * User previously logged in to Chef"
echo "  * Admin created user's account in Delivery, with LDAP auth and role 'admin'"
echo ""

set -e
echo "# Looking for $dk_user in Chef"
ssh chefserver1.aws-us-west-2-vpc2.marchex.com sudo chef-server-ctl user-show "$dk_user" >/dev/null
echo "User found"

set -e
echo "# Adding $dk_user to 'marchex' org in Chef"
ssh chefserver1.aws-us-west-2-vpc2.marchex.com sudo chef-server-ctl org-user-add marchex "$dk_user"

set +e
echo "# Looking for $dk_user in Delivery"
found=$(ssh chefdelivery1.aws-us-west-2-vpc2.marchex.com delivery-ctl list-users marchex | grep -c "$dk_user")
if [[ "$found" == "1" ]]; then
    echo "User found"
else
    echo "User $dk_user not found in Delivery"
    exit 1
fi

set -e
echo "# Linking $dk_user in Delivery to $dk_user in GitHub"
ssh chefdelivery1.aws-us-west-2-vpc2.marchex.com sudo delivery-ctl link-github-enterprise-user marchex "$dk_user" "$dk_user"
