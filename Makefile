# ############################################################################
# CUBIC Interpolation DSP ASIC - TSMC 28 nm
#
# Main project stages:
#
#   RTL simulation
#       ->
#   Design Compiler synthesis
#       ->
#   Gate-level simulation
#       ->
#   Conformal LEC
#       ->
#   Pad-level gate simulation
#       ->
#   Innovus place and route
#       ->
#   Post-route ECO / physical verification
#       ->
#   PrimeTime STA
#
# "make flow" runs the main flow through routed physical design.
#
# The final post-route ECO scripts are preserved under innovus/scripts/.
# The final Iter4B PrimeTime handoff is generated with:
#
#   make backend_prep_final
#
# Final 6-run PrimeTime STA:
#
#   make pt
#
# L selects the interpolation factor (2..5).
# L=5 is the primary golden-reference verification case.
# ############################################################################

SUBMIT = $(if $(JOB_ID),,qrsh -V -cwd -b y -q all.q)
ROOT   = $(CURDIR)
CORES  = cubic

# interpolation factor for the front-end sims (2,3,4,5).  golden exists for L=5.
L      ?= 5
# for 'make pnr_stage':  STAGE = stage script (fp, place, ...), PREV = saved state
STAGE  ?= route
PREV   ?= -

# The three front-end sims compile via their own run_*.tcsh (like run_syn.tcsh) so
# the qrsh dispatch never mangles quoting.  Each script runs, verbatim:
#     vcs -f <cud> -sverilog -kdb -full64 +vcs+fsdbon        (Euclide-identical)
# and bakes L in (default L=5).  The compare below is done here on the login node.
GOLDEN  = out/output_golden.txt

# diff the single *_POST_LPF_L_<L>.txt produced in $(1) against the golden (one line).
define cmp
@sh -c 'g="$(GOLDEN)"; d="$(1)"; if [ "$(L)" != "5" ]; then echo "[compare] SKIPPED: golden is L=5 only - output kept in $$d"; exit 0; fi; if [ ! -f "$$g" ]; then echo "[compare] ERROR: golden $$g missing"; exit 1; fi; o=`ls $$d/*_POST_LPF_L_$(L).txt 2>/dev/null | head -1`; if [ -z "$$o" ]; then echo "[compare] FAIL: no *_POST_LPF_L_$(L).txt produced in $$d"; exit 1; fi; if diff -q "$$o" "$$g" >/dev/null 2>&1; then echo "[compare] PASS: $$o == golden"; else echo "[compare] FAIL: $$o differs from golden"; diff "$$o" "$$g" | head; exit 1; fi'
endef

# ==========================================================================
#  WHOLE FLOW, IN ORDER (front-end verification then back-end physical)
# ==========================================================================
flow: sim syn gls lec gls_pads pnr
	@echo "==== CUBIC main flow complete: RTL -> synthesis -> GLS -> LEC -> pad GLS -> P&R ===="
	@echo "==== Final ECO scripts are under innovus/scripts; then run make backend_prep_final && make pt ===="

# ==========================================================================
#  1   R T L   S I M   +   golden compare        [final_pilot flow_rtl, simplified]
# ==========================================================================
sim:
	@test -f build.cud            || { echo "ERROR: build.cud missing"; exit 1; }
	@test -f RTL/tb_asic.sv       || { echo "ERROR: RTL/tb_asic.sv missing - front-end not populated"; exit 1; }
	@test -f in/input_hex_60M_L_$(L).txt || { echo "ERROR: in/input_hex_60M_L_$(L).txt missing (L=$(L))"; exit 1; }
	@test -f RTL/run_sim.tcsh || { echo "ERROR: RTL/run_sim.tcsh missing"; exit 1; }
	$(SUBMIT) tcsh RTL/run_sim.tcsh $(L)
	$(call cmp,out)

# ==========================================================================
#  2   S Y N T H E S I S     DC Ultra -> netlist + one sdc (write_sdc)
# ==========================================================================
syn:
	$(SUBMIT) tcsh synthesis/run_syn.tcsh

# ==========================================================================
#  3   G A T E   S I M  (netlist)  +  golden compare        [final_pilot flow_syn]
# ==========================================================================
gls:
	@test -f build_gls.cud                          || { echo "ERROR: build_gls.cud missing"; exit 1; }
	@test -f synthesis/dataout/ASIC_Top_netlist.v   || { echo "ERROR: netlist missing - run 'make syn' first"; exit 1; }
	@test -f GLS/tb_asic.sv                         || { echo "ERROR: GLS/tb_asic.sv missing"; exit 1; }
	@test -f GLS/run_gls.tcsh                       || { echo "ERROR: GLS/run_gls.tcsh missing"; exit 1; }
	$(SUBMIT) tcsh GLS/run_gls.tcsh $(L)
	$(call cmp,GLS/work)

# ------  Conformal RTL == netlist  (logic equivalence)      [final_pilot flow 3]
lec:
	@test -f lec_rvg/scripts/hier.do    || { echo "ERROR: lec_rvg/scripts/hier.do missing"; exit 1; }
	@test -f lec_rvg/work/compile.vsdc  || { echo "ERROR: lec_rvg/work/compile.vsdc missing (from synthesis)"; exit 1; }
	$(SUBMIT) tcsh lec_rvg/run_lec.tcsh

