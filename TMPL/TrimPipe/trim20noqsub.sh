#!/bin/bash
DIR=$1
FINALDIR=$2
FILE=$3
QUALITY=$4

cd $DIR

perl /rsgrps1/mbsulli/bioinfo/biotools/DynamicTrim.pl $FILE -h 20 -illumina

mv $FILE.trimmed $FINALDIR

FILEPATH=$FINALDIR/$FILE.trimmed

exec /rsgrps1/mbsulli/bioinfo/biotools/FastQC/fastqc -o=$QUALITY $FILEPATH