#!/usr/bin/env bash

MODULE=`perl -ne 'print($1),exit if m{version_from.+?([\w/.]+)}i' Makefile.PL`;
perl=perl
$perl -v

rm -rf MANIFEST.bak Makefile.old *.tar.gz && \
$perl Makefile.PL && \
make manifest && \
make && \
make disttest && \
make dist && \
cp -f *.tar.gz dist/ && \
make clean && \
rm -rf MANIFEST.bak Makefile.old *.tar.gz && \
echo "All is OK"
