#!/bin/tcsh
# ============================================================================
# RTL functional simulation - QAM-64 Cubic interpolator (ASIC_Top).
# Runs the REAL module-loaded vcs on a compute node, so it works headless AND
# from Euclide (the /tools/common/wrappers/vcs is interactive-only, needs a TTY).
#     make sim [L=5]   ->   qrsh -b y ... tcsh RTL/run_sim.tcsh <L>
# Compile is what Euclide compiles:  vcs -f build.cud -sverilog -kdb -full64 +vcs+fsdbon
# Writes out/rtl_output_POST_LPF_L_<L>.txt ; the Makefile diffs it vs the golden.
# ============================================================================
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load VCS VERDI
set L = "$1"
if ("$L" == "") set L = 5
cd `dirname $0`/..
mkdir -p out
set PV = ""
if ("$L" != "5") set PV = "-pvalue+tb_asic.L_VALUE=$L -pvalue+tb_asic.FILENAME=input_hex_60M_L_$L.txt -pvalue+tb_asic.OUT_FILE=rtl_output_POST_LPF_L_$L.txt"
echo "== RTL sim : L=$L  (real vcs = $VCS_HOME) =="
$VCS_HOME/bin/vcs -f build.cud $PV -sverilog -kdb -full64 +vcs+fsdbon -Mdir=out/csrc_rtl -o out/simv_rtl -l out/comp_rtl.log
if ($status != 0) then
    echo "RTL sim: VCS COMPILE FAILED - see out/comp_rtl.log"
    exit 1
endif
cd out
ln -sf ../in/input_hex_60M_L_$L.txt input_hex_60M_L_$L.txt
./simv_rtl -l run_rtl.log
echo "== RTL sim done - output in out/ =="
