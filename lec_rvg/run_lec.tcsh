#!/bin/tcsh
# LEC: Cadence Conformal RTL-vs-Gate equivalence - real module-loaded lec (headless/Euclide).
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load CONFRML
cd `dirname $0`/work
/tools/cadence/CONFRML/25.20.100/bin/lec -xl -nogui -dofile ../scripts/hier.do |& tee ../logfile/lec.log
