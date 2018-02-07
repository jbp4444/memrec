#
# rpm spec file for duologger.pl
#
Summary: duologger logs custom info to syslog every 1 and N minutes
Name: duologger_cfg
Version: 0.1
Release: 5
License: BSD
Group: General/Monitoring
Source: memrec.tar.gz
URL: http://sites.duke.edu/scsc
Vendor: Duke University
BuildArch: noarch
BuildRoot: %{_topdir}/BUILDROOT/%{name}-%{version}
Requires: memrec

%description
duologger is a system monitoring tool that runs a custom set of probes every 1 minute,
with output to syslog (local4) every N minutes.  Once in syslog, you can break it out into its
own file, rotate the log riles, forward the data, etc. using standard system tools.
The duologger_cfg rpm provides config files for those tools.

%prep
cd %{_builddir}
tar xzf %{_topdir}/SOURCES/memrec.tar.gz

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/etc
cp %{_builddir}/memrec/etc/duologger.cfg.pl %{buildroot}/usr/local/etc/.

%files
%defattr(-,root,root)
/usr/local/etc/duologger.cfg.pl

%post
if [ "$1" = "1" ]; then
	# new installation
	/sbin/chkconfig --level 345 duologger on
	/sbin/service duologger start
elif [ "$1" = "2" ]; then
	# upgrade
	/sbin/service duologger reload
	retval=$?
	if [ "$retval" = "7" ]; then
		# the service wasn't running .. couldn't reload config
		/sbin/service duologger start
	fi
fi

%preun
if [ "$1" = "0" ]; then
	# simple uninstallation
	/sbin/service duologger stop
fi

%changelog
* Tue Aug 28 2012 John Pormann <jbp1@duke.edu>
- first attempt at rpm spec file

