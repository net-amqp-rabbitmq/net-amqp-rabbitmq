#!/bin/bash

# Set up PERL5LIB
export PERL5LIB="../local/lib/perl5:$PERL5LIB"

#make sure a cpan build will work
perl Makefile.PL
make manifest
make distdir
cd $(perl -MCPAN::Meta -e '$m = CPAN::Meta->load_file("MYMETA.yml"); print $m->name . "-" . $m->version')

perl Makefile.PL
cover -make "make TEST_VERBOSE=1" -test test
MQSSL=1 prove -MDevel::Cover -v -I ../local -I blib/lib -I blib/arch t/

if [ "$COVERALLS_REPO_TOKEN" != "" ]; then
    cover -report coveralls -ignore_re "\.c|\.h"
fi

#run linux specific memory leak tests
if [ "$IS_OSX" = false ]; then
    perl -I blib/lib -I blib/arch xt/100_transaction_memory_leak.t
    perl -I blib/lib -I blib/arch xt/101_headers_memory_leak.t
fi
