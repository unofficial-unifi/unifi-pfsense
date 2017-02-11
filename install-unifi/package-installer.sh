#!/bin/sh

# OS architecture
OS_ARCH=`getconf LONG_BIT`

#FreeBSD package source:
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/freebsd:10:x86:${OS_ARCH}/latest/All/"

#FreeBSD package list: 
FREEBSD_PACKAGE_LIST_URL="http://pkg.freebsd.org/freebsd:10:x86:${OS_ARCH}/latest/packagesite.txz" 
 
#JSON shell parser script: 
JSON_PARSER_URL="https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh" 


#fetch ${FREEBSD_PACKAGE_LIST_URL} 
#tar vfx packagesite.txz 
#fetch ${JSON_PARSER_URL} 
#chmod +x JSON.sh 
 
GetDeps () { 
	pkgname=$1	
	pkginfo=`grep "\"name\":\"$pkgname\"" packagesite.yaml`
	pkgvers=`echo $pkginfo | ./JSON.sh -l | pcregrep -o1 '^\["version"\]\s+"(.*)"$'`
	
	echo $pkgname
	echo $pkginfo
	echo $pkgvers

        for dep in `echo $pkginfo | ./JSON.sh -l | pcregrep -o1 -o2 --om-separator="-" '^\["deps"\,"(.*)","version"\]\s+"(.*)"$'`
        do 
                echo $dep 
        done

	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add ${FREEBSD_PACKAGE_URL}${pkgname}-${pkgvers}.txz 
}
 
GetDeps mongodb 

