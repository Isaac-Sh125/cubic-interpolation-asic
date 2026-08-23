#!/bin/tcsh

setenv LANG C
setenv LC_ALL C
setenv TMPDIR /tmp

source /tools/modules/5.5.0/init/tcsh
module load CONFRML

cd `dirname $0`/work

echo "===== STANDARD COMPILE vs COMPILE_ULTRA LEC ====="
echo "===== compare effort = HIGH ====="

/tools/cadence/CONFRML/25.20.100/bin/lec \
    -xl \
    -nogui \
    -dofile ../scripts/hier_standard_vs_ultra.do |& \
    tee ../logfile/lec_console.log
