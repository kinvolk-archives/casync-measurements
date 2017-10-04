#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z ${WORKDIR} ] ; then
	WORKDIR=`mktemp -d -p "$DIR"`
fi
mkdir -p "$WORKDIR"
cd "$WORKDIR"

DOCKER2ACI=${DOCKER2ACI-docker2aci}
CASYNC=${CASYNC-casync}

IMAGES=(
	library/ubuntu:zesty-20170913
	library/ubuntu:zesty-20170703
	library/ubuntu:zesty-20170619
	library/ubuntu:zesty-20170411
	library/ubuntu:zesty-20170224
	library/ubuntu:zesty-20170118
	library/ubuntu:zesty-20161212
)

IMAGES=(
	weaveworks/scope:master-73f9b835
	weaveworks/scope:master-02101543
	weaveworks/scope:master-46c5fca7
	weaveworks/scope:master-c74e683a
	weaveworks/scope:master-03475cec
	weaveworks/scope:master-74c0c782
)

IMAGES=(
	weaveworksdemos/front-end:master-fe7f9828
	weaveworksdemos/front-end:master-b2308a3e
	weaveworksdemos/front-end:master-bdc6f3ff
	weaveworksdemos/front-end:master-3fad5eda
	weaveworksdemos/front-end:master-ac9ca707
	weaveworksdemos/front-end:master-82ebb7c9
)

IMAGES=(
	prom/prometheus:v2.0.0-beta.0
	prom/prometheus:v2.0.0-beta.1
	prom/prometheus:v2.0.0-beta.2
	prom/prometheus:v2.0.0-beta.3
	prom/prometheus:v2.0.0-beta.4
	prom/prometheus:v2.0.0-beta.5
)

IMAGES=(
	library/registry:0.6.1
	library/registry:0.6.2
	library/registry:0.6.3
	library/registry:0.6.4
	library/registry:0.6.5
	library/registry:0.6.6
	library/registry:0.6.7
	library/registry:0.6.8
	library/registry:0.6.9
	library/registry:0.7.0
	library/registry:0.7.1
)

TAGS=$(wget -q https://registry.hub.docker.com/v1/repositories/registry/tags -O -  | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n'  | awk -F: '{print $3}')
IMAGES=()
for i in $TAGS ; do
	IMAGES+=( library/registry:$i )
done

function acifile_from_name() {
	image=$1
	acifile=${image//\//-}
	acifile=${acifile//:/-}.aci
	echo $acifile
}

for image in "${IMAGES[@]}" ; do
	acifile=`acifile_from_name $image`

	if [ -f $acifile ] ; then
		echo "$acifile already here"
	else
		$DOCKER2ACI docker://$image
	fi

	if [ -d ${acifile}.dir ] ; then
		echo "$acifile.dir already here"
	else
		mkdir -p ${acifile}.dir
		(cd ${acifile}.dir && tar xf ../${acifile})
	fi

	mkdir -p ${acifile}.store
done


for image in "${IMAGES[@]}" ; do
	acifile=`acifile_from_name $image`

	if [ -f ${acifile}.du ] ; then
		echo "${acifile}.du already here"
	else
		casync make --without=user-names --compression=gzip --store=${acifile}.store ${acifile}.caidx ${acifile}.dir
		casync make --without=user-names --compression=gzip --store=store ${acifile}.caidx ${acifile}.dir
		du -s ${acifile}.store | tee ${acifile}.du
		du -s store            | tee ${acifile}.cumulated.du
	fi
done

echo
echo "version;aci size;store;accumulated store;downloaded with casync"
acc=0
for image in "${IMAGES[@]}" ; do
	acifile=`acifile_from_name $image`
	version=`echo $image  | cut -d: -f2`
	acisize=$((`stat --printf="%s" $acifile` / 1024))
	storesize=`gawk '{print $1}' ${acifile}.du`
	casyncsize=`gawk '{print $1}' ${acifile}.cumulated.du`
	
	echo "'$version;$acisize;$storesize;$casyncsize;$(($casyncsize - $acc))"

	acc=$casyncsize
done
