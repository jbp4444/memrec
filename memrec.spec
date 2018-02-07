Name:		memrec
Version:	0.1
Release:	5%{?dist}
Summary:	memrec is a set of tools/modules for building system/process "recording" scripts

Group:		General/Monitoring
License:	BSD
URL:		http://sites.duke.edu/scsc
Source0:	memrec.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}

%description
memrec is a set of tools and modules that can be used to build system and process
"recording" scripts (i.e. monitoring systems).  Some of the tools log output to syslog 
(generally, local4), and through syslog you can break out different data into their
own files, rotate the log files, forward the data, etc. using standard system tools.
This package also contains a script to use as a loadsensor for Gridengine, as well as
an older version of ipmitool as the latest version does not work with the Dell servers
in the DSCR.

%prep
%setup -q -n memrec


%build
cd src/tstat
/usr/bin/gcc -o dump_tstat dump_tstat.c

cd ../ipmitool-1.8.9
./configure --prefix=/opt/memrec
make

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/memrec/bin
mkdir -p %{buildroot}/opt/memrec/sbin
mkdir -p %{buildroot}/opt/memrec/etc
mkdir -p %{buildroot}/opt/memrec/lib/memrec
mkdir -p %{buildroot}/opt/memrec/share
mkdir -p %{buildroot}/etc/init.d
cp %{_builddir}/memrec/bin/* %{buildroot}/opt/memrec/bin/
cp %{_builddir}/memrec/sbin/* %{buildroot}/opt/memrec/sbin/
cp -r %{_builddir}/memrec/etc/* %{buildroot}/opt/memrec/etc/
cp %{_builddir}/memrec/lib/memrec/* %{buildroot}/opt/memrec/lib/memrec/
cp %{_builddir}/memrec/scripts/* %{buildroot}/etc/init.d/
cp %{_builddir}/memrec/src/tstat/dump_tstat %{buildroot}/opt/memrec/sbin/

cd src/ipmitool-1.8.9
make DESTDIR=${RPM_BUILD_ROOT} install

%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
/opt/memrec/bin/*
/opt/memrec/sbin/*
/opt/memrec/etc/*
/opt/memrec/lib/*
/opt/memrec/share/*
%attr(4755,root,root) /opt/memrec/sbin/dump_tstat
%attr(4755,root,root) /opt/memrec/bin/ipmitool
/etc/init.d/*


%changelog
* Tue Apr 23 2013 Mike Newton <jmnewton@duke.edu>
- At the request of John Pormann make ipmitool setuid root
* Wed Apr 10 2013 Mike Newton <jmnewton@duke.edu>
- Changes to the dlogger program and adding older version of ipmitool
* Mon Mar 18 2013 Mike Newton <jmnewton@duke.edu>
- Deleted qloadsensor by mistake. Adding back in.
* Wed Mar 13 2013 Mike Newton <jmnewton@duke.edu>
- Add latest changes from John Pormann
* Mon Jan 14 2013 Mike Newton <jmnewton@duke.edu>
- First build for DSCR
