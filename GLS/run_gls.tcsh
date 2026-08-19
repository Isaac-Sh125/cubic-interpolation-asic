#!/bin/tcsh
# Gate-level sim of the synthesised netlist - real module-loaded vcs (headless/Euclide).
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load VCS VERDI
set L = "$1"
if ("$L" == "") set L = 5
cd `dirname $0`/..
mkdir -p GLS/work
set PV = ""
if ("$L" != "5") set PV = "-pvalue+tb_asic.L_VALUE=$L -pvalue+tb_asic.FILENAME=input_hex_60M_L_$L.txt -pvalue+tb_asic.OUT_FILE=gls_output_POST_LPF_L_$L.txt"
echo "== gate sim (netlist) : L=$L  (real vcs = $VCS_HOME) =="
$VCS_HOME/bin/vcs -f build_gls.cud $PV -sverilog -kdb -full64 +vcs+fsdbon -timescale=1ns/1ps -Mdir=GLS/work/csrc -o GLS/work/simv_gls -l GLS/work/comp_gls.log
if ($status != 0) then
    echo "GLS: VCS COMPILE FAILED - see GLS/work/comp_gls.log"
    exit 1
endif
cd GLS/work
ln -sf ../../in/input_hex_60M_L_$L.txt input_hex_60M_L_$L.txt
./simv_gls -l run_gls.log
echo "== gate sim done - output in GLS/work/ =="
