#!/bin/bash

DIR=$DIR
FINALDIR=$FINALDIR
FILE=$FILE
QUALITY=$QUALITY

cd $DIR

perl /rsgrps1/mbsulli/bioinfo/biotools/DynamicTrim.pl $FILE -h 20 -illumina

mv $FILE.trimmed $FINALDIR

FILEPATH=$FINALDIR/$FILE.trimmed

exec /rsgrps1/mbsulli/bioinfo/biotools/FastQC/fastqc -o=$QUALITY $FILEPATH