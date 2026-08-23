#!/bin/tcsh
# Functional zero-delay gate simulation of the padded top-level design.
# The build uses the real TSMC 28 nm I/O Verilog model together with the
# synthesized core netlist. pad_sim_stubs.v supplies only the mechanical
# PCORNER_G cell, which has no functional signal behavior.
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load VCS VERDI
set L = "$1"
if ("$L" == "") set L = 5
cd `dirname $0`/..
mkdir -p gentop/work
set PV = ""
if ("$L" != "5") set PV = "-pvalue+tb_asic.L_VALUE=$L -pvalue+tb_asic.FILENAME=input_hex_60M_L_$L.txt -pvalue+tb_asic.OUT_FILE=gls_pads_POST_LPF_L_$L.txt"
echo "== padded gate sim : L=$L  (real vcs) =="
$VCS_HOME/bin/vcs -f gentop/build_top.cud $PV -sverilog -kdb -full64 +vcs+fsdbon +delay_mode_zero -timescale=1ns/1ps -Mdir=gentop/work/csrc -o gentop/work/simv_top -l gentop/work/comp_top.log
if ($status != 0) then
    echo "gls_pads: VCS COMPILE FAILED - see gentop/work/comp_top.log"
    exit 1
endif
cd gentop/work
ln -sf ../../in/input_hex_60M_L_$L.txt input_hex_60M_L_$L.txt
./simv_top -l run_top.log
echo "== padded gate sim done - output in gentop/work/ =="
