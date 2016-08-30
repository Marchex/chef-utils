
This repository exists to provide a place for documentation and utilities required to maintain our on-premises chef infrastructure.

[Wiki Documentation of on-premises Chef infrastructure](http://wiki.marchex.com/index.php/On-Premises_Chef_Server)


Assumptions made in this document:
* You have access to the SSH keys required to access the on-premises chef servers
* You have sudo access on the on-premises chef servers
* You have the AWS CLI installed and configured, and the propers AWS permissions to interact with chef AWS entities (instances, ELBs, etc.)

# Creating a QA stack (or replacement/additional production stack) from running servers

## Creating AMIs from running instances

1. For each server, e.g. `qa-chefserver1.aws-us-west-2-vpc4.marchex.com`, find its instance ID, and create a new AMI from it:

**This will _REBOOT_ the target instance as part of the AMI creation**
```
HOST=qa-chefserver1.aws-us-west-2-vpc4.marchex.com
INSTANCE_ID=`aws ec2 describe-instances --region us-west-2 --query 'Reservations[*].Instances[*].InstanceId' --output text --filters "Name=tag:Name,Values=$HOST"`
# Create and tag
AMI_ID=`aws ec2 create-image --region us-west-2 --output text --instance-id $INSTANCE_ID --name "chef-server-qa-`date +%F`" --description "Image created from $HOST"`
aws ec2 create-tags --region us-west-2 --resources $AMI_ID --tags Key=Name,Value='chef-server-qa' Key=creator,Value="$ENV['USER']" Key=project,Value='Chef' Key=team,Value='Tools'
```

2. Repeat for all of the chef server types (currently: chef server, delivery, and supermarket, replacing HOST with their hostname)

## Launching instances from new AMIs

1. SSH to `vmbuilder1.sea1`
2. Update the `~/autobot-manifests/manifests/chef/hosts.yml` file and update the `image:` value with the correct AMI for each server type.
3. Optionally, destroy existing instances:
    * **This will _TERMINATE_ running instances, if they exist**
    * `autobot -s chef -x chef,pulley -p destroy`
4. Create the new servers with the new AMIs: `autobot -s chef -x chef,pulley`

## Adjusting configuration on the new chef servers

Unless you are bringing up hosts with the same hostname (and using the same ELBs), you will need to make configuration changes on the instances created from those AMIs in order to get them to work.

For example, if you're creating `qa-{chef,delivery,supermarket}.marchex.com` from AMIs generated from servers configured to live on `{chef,delivery,supermarket}.marchex.com`, you'll want to find all configuration files that might need to be changed.

1. Find configuration files that may need to be changed:
```
# Find all files in /etc/opscode* directories that reference the FQDNs we care about
FQDNS='chef.marchex.com delivery.marchex.com supermarket.marchex.com'
for fqdn in $FQDNS; do
  echo "Looking for $fqdn in chef config files..."
  find $(find /etc/ -maxdepth 1 -type d -name "opscode*") -type f -not -name "*-running.json" -print0 |xargs -0 -I{} grep $fqdn {} /dev/null
done
```
2. Modify these configs and reconfigure services on appropriate servers:
    * chef server
        ```
        sudo chef-server-ctl reconfigure
        
        sudo chef-manage-ctl reconfigure
        
        sudo opscode-reporting-ctl reconfigure
        
        sudo opscode-push-jobs-server-ctl reconfigure
        ```
    * delivery server
        ```
        sudo delivery-ctl reconfigure
        ```
    * supermarket server
        ```
        sudo supermarket-ctl reconfigure
        ```

## Placing new instances in service

1. Open the AWS console to the [EC2 > Load Balancers](https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#LoadBalancers:) page
2. Select the appropriate ELB that you want to use
3. Click the 'Instances' tab, and select the 'Edit Instances' button
4. Add the approprate instance to the ELB
