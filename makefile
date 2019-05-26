#Makefile for HWSensor
SRCROOT = $(CURDIR)
LC_ALL=C
export LC_ALL

all: makebin

makebin:
	@${SRCROOT}/makebin

kexts:
	@${SRCROOT}/makebin 1

pkg:	
	@${SRCROOT}/makebin
	@${SRCROOT}/makepkg

clean:
	@${SRCROOT}/makebin clean

fresh: clean pkg

.PHONY: clean pkg makebin kexts