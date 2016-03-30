#!/bin/bash
# nbt, 2015-12-10

# Create a SKOS thesarus from GND subject headings

# Requires an GND endpoint and an empty endpoint for swdskos

# local endpoints urls and file names
GND_ENDPOINT=http://localhost:8080/fuseki/gnd
SWDSKOS_ENDPOINT=http://localhost:8080/fuseki/swdskos
QUERY_DIR=../sparql
DATA_DIR=../var/2016-02
SWDFILE=$DATA_DIR/rdf/gnd_swdskos_extract.ttl
SCFILE=$DATA_DIR/src/gndsc.rdf
SUPPLFILE=$DATA_DIR/rdf/gndsc_suppl.ttl
DUMPFILE=$DATA_DIR/rdf/swdskos.ttl.gz

# determine the version date from the directory name
tmp=`readlink -f $DATA_DIR`
ISSUED_DATE=`basename $tmp`
NOW=`date --rfc-3339=seconds`

# Construct SKOS file from GND
# This is the most expensive operation, so we skip it if the file is present
if [ -f $SWDFILE.gz ] ; then
  echo "$SWDFILE.gz exists - we use this version"
  ls -l $SWDFILE.gz
else
  echo Construct SWD SKOS file from GND
  curl -X POST --silent -d "query=`cat $QUERY_DIR/construct_as_skos.rq`" $GND_ENDPOINT/query | gzip > $SWDFILE.gz
fi

echo Load SWD SKOS file
gunzip -c $SWDFILE.gz > $SWDFILE
# PUT removes any prior entries - yet the text index may be not correctly updated
curl -X PUT --silent -H "Content-Type: application/x-turtle" -d @$SWDFILE $SWDSKOS_ENDPOINT/data?default > /dev/null
/bin/rm $SWDFILE

echo Download subject categories and load into swdskos endpoint
curl --silent -LH "Accept: application/rdf+xml" http://d-nb.info/standards/vocab/gnd/gnd-sc > $SCFILE
curl -X POST --silent -H "Content-Type: application/rdf+xml" -d @$SCFILE $SWDSKOS_ENDPOINT/data?default > /dev/null

echo Enhance subject categories and load into swdskos endpoint
curl -X POST --silent -d "query=`cat $QUERY_DIR/construct_gndsc_suppl.rq`" $GND_ENDPOINT/query > $SUPPLFILE
curl -X POST --silent -H "Content-Type: application/x-turtle" -d @$SUPPLFILE $SWDSKOS_ENDPOINT/data?default > /dev/null

echo Add metadata about the concept scheme
statement="
prefix dc: <http://purl.org/dc/elements/1.1/>
prefix dcterms: <http://purl.org/dc/terms/>
prefix skos: <http://www.w3.org/2004/02/skos/core#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>

delete {
  # cleanup if already present
  ?scheme dc:date ?date1 .
  ?scheme dcterms:issued ?date2 .
}
insert {
  ?scheme dc:date \"$NOW\" ;
    dcterms:issued \"$ISSUED_DATE\" .
}
where {
  ?scheme a skos:ConceptScheme .
  optional {
    ?scheme dc:date ?date1 .
  }
  optional {
    ?scheme dcterms:issued ?date2 .
  }
}
"
curl -X POST --silent -d "update=$statement" $SWDSKOS_ENDPOINT/update > /dev/null

echo Dump data for download
curl --silent $SWDSKOS_ENDPOINT/data?default | gzip >  $DUMPFILE

