#/bin/bash

echo 'C_primitives equ \' > primitives.inc.orig
sed -e 's/.*/\t&,\\/' primitives >> primitives.inc.orig
echo '' >> primitives.inc.orig

sed -e 's/.*/C_primitive &\n\nend C_primitive\n\n\n/' primitives > primitives.fasm.orig


