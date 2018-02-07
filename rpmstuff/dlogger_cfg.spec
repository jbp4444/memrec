#
# rpm spec file for dlogger.pl
#
Summary: dlogger logs custom info to syslog every N minutes
Name: dlogger_cfg
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
dlogger is a system monitoring tool that runs a custom set of probes every N minutes,
and logs the output to syslog (local4).  Once in syslog, you can break it out into its
own file, rotate the log riles, forward the data, etc. using standard system tools.
The dlogger_cfg rpm provides config files for those tools.

%prep
cd %{_builddir}
tar xzf %{_topdir}/SOURCES/memrec.tar.gz

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/etc
cp %{_builddir}/memrec/etc/dlogger.cfg.pl %{buildroot}/usr/local/etc/.

%files
%defattr(-,root,root)
/usr/local/etc/dlogger.cfg.pl

%post
if [ "$1" = "1" ]; then
	# new installation
	/sbin/chkconfig --level 345 dlogger on
	/sbin/service dlogger start
elif [ "$1" = "2" ]; then
	# upgrade
	/sbin/service dlogger reload
	retval=$?
	if [ "$retval" = "7" ]; then
		# the service wasn't running .. couldn't reload config
		/sbin/service dlogger start
	fi
fi

%preun
if [ "$1" = "0" ]; then
	# simple uninstallation
	/sbin/service dlogger stop
fi

%changelog
* Tue Aug 28 2012 John Pormann <jbp1@duke.edu>
- first attempt at rpm spec file

