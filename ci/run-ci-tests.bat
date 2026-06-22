rem *make sure a cpan build will work*
perl Makefile.PL
nmake manifest
nmake distdir

perl -MCPAN::Meta -e "$m = CPAN::Meta->load_file('MYMETA.yml'); print $m->name . '-' . $m->version" > pm.txt
set /p PM_NAME=<pm.txt
echo %PM_NAME%
cd %PM_NAME%

perl Makefile.PL

rem pending complete... github workflow may not be the best place to test...

rem cover -make "nmake TEST_VERBOSE=1" -test test
rem SET MQSSL=1 prove -MDevel::Cover -v -I blib/lib -I blib/arch t/

rem cover -report coveralls -ignore_re "\.c|\.h"

rem Skip this test, we need a rabbitmq server to be opened, and set MQHOST=localhost to run this test
rem run linux specific memory leak tests
rem if %is_osx% EQU "true" goto end
rem       perl -I blib/lib -I blib/arch xt/100_transaction_memory_leak.t
rem       perl -I blib/lib -I blib/arch xt/101_headers_memory_leak.t
rem :end

