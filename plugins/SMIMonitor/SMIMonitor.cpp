/*
 *  SMIMonitor.cpp
 *  HWSensors
 *
 *  Copyright 2014 Slice. All rights reserved.
 *
 */

#include "SMIMonitor.h"
#include "FakeSMC.h"
#include "utils.h"

#ifndef Debug
#define Debug FALSE
#endif

#define LogPrefix "SMIMonitor: "
#define DebugLog(string, args...)	do { if (Debug) { IOLog (LogPrefix "[Debug] " string "\n", ## args); } } while(0)
#define WarningLog(string, args...) do { IOLog (LogPrefix "[Warning] " string "\n", ## args); } while(0)
#define InfoLog(string, args...)	do { IOLog (LogPrefix string "\n", ## args); } while(0)

#define super IOService
OSDefineMetaClassAndStructors(SMIMonitor, IOService)

bool SMIMonitor::addSensor(const char* key, const char* type, unsigned int size) {
  if (kIOReturnSuccess != fakeSMC->callPlatformFunction(kFakeSMCAddKeyHandler,
                                                        false, (void *)key,
                                                        (void *)type,
                                                        (void *)(size_t)size,
                                                        (void *)this)) {
    WarningLog("Can't add key %s to fake SMC device, kext will not load", key);
    return false;
  }
	return true;
}

// for example addTachometer(0, "System Fan");
bool SMIMonitor::addTachometer(int index, const char* id) {
	UInt8 length = 0;
	void * data = 0;
	
	if (kIOReturnSuccess == fakeSMC->callPlatformFunction(kFakeSMCGetKeyValue,
                                                        true,
                                                        (void *)KEY_FAN_NUMBER,
                                                        (void *)&length,
                                                        (void *)&data,
                                                        0)) {
		char key[5];
		length = 0;
		
		bcopy(data, &length, 1);
		
		snprintf(key, 5, KEY_FORMAT_FAN_SPEED, length);
		
		if (addSensor(key, TYPE_FPE2, 2)) {
			if (id) {
				FanTypeDescStruct fds;
				snprintf(key, 5, KEY_FORMAT_FAN_ID, length);
				fds.type = FAN_PWM_TACH;
				fds.ui8Zone = 1;
				fds.location = LEFT_LOWER_FRONT;
				strncpy(fds.strFunction, id, DIAG_FUNCTION_STR_LEN);
        
				if (kIOReturnSuccess != fakeSMC->callPlatformFunction(kFakeSMCAddKeyValue,
                                                              false,
                                                              (void *)key,
                                                              (void *)TYPE_FDESC,
                                                              (void *)((UInt64)sizeof(fds)),
                                                              (void *)&fds)) {
          
					WarningLog("error adding tachometer id value");
				}
			}
			
			length++;
			
			if (kIOReturnSuccess != fakeSMC->callPlatformFunction(kFakeSMCSetKeyValue,
                                                            true,
                                                            (void *)KEY_FAN_NUMBER,
                                                            (void *)1,
                                                            (void *)&length,
                                                            0)) {
				WarningLog("error updating FNum value");
			}
			return true;
		}
  } else {
    WarningLog("error reading FNum value");
  }
  
	return false;
}
/*
 SMIC=0xB2
 SMIA=0x86
Mutex (SMIX, 0x01)
Method (SMI, 2, NotSerialized)
{
  Acquire (SMIX, 0xFFFF)
  Store (Arg1, \_SB.SMIA)
  Store (Arg0, \_SB.SMIC)
  Store (\_SB.SMIC, Local0)
  While (LNotEqual (Local0, Zero))
  {
    Store (\_SB.SMIC, Local0)
  }
  
  Store (\_SB.SMIA, Local1)
  Release (SMIX)
  Return (Local1)
}
*/

