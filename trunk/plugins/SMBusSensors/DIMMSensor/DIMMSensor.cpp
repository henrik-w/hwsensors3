//
// Slice 2015
//
// based on JEDEC datasheets and code template from  Artem Falcon <lomka@gero.in>

#include "DIMMSensor.h"

OSDefineMetaClassAndStructors(TSOD, IOService)

bool TSOD::init (OSDictionary* dict)
{
  bool res = super::init(dict);
  DbgPrint("init\n");
  
	if (!(sensors = OSDictionary::withCapacity(0)))
		return false;
  
  DIMMaddr = 0x18;
  
  return res;
}


void TSOD::free(void)
{
  DbgPrint("free\n");
  
  i2cNub->close(this);
  i2cNub->release();
  
  sensors->release();
  
  super::free();
}

IOService *TSOD::probe (IOService* provider, SInt32* score)
{
  IOService *res = super::probe(provider, score);
  DbgPrint("probe\n");
  return res;
}

bool TSOD::start(IOService *provider)
{
  if (!provider || !super::start(provider)) return false;
  int i, s;
  bool found = false;
  UInt8 cmd, data;
  
  struct MList list = {
     DIMM_TRM, DIMM_TRM, {KEY_DIMM_TEMPERATURE, TYPE_SP78, 2}, true, 0, true
  };
  
//  OSDictionary *conf = NULL, *sconf = OSDynamicCast(OSDictionary, getProperty("Sensors Configuration")), *dict;
//  IOService *fRoot = getServiceRoot();
//  OSString *str, *vendor = NULL;
//  char *key;
//  char tempkey[] = "_temp "; /* Ugly hack to keep keys in order for auto-generated plist */
  
  DbgPrint("start\n");
  
  if (!(i2cNub = OSDynamicCast(I2CDevice, provider))) {
    IOPrint("Failed to cast provider\n");
    return false;
  }
  
  if (!(fakeSMC = waitForService(serviceMatching(kFakeSMCDeviceService)))) {
    //		WarningLog("Can't locate fake SMC device, kext will not load");
		return false;
  }
  
  i2cNub->retain();
  i2cNub->open(this);
  
  for (i = 0; i < NUM_SENSORS; i++) {
    if (!i2cNub->ReadI2CBus(DIMMaddr + i, &(cmd = DIMM_VID), sizeof(cmd), &data, sizeof(data))) {
      IOPrint("found DIMM VID %x\n", data);
      if ((data != 0) && (data != 0xFF)) {
        if(!i2cNub->ReadI2CBus(DIMMaddr + i, &(cmd = DIMM_DID), sizeof(cmd), &data, sizeof(data))) {
  //        Measures[i].present = true;
          memcpy(&Measures[i], &list, sizeof(struct MList));
          found = true;
          IOPrint("DIMM DID=0x%x attached at %d.\n", data, i);
        } else {
          Measures[i].present = false;
        }
      } 
    }
  }
  if (!found) {
    IOPrint("Device matching failed.\n");
    return false;
  }
/*
  if (fRoot) {
    vendor = OSDynamicCast(OSString, fRoot->getProperty("OEMVendor"));
    str = OSDynamicCast(OSString, fRoot->getProperty("OEMBoard"));
    if (!str) {
      str = OSDynamicCast(OSString, fRoot->getProperty("OEMProduct"));
    }
  }
  if (vendor)
    if (OSDictionary *link = OSDynamicCast(OSDictionary, sconf->getObject(vendor)))
      if(str)
        conf = OSDynamicCast(OSDictionary, link->getObject(str));
  if (sconf && !conf)
    conf = OSDynamicCast(OSDictionary, sconf->getObject("Active"));
*/  
  for (i = 0, s = 0; i < NUM_SENSORS; i++) {
    if (Measures[i].present) {
      Measures[i].hwsensor.key[2] = 0x30 + s;
    
      addSensor(Measures[i].hwsensor.key, Measures[i].hwsensor.type,
                Measures[i].hwsensor.size, s);
      s++;
    }
   }
    
  return true;
}

void TSOD::stop(IOService *provider)
{
  DbgPrint("stop\n");
  
  sensors->flushCollection();
  if (kIOReturnSuccess != fakeSMC->callPlatformFunction(kFakeSMCRemoveKeyHandler, true, this, NULL, NULL, NULL)) {
    IOLog("Can't remove key handler");
    IOSleep(500);
  }
  
  super::stop(provider);
}

/* Temp: update 'em all et once */
void TSOD::updateSensors()
{
	UInt8 hdata, ldata;
//  UInt16 data;
  
  i2cNub->LockI2CBus();
  
  for (int i = 0; i < NUM_SENSORS; i++) {
    /* Skip unused */
    if (!Measures[i].present)
      continue;
    hdata = 0;
    Measures[i].obsoleted = false;
    if (i2cNub->ReadI2CBus(DIMMaddr + i, &Measures[i].lreg, sizeof Measures[i].lreg, &ldata, sizeof ldata)) {
			Measures[i].value = 0;
			continue;
		}
    
      if (ldata == DIMM_TEMP_NA)
        Measures[i].value = 0;
      else {
        Measures[i].value = ((hdata << 8 | ldata)) >> 6;
        Measures[i].value = (float) Measures[i].value * 0.25f;
      }
  }
  
  i2cNub->UnlockI2CBus();
}

void TSOD::readSensor(int idx)
{
  if (Measures[idx].obsoleted)
    updateSensors();
  
  Measures[idx].obsoleted = true;
}

/* FakeSMC dependend methods */
bool TSOD::addSensor(const char* key, const char* type, unsigned int size, int index)
{
	if (kIOReturnSuccess == fakeSMC->callPlatformFunction(kFakeSMCAddKeyHandler, true, (void *)key,
                                                        (void *)type, (void *)(long long)size, (void *)this)) {
		if (sensors->setObject(key, OSNumber::withNumber(index, 32))) {
      return true;
    } else {
      IOPrint("%s key not set\n", key);
      return 0;
    }
  }
  
	IOPrint("%s key not added\n", key);
  
	return 0;
}


/* Exports for HWSensors3 */
IOReturn TSOD::callPlatformFunction(const OSSymbol *functionName, bool waitForFunction,
                                      void *param1, void *param2, void *param3, void *param4 )
{
  int i, idx = -1;
//  char fan = -1;
  
  if (functionName->isEqualTo(kFakeSMCGetValueCallback)) {
    const char* key = (const char*)param1;
		char * data = (char*)param2;
    
    if (key && data) {
      if (key[0] == 'T') {
        for (i = 0; i < NUM_SENSORS; i++)
          if (Measures[i].present) {
              idx = i; break;
          }
        
        if (idx > -1) {
          readSensor(idx);
          //      Measures[idx].value = Measures[idx].hwsensor->encodeValue(Measures[idx].value);
          Measures[idx].value = encode_fpe2(Measures[idx].value); //?
          memcpy(data, &Measures[idx].value, Measures[idx].hwsensor.size);
          return kIOReturnSuccess;
        }
      }
    }
    return kIOReturnBadArgument;
  }

  return super::callPlatformFunction(functionName, waitForFunction, param1, param2, param3, param4);
}
/* */
