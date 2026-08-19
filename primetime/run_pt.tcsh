#!/bin/tcsh
# PrimeTime signoff STA - setup+hold x slow/typ/fast. Runs from primetime/ so
# pt_run.tcl's relative report/ and work/ resolve.
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load PT
cd `dirname $0`
mkdir -p report work
foreach mode (setup hold)
  foreach corner (slow typ fast)
    setenv PT_MODE   $mode
    setenv PT_CORNER $corner
    echo "==== PT $mode / $corner ===="
    /tools/synopsys/prime/X-2025.06-SP2-1/bin/pt_shell -f scripts/pt_run.tcl |& tee logfile/pt_${mode}_${corner}.log
  end
end
