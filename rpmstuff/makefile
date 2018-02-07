#
#

nothing:
	@echo Try 'make {new clean clobber build}'

new:
	-mkdir SOURCES SPECS BUILD BUILDROOT SRPMS RPMS
	( cd SPECS ; ln -s /bdscratch/jbp1/seq/memrec/rpmstuff/memrec.spec . )
	( cd SPECS ; ln -s /bdscratch/jbp1/seq/memrec/rpmstuff/dlogger_cfg.spec . )
	( cd SPECS ; ln -s /bdscratch/jbp1/seq/memrec/rpmstuff/duologger_cfg.spec . )
	( cd SPECS ; ln -s /bdscratch/jbp1/seq/memrec/rpmstuff/qloadsensor_cfg.spec . )

build:
	rpmbuild -ba SPECS/memrec.spec
	rpmbuild -ba SPECS/dlogger_cfg.spec
	rpmbuild -ba SPECS/duologger_cfg.spec
	rpmbuild -ba SPECS/qloadsensor_cfg.spec

clean:
	-rm -rf BUILD/* BUILDROOT/*

clobber: clean
	-rm -rf RPMS/* SRPMS/*

