#
# makefile to build the tar file
#

nothing:
	@echo Try:  'make tar' or 'make tar.gz'

tar:
	( cd .. ; tar cf memrec.tar memrec/ --exclude .svn )
tar.gz:
	( cd .. ; tar cf memrec.tar memrec/ --exclude .svn ; gzip memrec.tar )
tgz: tar.gz
	mv memrec.tar.gz memrec.tgz

