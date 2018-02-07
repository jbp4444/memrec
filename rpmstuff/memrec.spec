#
# rpm spec file for memrec tools
#
Summary: memrec is a set of tools/modules for building system/process "recording" scripts
Name: memrec
Version: 0.1
Release: 1
License: BSD
Group: General/Monitoring
Source: memrec.tar.gz
URL: http://sites.duke.edu/scsc
Vendor: Duke University
BuildArch: x86_64
BuildRoot: %{_topdir}/BUILDROOT/%{name}-%{version}

%description
memrec is a set of tools and modules that can be used to build system and process
"recording" scripts (i.e. monitoring systems).  Some of the tools log output to syslog 
(generally, local4), and through syslog you can break out different data into their
own files, rotate the log files, forward the data, etc. using standard system tools.

%prep
cd %{_builddir}
tar xzf %{_topdir}/SOURCES/memrec.tar.gz

%build
cd %{_builddir}/memrec

/usr/bin/gcc -o src/dump_tstat src/dump_tstat.c

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/usr/local/sbin
mkdir -p %{buildroot}/usr/local/lib/memrec
mkdir -p %{buildroot}/etc/init.d
cp %{_builddir}/memrec/bin/* %{buildroot}/usr/local/bin
cp %{_builddir}/memrec/sbin/* %{buildroot}/usr/local/sbin
cp %{_builddir}/memrec/lib/memrec/* %{buildroot}/usr/local/lib/memrec
cp %{_builddir}/memrec/src/dump_tstat %{buildroot}/usr/local/sbin/.
cp %{_builddir}/memrec/etc/init.d/* %{buildroot}/etc/init.d

%files
%defattr(-,root,root)
/usr/local/bin/*
/usr/local/sbin/*
/usr/local/lib/*
/etc/init.d/*
%attr(4755, root, root) /usr/local/sbin/dump_tstat

%changelog
* Tue Aug 28 2012 John Pormann <jbp1@duke.edu>
- first attempt at rpm spec file

