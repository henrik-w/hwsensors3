#Makefile for HWSensor
SRCROOT = $(CURDIR)
LC_ALL=C
export LC_ALL

all: makebin

makebin:
	@${SRCROOT}/makebin 1 1 1 0

kexts:
	@${SRCROOT}/makebin 1 0 0 0

monitor1:
	@${SRCROOT}/makebin 0 1 0 0

monitor2:
	@${SRCROOT}/makebin 0 0 1 0


pkg:	
	@${SRCROOT}/makebin 1 1 1 0
	@${SRCROOT}/makepkg

clean:
	@${SRCROOT}/makebin 0 0 0 1

fresh: clean pkg

.PHONY: clean pkg makebin kexts