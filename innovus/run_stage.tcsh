#!/bin/tcsh
# Run ONE P&R stage on top of a saved state.  usage: run_stage.tcsh <stage> <prev|->
setenv LANG C ; setenv LC_ALL C
cd `dirname $0`/work
set stage = $1 ; set prev = $2 ; set tmp = stage_run.tcl
echo "# auto stage runner" > $tmp
if ("$prev" != "-") echo "restoreDesign ../dataout/design_saves/$prev.dat top" >> $tmp
echo "source ../scripts/$stage.tcl" >> $tmp
echo "saveDesign ../dataout/design_saves/$stage.dat" >> $tmp
echo "exit" >> $tmp
/tools/common/wrappers/innovus -no_gui -files $tmp -log ../logfile/$stage |& tee ../logfile/${stage}_run.log