SMMRegisters *globalRegs;
static int gRc;
//static int fanMult;
//inline
static
int smm(SMMRegisters *regs)
{
  
  int rc;
  int eax = regs->eax;  //input value

#if __LP64__
  asm volatile("pushq %%rax\n\t"
               "movl 0(%%rax),%%edx\n\t"
               "pushq %%rdx\n\t"
               "movl 4(%%rax),%%ebx\n\t"
               "movl 8(%%rax),%%ecx\n\t"
               "movl 12(%%rax),%%edx\n\t"
               "movl 16(%%rax),%%esi\n\t"
               "movl 20(%%rax),%%edi\n\t"
               "popq %%rax\n\t"
               "out %%al,$0xb2\n\t"
               "out %%al,$0x84\n\t"
               "xchgq %%rax,(%%rsp)\n\t"
               "movl %%ebx,4(%%rax)\n\t"
               "movl %%ecx,8(%%rax)\n\t"
               "movl %%edx,12(%%rax)\n\t"
               "movl %%esi,16(%%rax)\n\t"
               "movl %%edi,20(%%rax)\n\t"
               "popq %%rdx\n\t"
               "movl %%edx,0(%%rax)\n\t"
               "pushfq\n\t"
               "popq %%rax\n\t"
               "andl $1,%%eax\n"
               : "=a"(rc)
               :    "a"(regs)
               :    "%ebx", "%ecx", "%edx", "%esi", "%edi", "memory");
#else
  asm volatile("pushl %%eax\n\t"
               "movl 0(%%eax),%%edx\n\t"
               "push %%edx\n\t"
               "movl 4(%%eax),%%ebx\n\t"
               "movl 8(%%eax),%%ecx\n\t"
               "movl 12(%%eax),%%edx\n\t"
               "movl 16(%%eax),%%esi\n\t"
               "movl 20(%%eax),%%edi\n\t"
               "popl %%eax\n\t"
               "out %%al,$0xb2\n\t"
               "out %%al,$0x84\n\t"
               "xchgl %%eax,(%%esp)\n\t"
               "movl %%ebx,4(%%eax)\n\t"
               "movl %%ecx,8(%%eax)\n\t"
               "movl %%edx,12(%%eax)\n\t"
               "movl %%esi,16(%%eax)\n\t"
               "movl %%edi,20(%%eax)\n\t"
               "popl %%edx\n\t"
               "movl %%edx,0(%%eax)\n\t"
               "lahf\n\t"
               "shrl $8,%%eax\n\t"
               "andl $1,%%eax\n"
               : "=a"(rc)
               :    "a"(regs)
               :    "%ebx", "%ecx", "%edx", "%esi", "%edi", "memory");
#endif
  
  if ((rc != 0) || ((regs->eax & 0xffff) == 0xffff) || (regs->eax == eax)) {
    return -1;
  }

  return 0;
}

void read_smi(void * magic) {
  SMMRegisters *regs = (SMMRegisters *)magic;
  volatile UInt32 i = cpu_number();
  if (i == 0) { /* SMM requires CPU 0 */
    gRc = smm(regs);
  } else gRc = -1;
}

int SMIMonitor::i8k_smm(SMMRegisters *regs)
{
//  size_t magic = 0;
//  globalRegs = regs;
  mp_rendezvous_no_intrs(read_smi, (void *)regs);
  return gRc;
}

int SMIMonitor::i8k_get_bios_version(void) {
  INIT_REGS;
  int rc;
  
  regs.eax = I8K_SMM_BIOS_VERSION;
  if ((rc = i8k_smm(&regs)) < 0) {
    return rc;
  }
  
  return regs.eax;
}

/*
 * Read the CPU temperature in Celcius.
 */
int SMIMonitor::i8k_get_temp(int sensor) {
  INIT_REGS;
  int rc;
  int temp;
  
  regs.eax = I8K_SMM_GET_TEMP;
  regs.ebx = sensor & 0xFF;
  if ((rc=i8k_smm(&regs)) < 0) {
    return rc;
  }
	
  temp = regs.eax & 0xff;
  if (temp == 0x99) {
    IOSleep(100);
	regs.eax = I8K_SMM_GET_TEMP;
    regs.ebx = sensor & 0xFF;
    if ((rc=i8k_smm(&regs)) < 0) {
      return rc;
    }

    temp = regs.eax & 0xff;
  }

  return temp;
}

