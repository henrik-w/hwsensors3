#Makefile for HWSensor
SRCROOT = $(CURDIR)
LC_ALL=C
export LC_ALL

all: makebin

makebin:
	@${SRCROOT}/makebin

pkg:	
	@${SRCROOT}/makebin
	@${SRCROOT}/makepkg

clean:
	rm -rf compilations

.PHONY: clean pkg makebin 
