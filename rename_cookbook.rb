#!/usr/bin/env ruby
require 'mixlib/shellout'
require 'mkmf'

## NOTE: this script is probably not used anymore, and has not been tested
## since we abandoned Delivery/Workflow.  beware.


def shell_command(command, cwd=nil)
  require 'mixlib/shellout'
  puts "Running command: #{command}"
  cmd = Mixlib::ShellOut.new(command, :cwd => cwd)
  cmd.run_command
  cmd.error! # Display stdout if exit code was non-zero
  return cmd.stdout
end

def usage(msg='')
  puts "ERROR: #{msg}"
  puts "\nUsage: (arguments in [] are optional and have marchex-specific defaults)"
  puts "#{$0} <cookbook to rename> <new name> [github org]\t"
  puts "Example: #{$0} my-stupid-cookbook my_awesome_cookbook"
  abort
end
github_branch_name    = "topic_TOOL-858_rename"
github_commit_message = "TOOL-858 Rename existing on-premises cookbooks to adhere to naming standards."

# Could this work at all?
cookbook_name     = ARGV[0]   || usage("no cookbook name provided for renaming.")
new_cookbook_name = ARGV[1]   || usage("no cookbook name provided.")
github_org        = ARGV[2]   || "marchex-chef" #abort("no github org provided.")
Dir.exist?(cookbook_name)     || usage("#{cookbook_name} directory not found")
ENV['GITHUB_TOKEN']           || usage("GITHUB_TOKEN environment variable not set")
ENV['GITHUB_HOST']            || usage("GITHUB_HOST environment variable not set")
new_cookbook_name.match(/-/)  && abort("Cookbook names must not contain hyphens.")

%w( git github_api jq perl ).each { |cmd|
  find_executable(cmd) || usage("#{cmd} not found in your PATH: #{ENV['PATH']}")
}

shell_command("git checkout master", cookbook_name)
shell_command("git branch --set-upstream-to=origin/master master", cookbook_name)
shell_command("git pull --rebase", cookbook_name)
shell_command("github_api -m PATCH /repos/#{github_org}/#{cookbook_name} -d name=#{new_cookbook_name}")
shell_command("git checkout -b #{github_branch_name}", cookbook_name)
shell_command("find #{cookbook_name} -type f -print0 | xargs -0 sed -i 's/#{cookbook_name}/#{new_cookbook_name}/g'")
# Bump patch version e.g. "version '0.1.1'" --> "version '0.1.2'"
shell_command("perl -i -pe 's/version.*\\d+\\.\\d+\\.\\K(\\d+)/ $1+1 /e' metadata.rb", cookbook_name)
shell_command("git commit -a -m '#{github_commit_message}'", cookbook_name)
shell_command("git push origin #{github_branch_name}", cookbook_name)
sleep(1)
shell_command("mv #{cookbook_name} #{new_cookbook_name}")
shell_command("github_api -m POST /repos/#{github_org}/#{new_cookbook_name}/pulls -d title='#{github_commit_message}' -d head=#{github_branch_name} -d base=master")
github_search_string = "github_search -f '-repo:#{github_org}/#{cookbook_name} -repo:#{github_org}/#{new_cookbook_name} org:#{github_org} in:file #{cookbook_name}'"
search_results = shell_command(github_search_string)
search_results_url = shell_command(github_search_string << ' --print_url')
unless (search_results.nil? || search_results == '') then
  puts "\n#### WARNING WARNING WARNING WARNING WARNING ####\n"
  puts "The following references to the old cookbook name were found in other repos:\n"
  puts "#{search_results}\n"
  puts "These MUST be updated from #{cookbook_name} to #{new_cookbook_name} or things WILL break."
  puts "\nURL to view these results: #{search_results_url}\n"
  puts "#### WARNING WARNING WARNING WARNING WARNING ####"
else
  puts "Rename completed and no references to the old name found in the #{github_org} github repositories."
end
