#!/usr/bin/perl
#
# Copyright 2021 Dolthub, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use warnings;
use strict;

use open ":std", ":encoding(UTF-8)";

use JSON::Parse 'json_file_to_perl';
use Data::Dumper;

use Getopt::Long;

# Usage: ./gen_release_notes.pl <version> to generate release notes
# for an existing release
#
# ./gen_release_notes.pl to generate release notes for a new release
# (everything since the last release)
# 
# Example: ./gen_release_notes.pl v0.22.9

# GitHub API rate limits unauthed access to 60 requests an
# hour. Running this to generate release notes for a single release
# shouldn't normally hit this limit. If it does, you'll need to use a
# personal access token with the --token flag. Details for how to
# create a token:
# https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token

my $token = "";
my @dependencies;
GetOptions (
    "dependencies|d=s" => \@dependencies,
    "token|t=s" => \$token,
) or die "Error in command line args";

my $repo = shift @ARGV;
# no arg for changes since last release
my $release_tag = shift @ARGV;

die "Must provide github repo" unless $repo;

print STDERR "Looking for changes for release $release_tag\n" if $release_tag;

my $tmp_dir = "/var/tmp";
my $curl_file = "$tmp_dir/curl-$$.out";

my $releases_url = "https://api.github.com/repos/$repo/releases?per_page=100";
my $curl_releases = curl_cmd($releases_url, $token);

print STDERR "$curl_releases\n";
system($curl_releases) and die $!;

my $releases_json = json_file_to_perl($curl_file);

my ($from_time, $from_tag, $from_hash, $to_time, $to_tag, $to_hash);
foreach my $release (@$releases_json) {
    $from_time = $release->{created_at};
    $from_tag = $release->{tag_name};
    last if $to_time;

    if ((! $release_tag) || ($release_tag eq $release->{tag_name})) {
        $to_time = $release->{created_at};
        $to_tag = $release->{tag_name};
        last unless $release_tag;
    }
}

die "Couldn't find release" unless $to_time;

checkout_repo($repo);

$from_hash = tag_to_commit_hash($from_tag);
$to_hash = tag_to_commit_hash($to_tag);

# If we don't have a release tag to generate notes for, there is no
# upper bound for pulls and issues, only a lower bound.
$to_time = "" unless $release_tag;

print STDERR "Looking for PRs and issues from $from_time to $to_time\n";

my $pull_requests_url = "https://api.github.com/repos/$repo/pulls";
my $merged_prs = get_prs($pull_requests_url, $from_time, $to_time);

my $issues_url = "https://api.github.com/repos/$repo/issues";
my $closed_issues = get_issues($issues_url, $from_time, $to_time);

foreach my $dep (@dependencies) {
    my $from_dep_hash = get_dependency_version($dep, $from_hash);
    my $to_dep_hash = get_dependency_version($dep, $to_hash);

    if ($from_dep_hash eq $to_dep_hash) {
        print STDERR "Skipping $dep, version $from_dep_hash has not changed\n";
        next;
    }
    
    print STDERR "Looking for commit times in $dep from $from_dep_hash to $to_dep_hash\n";
    my $from_dep_time = get_commit_time($dep, $from_dep_hash);
    my $to_dep_time = get_commit_time($dep, $to_dep_hash);

    print STDERR "Looking for pulls in $dep from $from_dep_time to $to_dep_time\n";
    my $dep_pulls_urls = "https://api.github.com/repos/$dep/pulls";
    my $merged_dep_prs = get_prs($dep_pulls_urls, $from_dep_time, $to_dep_time);
    my $dep_issues_url = "https://api.github.com/repos/$dep/issues";
    my $closed_dep_issues = get_issues($dep_issues_url, $from_dep_time, $to_dep_time);

    push @$merged_prs, @$merged_dep_prs;
    push @$closed_issues, @$closed_dep_issues;
}

print "# Merged PRs\n\n";
foreach my $pr (@$merged_prs) {
    print "* [$pr->{number}]($pr->{url}): $pr->{title}\n";

    if ($pr->{body}) {
        my @lines = split (/\s*[\n\r]+\s*/, $pr->{body});
        foreach my $line (@lines) {
            print "  $line\n";
        }
    }
}

print "\n# Closed Issues\n\n";
foreach my $pr (@$closed_issues) {
    print "* [$pr->{number}]($pr->{url}): $pr->{title}\n";
}

exit 0;

# Gets a curl command to access the github api with the URL with token given (optional).
sub curl_cmd {
    my $url = shift;
    my $token = shift;

    my $base_cmd = "curl -H 'Accept: application/vnd.github.v3+json'";
    $base_cmd .= " -H 'Authorization: token $token'" if $token;
    $base_cmd .= " '$url' > $curl_file";

    return $base_cmd;
}

