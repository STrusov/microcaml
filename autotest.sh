#/bin/bash

testsuite="../ocaml/testsuite/tests"
tests="
    array-functions
    basic
    basic-float
    "

tmpdir=`mktemp -d --tmpdir microcamltest.XXX`

for testdir in ${tests}
do
    echo -e "\033[1m Каталог ${testdir}:\033[22m"
    sources=`ls -1 ${testsuite}/${testdir}/*ml`
    for filepath in ${sources}
    do
        filename=${filepath##*/}
        echo -ne "${filename} \t"
        cp ${filepath} ${tmpdir}
        cp ${filepath%.ml}.reference ${tmpdir}
        bytecode=${tmpdir}/${filename%.ml}
        ocamlc ${tmpdir}/${filename} -o ${bytecode}
        rm ${tmpdir}/*.cm*
        ./microcaml ${bytecode} > ${bytecode}.output
        diff -u ${bytecode}.output ${bytecode}.reference && echo '+' || exit
    done
done

rm --recursive --force $tmpdir
