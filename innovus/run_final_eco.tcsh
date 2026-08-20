#!/bin/tcsh

# ================================================================
# Final post-route ECO chain for the CUBIC ASIC.
#
# Input:
#   dataout/design_saves/final.dat
#
# Output:
#   dataout/design_saves/final_hold_eco_iter4b_trial.dat
# ================================================================

set ROOT=`dirname $0`
cd $ROOT/work

mkdir -p ../logfile

echo ""
echo "============================================================"
echo "FINAL ECO 1/4 - Data hold repair"
echo "============================================================"

/tools/common/wrappers/innovus \
    -no_gui \
    -files ../scripts/apply_hold_eco_29.tcl \
    |& tee ../logfile/final_eco_01_hold29.log

grep -q 'HOLD_ECO_29_PHYSICAL_PASS' \
    ../logfile/final_eco_01_hold29.log

if ( $status != 0 ) then
    echo "ERROR: ECO 1 failed"
    exit 1
endif


echo ""
echo "============================================================"
echo "FINAL ECO 2/4 - Remaining data hold repair"
echo "============================================================"

/tools/common/wrappers/innovus \
    -no_gui \
    -files ../scripts/apply_hold_eco_iter2.tcl \
    |& tee ../logfile/final_eco_02_hold_iter2.log

grep -q 'HOLD_ECO_ITER2_PHYSICAL_PASS' \
    ../logfile/final_eco_02_hold_iter2.log

if ( $status != 0 ) then
    echo "ERROR: ECO 2 failed"
    exit 1
endif


echo ""
echo "============================================================"
echo "FINAL ECO 3/4 - Clock-gating hold repair"
echo "============================================================"

/tools/common/wrappers/innovus \
    -no_gui \
    -files ../scripts/apply_clock_gating_eco_iter3.tcl \
    |& tee ../logfile/final_eco_03_clock_gating.log

grep -q 'CG_ECO_ITER3_PHYSICAL_PASS' \
    ../logfile/final_eco_03_clock_gating.log

if ( $status != 0 ) then
    echo "ERROR: ECO 3 failed"
    exit 1
endif


echo ""
echo "============================================================"
echo "FINAL ECO 4/4 - Scan-enable DRV repair"
echo "============================================================"

/tools/common/wrappers/innovus \
    -no_gui \
    -files ../scripts/apply_scan_en_fix_iter4b.tcl \
    |& tee ../logfile/final_eco_04_scan_en.log

grep -q 'SCAN_ECO_ITER4B_PHYSICAL_PASS' \
    ../logfile/final_eco_04_scan_en.log

if ( $status != 0 ) then
    echo "ERROR: ECO 4 failed"
    exit 1
endif


echo ""
echo "============================================================"
echo "FINAL ECO CHAIN PASS"
echo "Output: final_hold_eco_iter4b_trial"
echo "============================================================"

exit 0
