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
	xcodebuild -quiet -project ${SRCROOT}/trunk/HWSensors.xcodeproj -alltargets clean
	xcodebuild -quiet -project ${SRCROOT}/trunk/hwmonitor/HWMonitorSMC.xcodeproj -alltargets clean
	xcodebuild -quiet -project ${SRCROOT}/trunk/hwmonitor2/HWMonitorSMC.xcodeproj -alltargets clean
	xcodebuild -quiet -project ${SRCROOT}/package/utils/partutil/partutil.xcodeproj -alltargets clean
	xcodebuild -quiet -project ${SRCROOT}/package/utils/seticon/seticon.xcodeproj -alltargets clean
	rm -rf compilations package/utils/partutil/build package/utils/seticon/build trunk/hwmonitor/build trunk/hwmonitor2/build trunk/build

.PHONY: clean pkg makebin 