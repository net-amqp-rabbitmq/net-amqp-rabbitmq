#!/bin/bash

#make sure a cpan build will work
perl Makefile.PL
make manifest
make distdir
cd $(perl -MCPAN::Meta -e '$m = CPAN::Meta->load_file("MYMETA.yml"); print $m->name . "-" . $m->version')

perl Makefile.PL
cover -make "make TEST_VERBOSE=1" -test test
MQSSL=1 prove -MDevel::Cover -v -I blib/lib -I blib/arch t/

cover -report coveralls -ignore_re "\.c|\.h"

#run linux specific memory leak tests
if [ "$is_osx" = false ]; then
    perl -I blib/lib -I blib/arch xt/100_transaction_memory_leak.t
    perl -I blib/lib -I blib/arch xt/101_headers_memory_leak.t
fi
