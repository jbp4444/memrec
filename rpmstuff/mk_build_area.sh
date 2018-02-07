#!/bin/csh
#
# script to create rpm-build area
#

set TOP = /tmp/rpmbuild

mkdir -p $TOP

foreach d ( SOURCES SPECS BUILD BUILDROOT SRPMS RPMS )
	mkdir -p $TOP/$d
end