bool SMIMonitor::i8k_get_dell_sig_aux(int fn) {
  INIT_REGS;
  int rc;
  
  regs.eax = fn;
  if ((rc=i8k_smm(&regs)) < 0) {
    WarningLog("No function 0x%x", fn);
    return false;
  }
  InfoLog("Got sigs %x and %x", regs.eax, regs.edx);
  return ((regs.eax == 0x44494147 /*DIAG*/) &&
          (regs.edx == 0x44454C4C /*DELL*/));
}

bool SMIMonitor::i8k_get_dell_signature(void) {
  
  return (i8k_get_dell_sig_aux(I8K_SMM_GET_DELL_SIG1) ||
          i8k_get_dell_sig_aux(I8K_SMM_GET_DELL_SIG2));
}


/*
 * Read the power status.
 */
int SMIMonitor::i8k_get_power_status(void) {
  INIT_REGS;
  int rc;
/*
  regs.eax = I8K_SMM_GET_POWER_TYPE;
  i8k_smm(&regs);
  InfoLog("Got power type=%d", (regs.eax & 0xff));
*/
  regs.eax = I8K_SMM_POWER_STATUS;
  if ((rc=i8k_smm(&regs)) < 0) {
    WarningLog("No power status");
    return rc;
  }
  InfoLog("Got power status=%d", (regs.eax & 0xff));
  return regs.eax & 0xff; // 0 = No Batt, 3 = No AC, 1 = Charging, 5 = Full.
}

/*
 * Read the fan speed in RPM.
 */
int SMIMonitor::i8k_get_fan_speed(int fan) {
  INIT_REGS;
  int rc;
  int speed = 0;
  
  regs.eax = I8K_SMM_GET_SPEED;
  regs.ebx = fan & 0xff;
  if ((rc=i8k_smm(&regs)) < 0) {
    return rc;
  }
  speed = (regs.eax & 0xffff) * fanMult;
  return speed;
}

/*
 * Read the fan status.
 */
int SMIMonitor::i8k_get_fan_status(int fan) {
  INIT_REGS;
  int rc;
  
  regs.eax = I8K_SMM_GET_FAN;
  regs.ebx = fan & 0xff;
  if ((rc=i8k_smm(&regs)) < 0) {
    return rc;
  }
  
  return (regs.eax & 0xff);
}

/*
 * Read the fan nominal rpm for specific fan speed.
 */
int SMIMonitor::i8k_get_fan_nominal_speed(int fan, int speed)
{
	INIT_REGS;
	regs.eax = I8K_SMM_GET_NOM_SPEED;
	regs.ebx = (fan & 0xff) | (speed << 8);
	return i8k_smm(&regs) ? 0 : (regs.eax & 0xffff) * fanMult;
}

/*
 * Set the fan speed (off, low, high). Returns the new fan status.
 */
int SMIMonitor::i8k_set_fan(int fan, int speed)
{
	INIT_REGS;
	regs.eax = I8K_SMM_SET_FAN;

	speed = (speed < 0) ? 0 : ((speed > I8K_FAN_MAX) ? I8K_FAN_MAX : speed);
	regs.ebx = (fan & 0xff) | (speed << 8);

	return i8k_smm(&regs) ? -1 : i8k_get_fan_status(fan);
}


