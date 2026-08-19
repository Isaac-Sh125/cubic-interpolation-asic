#!/bin/tcsh
# P&R: full flow init->fp->power->place->cts->route->write_data
setenv LANG C ; setenv LC_ALL C
cd `dirname $0`/work
/tools/common/wrappers/innovus -no_gui -files ../scripts/full.tcl -log ../logfile/innovus |& tee ../logfile/run.log
