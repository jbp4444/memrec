#
# rpm spec file for memrec/qloadsensor.pl
#
Summary: qloadsensor_cfg is a set of configuration bits for memrec
Name: qloadsensor_cfg
Version: 0.1
Release: 1
License: BSD
Group: General/Monitoring
Source: memrec.tar.gz
URL: http://sites.duke.edu/scsc
Vendor: Duke University
BuildArch: noarch
BuildRoot: %{_topdir}/BUILDROOT/%{name}-%{version}
Requires: memrec

%description
This is a load-sensor script for Grid Engine that leverages the memrec tools.
It deploys its config file into /usr/local/etc/qloadsensor.cfg.pl

%prep
cd %{_builddir}
tar xzf %{_topdir}/SOURCES/memrec.tar.gz

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/etc
cp %{_builddir}/memrec/etc/qloadsensor.cfg.pl %{buildroot}/usr/local/etc/.

%files
%defattr(-,root,root)
/usr/local/etc/qloadsensor.cfg.pl

%post
if [ "$1" = "2" ]; then
	# upgrade
	/usr/bin/killall -INT qloadsensor.pl
fi

%changelog
* Tue Aug 28 2012 John Pormann <jbp1@duke.edu>
- first attempt at rpm spec file