IOService* SMIMonitor::probe(IOService *provider, SInt32 *score) {
  if (super::probe(provider, score) != this) { return 0; }
  
  if (!i8k_get_dell_signature()) {
    WarningLog("Unable to get Dell SMM signature!");
    return NULL;
  }

  InfoLog("Based on I8kfan project adopted to HWSensors by Slice 2014");
//  InfoLog("Dell BIOS version=%x", i8k_get_bios_version());
/*  InfoLog("Dump SMI ------------");
  INIT_REGS;
  int rc;

  regs.eax = I8K_SMM_POWER_STATUS;
  rc=i8k_smm(&regs);
  InfoLog("POWER_STATUS: rc=0x%x eax=0x%x", rc, regs.eax);

  for (int i=0; i<6; i++) {
    memset(&regs, 0, sizeof(regs));
    regs.eax = I8K_SMM_GET_FAN;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    InfoLog("GET_FAN %d: rc=0x%x eax=0x%x", i, rc, regs.eax);
    memset(&regs, 0, sizeof(regs));
    if (rc < 0) continue;
    regs.eax = I8K_SMM_FN_STATUS;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    InfoLog("FN_STATUS %d: rc=0x%x eax=0x%x", i, rc, regs.eax);
    if (rc < 0) continue;
    memset(&regs, 0, sizeof(regs));
    regs.eax = I8K_SMM_GET_FAN_TYPE;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    InfoLog("GET_FAN_TYPE: rc=0x%x eax=0x%x", rc, regs.eax);
    memset(&regs, 0, sizeof(regs));
    regs.eax = I8K_SMM_GET_SPEED;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    InfoLog("GET_SPEED: rc=0x%x eax=0x%x", rc, regs.eax);
    memset(&regs, 0, sizeof(regs));
    regs.eax = I8K_SMM_GET_NOM_SPEED;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    InfoLog("GET_NOM_SPEED: rc=0x%x eax=0x%x", rc, regs.eax);
  }

  for (int i=0; i<6; i++) {
    memset(&regs, 0, sizeof(regs));
    regs.eax = I8K_SMM_GET_TEMP;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    if (rc < 0) continue;
    InfoLog("GET_TEMP %d: rc=0x%x eax=0x%x", i, rc, regs.eax);
  }
  */

  i8k_get_power_status();

	return this;
}

bool SMIMonitor::start(IOService * provider)
{
  INIT_REGS;
  int rc = 0;
  if (!provider || !super::start(provider)) { return false; }
  
  if (!(fakeSMC = waitForService(serviceMatching(kFakeSMCDeviceService)))) {
    WarningLog("Can't locate fake SMC device, kext will not load");
    return false;
  }

  char key[5];
  
  //Here are Fans in info.plist
  OSArray* fanNames = OSDynamicCast(OSArray, getProperty("FanNames"));
  int fanNum =0;
  for (int i=0; i<6; i++) {  

    memset(&regs, 0, sizeof(regs));
    regs.eax = I8K_SMM_GET_FAN;
    regs.ebx = i;
    rc=i8k_smm(&regs);
    if (rc < 0) continue; //laptop has one fan, but desktop 0 and 2; continue search

    fanNum++;
    snprintf(key, 5, "FAN%X", i);
    
    OSString* name = NULL;
    
    if (fanNames) {
      name = OSDynamicCast(OSString, fanNames->getObject(i));
    }
    
    if (!addTachometer(i, name ? name->getCStringNoCopy() : 0)) {
      WarningLog("Can't add tachometer sensor, key %s", key);
    }
	//add special key for fan status control
	snprintf(key, 5, "F%XAs", i);
	addSensor(key, TYPE_UI8, 1);  //F0As
  }
//  addSensor(KEY_CPU_PROXIMITY_TEMPERATURE, TYPE_SP78, 2);

  memset(&regs, 0, sizeof(regs));
  regs.eax = I8K_SMM_GET_TEMP;
  regs.ebx = 0;
  if (!i8k_smm(&regs)) addSensor(KEY_CPU_PROXIMITY_TEMPERATURE, TYPE_SP78, 2);  //TC0P
  memset(&regs, 0, sizeof(regs));
  regs.eax = I8K_SMM_GET_TEMP;
  regs.ebx = 1;
  if (!i8k_smm(&regs))   addSensor(KEY_GPU_PROXIMITY_TEMPERATURE, TYPE_SP78, 2);  //TG0P
  memset(&regs, 0, sizeof(regs));
  regs.eax = I8K_SMM_GET_TEMP;
  regs.ebx = 2;
  if (!i8k_smm(&regs))   addSensor(KEY_DIMM_TEMPERATURE, TYPE_SP78, 2);  //Tm0P
  memset(&regs, 0, sizeof(regs));
  regs.eax = I8K_SMM_GET_TEMP;
  regs.ebx = 3;
  if (!i8k_smm(&regs))   addSensor(KEY_NORTHBRIDGE_TEMPERATURE, TYPE_SP78, 2);  //TN0P
  memset(&regs, 0, sizeof(regs));
  regs.eax = I8K_SMM_GET_TEMP;
  regs.ebx = 4;
  if (!i8k_smm(&regs))   addSensor(KEY_AMBIENT_TEMPERATURE, TYPE_SP78, 2);  //TA0P

  registerService(0);
  
  return true;
}

