#!/usr/local/bin/perl
use warnings;
use strict;
use feature ':5.10';

# from https://github.com/chef/knife-acl/blob/master/README.md

# make sure your knife.rb is configured correctly before running
# set up the permissions here, and when you run the script, it
# will configure all the permissions for all existing data and
# containers

my %containers = (
    clients             => { crud => 1 },
    containers          => { no_bulk => 1 },
    cookbook_artifacts  => { no_bulk => 1 },
    cookbooks           => {},
    data                => { crud => 1 },
    environments        => {},
    groups              => { no_bulk => 1 },
    nodes               => { crud => 1 },
    roles               => {},
    sandboxes           => { no_bulk => 1 },
    policies            => {},
    policy_groups       => {},
);

for my $container (sort keys %containers) {
    # for everything: no one gets grant, everyone gets read
    # by default: no create/update/delete
    # some objects do allow CRU (crud => 1)
    # for some objects (sandboxes) we do no bulk updating, not necessary (no_bulk => 1)

    my $rm_perms  = $containers{$container}{crud} ? 'grant' : 'create,update,delete,grant';
    my $add_perms = $containers{$container}{crud} ? 'create,read,update,delete' : 'read';

    system('knife', 'acl',         'remove', 'group', 'users', 'containers', $container,       $rm_perms);
    system('knife', 'acl', 'bulk', 'remove', 'group', 'users',               $container, '.*', $rm_perms, '--yes')
        unless $containers{$container}{no_bulk};

    system('knife', 'acl',         'add',    'group', 'users', 'containers', $container,       $add_perms);
    system('knife', 'acl', 'bulk', 'add',    'group', 'users',               $container, '.*', $add_perms, '--yes')
        unless $containers{$container}{no_bulk};
}

sub _system {
    my(@args) = @_;

    my $args = join ' ', @args;
    my $ret = system(@args);
    die "system '$args' failed: $ret : $?" if $ret != 0;
    if ($? == -1) {
        die "failed to execute: $!";
    }
    elsif ($? & 127) {
        die sprintf "child died with signal %d, %s coredump",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
}

__END__
