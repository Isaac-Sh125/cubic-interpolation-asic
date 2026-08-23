#!/bin/tcsh

setenv LANG C
setenv LC_ALL C
setenv TMPDIR /tmp

source /tools/modules/5.5.0/init/tcsh
module load SYN

cd `dirname $0`/work

echo "===== STANDARD COMPILE + SCAN VERIFICATION SYNTHESIS ====="

/tools/synopsys/syn/X-2025.06-SP4/bin/dc_shell \
    -f ../scripts/synthesis_standard.tcl |& \
    tee ../logfile/syn_standard.log

set RC = $status

echo "STANDARD_SYNTHESIS_EXIT_STATUS=$RC"
exit $RC
