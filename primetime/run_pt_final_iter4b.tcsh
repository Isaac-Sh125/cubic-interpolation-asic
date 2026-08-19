#!/bin/tcsh

setenv LANG C
setenv LC_ALL C
setenv TMPDIR /tmp

source /tools/modules/5.5.0/init/tcsh
module load PT

cd `dirname $0`

mkdir -p report/final_iter4b_no_flat
mkdir -p logfile/final_iter4b_no_flat

rm -f report/final_iter4b_no_flat/SUMMARY.txt

foreach mode ( setup hold )

    foreach corner ( slow typ fast )

        setenv PT_MODE   $mode
        setenv PT_CORNER $corner

        echo ""
        echo "============================================================"
        echo "FINAL PT: $mode / $corner"
        echo "============================================================"

        /tools/common/wrappers/pt_shell \
            -f scripts/pt_run_final_iter4b_no_flat.tcl \
            |& tee logfile/final_iter4b_no_flat/pt_${mode}_${corner}.log

    end
end

echo ""
echo "============================================================"
echo "FINAL PT MATRIX COMPLETE"
echo "============================================================"

cat report/final_iter4b_no_flat/SUMMARY.txt
