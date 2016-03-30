#!/bin/sh

DATA_DIR=../var/2016-02

java -jar /opt/qSKOS/target/qSKOS-cmd.jar analyze -np -d -c ol,chr,usr,rc,mc,ipl,dlv,urc $DATA_DIR/rdf/swdskos.ttl.gz -o $DATA_DIR/log/qskos_extended.log