# ==========================================================================
#  4   P A D D E D - C H I P   G A T E   S I M   + golden   [final_pilot flow_gentop]
# ==========================================================================
gls_pads:
	@test -f gentop/build_top.cud || { echo "ERROR: gentop/build_top.cud missing"; exit 1; }
	@test -f gentop/top.v         || { echo "ERROR: gentop/top.v (padded netlist) missing"; exit 1; }
	@test -f gentop/pad.v         || { echo "ERROR: gentop/pad.v (pad shells) missing"; exit 1; }
	@test -f gentop/run_pads.tcsh || { echo "ERROR: gentop/run_pads.tcsh missing"; exit 1; }
	$(SUBMIT) tcsh gentop/run_pads.tcsh $(L)
	$(call cmp,gentop/work)

# rebuild the padded top from the core netlist (scratch - never clobbers gentop/top.v)
gentop:
	mkdir -p innovus/datain/gentop_out
	cd innovus/datain/gentop_out && perl ../gentop.pl ../../../synthesis/dataout/ASIC_Top_netlist.v ASIC_Top
	@echo "gentop: raw top.v/top.io in innovus/datain/gentop_out/ - apply _G pad wrappers (gen_pads.pl) before P&R."

# ==========================================================================
#  5   P L A C E   &   R O U T E     Innovus -> routed GDS
# ==========================================================================
pnr:
	$(SUBMIT) tcsh innovus/run_innovus.tcsh

# one P&R stage on top of a saved state:  make pnr_stage STAGE=fp PREV=init
pnr_stage:
	$(SUBMIT) tcsh innovus/run_stage.tcsh $(STAGE) $(PREV)

# export the PrimeTime/LVS netlists + SPEF + GDS from the routed design
backend_prep:
	cd innovus/work && /tools/common/wrappers/innovus -no_gui -files ../scripts/backend_prep.tcl -log ../logfile/backend_prep

# Final PrimeTime handoff from the closed Iter4B physical implementation
backend_prep_final:
	cd innovus/work && /tools/common/wrappers/innovus -no_gui -files ../scripts/backend_prep_hold_eco_iter4b.tcl -log ../logfile/backend_prep_final

# Voltus power from the per-L switching activity (needs the routed design)
power:
	$(SUBMIT) sh -c 'cd innovus/work && innovus -no_gui -files ../scripts/power_saif.tcl -log ../logfile/power'

# the per-L SAIF (measured activity) power_saif.tcl consumes.  Already staged in
# innovus/datain/saif/ from a post-layout gate sim (see innovus/build_pnr.cud);
# this target just verifies the one for the requested L is present.
saif:
	@if [ -f innovus/datain/saif/core_L$(L).saif ]; then \
	  echo "SAIF present: innovus/datain/saif/core_L$(L).saif  (consumed by 'make power')"; \
	else \
	  echo "ERROR: innovus/datain/saif/core_L$(L).saif missing - regenerate a post-layout"; \
	  echo "       gate sim (innovus/build_pnr.cud) with SAIF dump into innovus/datain/saif/"; exit 1; fi

# ==========================================================================
#  6   P R I M E T I M E     signoff STA (setup AND hold, all three corners)
# ==========================================================================
pt:
	tcsh primetime/run_pt_final_iter4b.tcsh

#  H O U S E K E E P I N G   +   H E L P
# ==========================================================================
clean:
	-rm -rf out/csrc_rtl out/simv_rtl out/simv_rtl.daidir out/*.log out/rtl_output_*.txt out/*_POST_LPF_*.txt
	-rm -rf out/novas* out/verdiLog out/*.fsdb out/*.key out/*.vpd out/ucli.key out/input_hex_60M_L_*.txt out/.vdb out/*.vdb
	-rm -rf GLS/work/* gentop/work/*
	-rm -rf synthesis/work/* innovus/work/* primetime/work/*
	-rm -f  synthesis/logfile/* innovus/logfile/* primetime/logfile/*
	@echo "==== cleaned front-end + back-end work/ (sources, .cud, in/, golden, datain/dataout kept) ===="

clean_all: clean
	-rm -rf lec_rvg/work/LEC.cfm lec_rvg/logfile/lec*.log lec_rvg/work/hier_compare.do
	@echo "==== clean_all done (lec_rvg/work/compile.vsdc kept) ===="

help: flow_help
flow_help:
	@echo ""
	@echo "  ==== CUBIC Interpolation DSP ASIC - TSMC 28 nm ===="
	@echo ""
	@echo "   Main flow:"
	@echo "     1  make sim        RTL simulation + golden comparison"
	@echo "     2  make syn        Design Compiler synthesis"
	@echo "     3  make gls        gate-level simulation"
	@echo "        make lec        Conformal RTL-to-netlist equivalence"
	@echo "     4  make gls_pads   pad-level gate simulation"
	@echo "     5  make pnr        Innovus place and route"
	@echo ""
	@echo "   Final implementation:"
	@echo "        post-route ECO scripts: innovus/scripts/"
	@echo "        make backend_prep_final  export final Iter4B PT netlist + SPEF"
	@echo "     6  make pt          final setup/hold x slow/typ/fast PrimeTime matrix"
	@echo ""
	@echo "   Optional analysis:"
	@echo "        make power       activity-based power analysis"
	@echo "        make saif        check SAIF availability"
	@echo ""
	@echo "   make flow             run main flow through P&R"
	@echo "   make clean            clean generated work directories"
	@echo "   make clean_all        clean work + Conformal temporary database"
	@echo ""
	@echo "   L=$(L)                interpolation factor, supported 2..5"
	@echo ""

.PHONY: flow sim syn gls lec gls_pads gentop pnr pnr_stage backend_prep backend_prep_final power saif pt clean clean_all help flow_help
