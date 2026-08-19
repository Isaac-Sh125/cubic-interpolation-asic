#!/bin/tcsh
# Synthesis: Design Compiler (real, module-loaded) -> netlist + ONE sdc.
# Runs headless / from Euclide (the wrapper dc_shell is interactive-only).
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load SYN
cd `dirname $0`/work
/tools/synopsys/syn/X-2025.06-SP4/bin/dc_shell -f ../scripts/synthesis.tcl |& tee ../logfile/syn.log
