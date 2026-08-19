#!/bin/tcsh
setenv LANG C ; setenv LC_ALL C ; setenv TMPDIR /tmp
source /tools/modules/5.5.0/init/tcsh
module load VCS VERDI
rehash
set FS = /project/verif/users/yitzhak2/ws/ex_vlsi_1/final_script
cd $FS
set G = $FS/GL_sim_saif
mkdir -p $G/saif
echo "== build gate SAIF sim (fixed cfg_word) =="
$VCS_HOME/bin/vcs -f GL_sim_saif/build_saif.cud -sverilog -full64 -kdb \
   -cc /usr/bin/gcc -cpp /usr/bin/g++ -LDFLAGS "-L/usr/lib64" \
   -timescale=1ns/1ps -o $G/simv_saif -top design_tb -Mdir=$G/csrc -l $G/comp_saif.log
if ($status != 0) then
  echo "BUILD FAILED"; tail -8 $G/comp_saif.log; exit 1
endif
cd $G
foreach L (2 3 4 5)
  ln -sf ../in/input_hex_60M_L_$L.txt input_hex_60M_L_$L.txt
  echo "== run L=$L =="
  timeout 900 ./simv_saif +L=$L +SAIF +SAIFFILE=$G/saif/core_L$L.saif -l log_saif_L$L >& /dev/null
  set dur = `grep -m1 -oE 'DURATION [0-9.]+' saif/core_L$L.saif |awk '{print $2}'`
  grep -hE 'PROBE|DONE L=|out_nonzero' log_saif_L$L | tail -1
  echo "   L=$L DURATION=$dur saif_bytes=`stat -c%s saif/core_L$L.saif`"
end
echo "== distinct SAIF bodies (strip header) =="
for L in 2 3 4 5; do sed '1,15d' saif/core_L$L.saif | md5sum | awk -v l=$L '{print "L"l" bodymd5="$1}'; done
echo "SAIFGEN_DONE"
