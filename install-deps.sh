#!/bin/sh

perl -MCPAN -e 'CPAN::Shell->rematein("notest", "install", "DateTime::Format::ISO8601")'
perl -MCPAN -e 'CPAN::Shell->rematein("notest", "install", "Getopt::Long")'
perl -MCPAN -e 'CPAN::Shell->rematein("notest", "install", "JSON::Parse")'
perl -MCPAN -e 'CPAN::Shell->rematein("notest", "install", "Sort::Naturally")'