# Returns a list of closed PRs in the time range given, using the 
sub get_prs {
    my $base_url = shift;
    my $from_time = shift;
    my $to_time = shift;

    $base_url .= '?state=closed&sort=created&direction=desc&per_page=100';
    
    my $page = 1;
    my $more = 0;
    
    my @merged_prs;
    do {
        my $pulls_url = "$base_url&page=$page";
        my $curl_pulls = curl_cmd($pulls_url, $token);
        print STDERR "$curl_pulls\n";
        system($curl_pulls) and die $!;

        $more = 0;
        my $pulls_json = json_file_to_perl($curl_file);
        die "JSON file does not contain a list response" unless ref($pulls_json) eq 'ARRAY';
        
        foreach my $pull (@$pulls_json) {
            $more = 1;
            next unless $pull->{merged_at};

            print STDERR "PR merged at $pull->{merged_at}\n";
            return \@merged_prs if $pull->{created_at} lt $from_time;
            my %pr = (
                'url' => $pull->{html_url},
                'number' => $pull->{number},
                'title' => $pull->{title},
                'body' => $pull->{body},
                );

            push (@merged_prs, \%pr) if !$to_time || $pull->{merged_at} le $to_time;
        }

        $page++;
    } while $more;
    
    return \@merged_prs;
}

# Returns the SHA version of the dependency named at the repository SHA given.
sub get_dependency_version {
    my $dependency = shift;
    my $hash = shift;

    my $cmd = "git show $hash:go/go.mod | grep $dependency";
    print STDERR "$cmd\n";
    my $line = `$cmd`;

    # TODO: this only works for commit versions, not actual releases like most software uses
    # github.com/dolthub/go-mysql-server v0.6.1-0.20210107193823-566f0ba75abc
    if ($line =~ m/\S+\s+.*-([0-9a-f]{12})/) {
        return $1;
    }

    die "Couldn't determine dependency version in $line";
}

# Returns a list of closed issues in the time frame given from the github API url given
sub get_issues {
    my $base_url = shift;
    my $from_time = shift;
    my $to_time = shift;

    $base_url .= "?state=closed&sort=created&direction=desc&since=$from_time&per_page=100";
    
    my $page = 1;
    my $more = 0;

    my @closed_issues;
    do {
        my $issues_url = "$base_url&page=$page";
        my $curl_issues = curl_cmd($issues_url, $token);
        print STDERR "$curl_issues\n";
        system($curl_issues) and die $!;

        my $issues_json = json_file_to_perl($curl_file);
        die "JSON file does not contain a list response" unless ref($issues_json) eq 'ARRAY';

        $more = 0;
        foreach my $issue (@$issues_json) {
            $more = 1;
            next unless $issue->{closed_at};
            return \@closed_issues if $issue->{created_at} lt $from_time;
            next if $issue->{html_url} =~ m|/pull/|; # the issues API also returns PR results
            my %i = (
                'url' => $issue->{html_url},
                'number' => $issue->{number},
                'title' => $issue->{title},
                'body' => $issue->{body},
                );
            
            push (@closed_issues, \%i) if !$to_time || $issue->{closed_at} le $to_time; 
        }

        $page++;
    } while $more;
    
    return \@closed_issues;
}

# Returns the commit time for the commit from the repo given with the sha given
sub get_commit_time {
    my $repo = shift;
    my $sha = shift;

    my $commit_curl = curl_cmd("https://api.github.com/repos/$repo/commits?sha=$sha&per_page=1", $token);
    print STDERR "$commit_curl\n";
    system($commit_curl) and die $!;
    
    my $commit_json = json_file_to_perl($curl_file);
    die "JSON file does not contain a list response" unless ref($commit_json) eq 'ARRAY';

    foreach my $commit (@$commit_json) {
        # [
        #  {
        #      "sha": "9a89aaf765d7868c8252d24462e371f575175658",
        #      "commit": {
        #          "author": {
        #              "name": "Daylon Wilkins",
        #              "email": "daylon@liquidata.co",
        #              "date": "2020-12-21T14:33:08Z"
        #          },
        return $commit->{commit}{author}{date};
    }

    die "Couldn't find commit time";
}

# translates the tag given to a commit hash for the current git repo
sub tag_to_commit_hash {
    my $tag = shift;

    my $cmd = "git rev-list -n 1 $tag";
    print STDERR "$cmd\n";
    my $line = `$cmd` or die $!;
    
    if ($line =~ m/([0-9a-f]+)/) {
        return $1;
    }

    die "Couldn't determine dependency commit hash for tag $tag";
}

# Clones the repo given if necessary and changes the working directory to it.
sub checkout_repo {
    my $repo = shift;

    die "couldn't determine dir name" unless $repo =~ m|.+/(.+)|;

    my $dir = $1;
    if (!-e $dir) {
        my $cmd = "git clone git\@github.com:$repo.git";
        print STDERR "$cmd\n";
        system($cmd) and die $!;
    }

    chdir $dir;
}