bool SMIMonitor::init(OSDictionary *properties) {
  if (!super::init(properties)) {
    return false;
  }
  if (!(sensors = OSDictionary::withCapacity(0))) {
    return false;
  }
  fanMult = 1;
  OSNumber * Multiplier = OSDynamicCast(OSNumber, properties->getObject("FanMultiplier"));
  if (Multiplier) 
    fanMult = Multiplier->unsigned32BitValue();
  return true;
}

void SMIMonitor::stop(IOService* provider) {
  sensors->flushCollection();
  if (kIOReturnSuccess != fakeSMC->callPlatformFunction(kFakeSMCRemoveKeyHandler,
                                                        true,
                                                        this,
                                                        NULL,
                                                        NULL,
                                                        NULL)) {
    WarningLog("Can't remove key handler");
    IOSleep(500);
  }
  
  super::stop(provider);
}

void SMIMonitor::free() {
  sensors->release();
  super::free();
}

#define MEGA10 10000000ull
IOReturn SMIMonitor::callPlatformFunction(const OSSymbol *functionName,
                                          bool waitForFunction,
                                          void *param1,
                                          void *param2,
                                          void *param3,
                                          void *param4) {
  const char* name = (const char*)param1;
  void * data = param2;
//  UInt64 size = (UInt64)param3;

#if __LP64__
  UInt64 value;
#else
  UInt32 value;
#endif
  UInt16 val;
  
  if (functionName->isEqualTo(kFakeSMCSetValueCallback)) {
    if (name && data) {
      InfoLog("Writing key=%s value=%x", name, *(UInt16*)data);
      //OSObject * params[1];
      if ((name[0] == 'F') && (name[2] == 'A') && (name[3] == 's')) {  //set fan status {off, low, high}
        val = *(UInt8*)data;
        int fan = (int)(name[1] - '0');
        int ret = i8k_set_fan(fan, val);
        if (ret == val) {
          return kIOReturnSuccess;
        } else {
          return kIOReturnError;
        }
      }
    }
    return kIOReturnBadArgument;
  }

  if (functionName->isEqualTo(kFakeSMCGetValueCallback)) {
    if (name && data) {
      val = 0;
      if (name[0] == 'F') {
        if ((name[2] == 'A') && (name[3] == 'c')) {
          int fan = (int)(name[1] - '0');
          value = i8k_get_fan_speed(fan);
          val = encode_fpe2(value);
          bcopy(&val, data, 2);
          return kIOReturnSuccess;
		}
		else if ((name[2] == 'A') && (name[3] == 's')) {
			int fan = (int)(name[1] - '0');
			val = i8k_get_fan_status(fan);
			bcopy(&val, data, 1);
			return kIOReturnSuccess;
		}
      } else if ((name[0] == 'T') && (name[2] == '0') && (name[3] == 'P')) {
        if (name[1] == 'C') {
          val = i8k_get_temp(0);
        } else if (name[1]  == 'G') {
          val = i8k_get_temp(1);
        } else if (name[1]  == 'm') {
          val = i8k_get_temp(2);
        } else if (name[1]  == 'N') {
          val = i8k_get_temp(3);
        } else if (name[1]  == 'A') {
          val = i8k_get_temp(4);
        }
        bcopy(&val, data, 1);
        return kIOReturnSuccess;
      }
      return kIOReturnBadArgument; //no key or no pointer to data
    }
    //DebugLog("bad argument key name or data");
    return kIOReturnBadArgument;
  }

  return super::callPlatformFunction(functionName, waitForFunction, param1, param2, param3, param4);
}
