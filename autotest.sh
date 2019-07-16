#/bin/bash

testsuite="../ocaml/testsuite/tests"

tests="
    array-functions
    basic
    basic-float
    extension-constructor
    lib-queue
    lib-stack
    match-exception-warnings
    prim-bswap
    prim-revapply
    "

testlib="../ocaml/testsuite/lib"
testmodule="testing"

tmpdir=`mktemp -d --tmpdir microcamltest.XXX`

cp ${testlib}/${testmodule}.ml{,i} ${tmpdir} || exit
ocamlc -c ${tmpdir}/${testmodule}.mli
ocamlc ${tmpdir}/${testmodule}.ml -I ${tmpdir}

for testdir in ${tests}
do
    echo -e "\033[1m Каталог ${testdir}:\033[22m"
    sources=`ls -1 ${testsuite}/${testdir}/*ml`
    for filepath in ${sources}
    do
        filename=${filepath##*/}
        echo -ne "${filename} \t"
        cp ${filepath} ${tmpdir}
        bytecode=${tmpdir}/${filename%.ml}
        ocamlc ${tmpdir}/${testmodule}.cmo ${tmpdir}/${filename} -I ${tmpdir} -o ${bytecode} -w -3-8-11-12-26
        rm ${bytecode}.cm*
        ${bytecode} > ${bytecode}.reference
        ./microcaml ${bytecode} > ${bytecode}.output
        diff -u ${bytecode}.output ${bytecode}.reference && echo '+' || exit
    done
done

rm --recursive --force $tmpdir
