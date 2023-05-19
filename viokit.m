#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPropertyList.h>
#include <Foundation/NSString.h>
#include <IOKit/IOTypes.h>
#include <stdio.h>

#if DEBUG == 1
#define NSLog(...) NSLog(@"[viokit] " __VA_ARGS__)
#else
#define NSLog(...)
#endif

// Helpers
NSDictionary *DATA_PLIST = nil;
NSDictionary *read_data_plist() {
  if (DATA_PLIST != nil) {
    return DATA_PLIST;
  }
  // Read data.plist from the current directory
  NSString *path = @"data.plist";
  NSData *data = [NSData dataWithContentsOfFile:path];
  if (!data) {
    // printf("Failed to read data.plist\n");
    // exit(-2);
    @throw [NSException exceptionWithName:@"Failed to read data.plist"
                                   reason:@"Failed to read data.plist"
                                 userInfo:nil];
    // return nil;
  }
  NSError *error;
  NSDictionary *plist =
      [NSPropertyListSerialization propertyListWithData:data
                                                options:NSPropertyListImmutable
                                                 format:NULL
                                                  error:&error];
  if (error) {
    // printf("Failed to parse data.plist oh no\n");
    // exit(-2);
    //  Throw an exception
    @throw [NSException exceptionWithName:@"Failed to parse data.plist"
                                   reason:@"Failed to parse data.plist"
                                 userInfo:nil];
  }
  DATA_PLIST = plist;
  return plist;
}

NSDictionary *get_iokit_data() {
  // Get the iokit key from read_data_plist
  NSDictionary *data_plist = read_data_plist();
  return [data_plist objectForKey:@"iokit"];
}

#define CFSTR_CMP(str1, str2) CFStringCompare(str1, str2, 0) == 0

CFDataRef data_from_cfstr(CFStringRef string) {
  CFIndex length = CFStringGetLength(string);
  CFIndex maxSize =
      CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
  char *buffer = (char *)malloc(maxSize);
  if (CFStringGetCString(string, buffer, maxSize, kCFStringEncodingUTF8)) {
    return CFDataCreate(NULL, (const UInt8 *)buffer, maxSize);
  } else {
    return NULL;
  }
}

// Stubs
mach_port_t kIOMasterPortDefault = 90;

io_registry_entry_t IORegistryEntryFromPath(mach_port_t masterPort,
                                            char *path) {
  NSLog(@"IORegistryEntryFromPath called with port %d path: %s\n", masterPort,
        path);
  return 91;
}

CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry,
                                          CFStringRef key,
                                          CFAllocatorRef allocator,
                                          IOOptionBits options) {
  // Convert the CFStringRef to a C string
  char key_c[100];
  CFStringGetCString(key, key_c, 100, kCFStringEncodingUTF8);
  NSLog(@"IORegistryEntryCreateCFProperty called with entry: %d key: %s\n",
        entry, key_c);

  NSDictionary *data_plist = get_iokit_data();
  // Convert the CFStringRef to a NSString
  NSString *key_ns = (__bridge_transfer NSString *)key;
  // Check if the key is in the dictionary
  if ([data_plist objectForKey:key_ns]) {
    // Get the value
    id value = [data_plist objectForKey:key_ns];
    // printf("value: %p\n", value);
    NSLog(@"Returning value: %@", value);
    // Check if it is a string
    if ([value isKindOfClass:[NSString class]]) {
      // printf("value is NSString\n");
      //  Convert the NSString to a CFStringRef
      CFStringRef value_cf = (__bridge_retained CFStringRef)value;
      return value_cf;
    } else if ([value isKindOfClass:[NSData class]]) {
      // printf("value is NSData\n");
      //  Convert the NSData to a CFDataRef
      CFDataRef value_cf = (__bridge_retained CFDataRef)value;
      // Make a copy of the CFDataRef so that we are not returning an ARC object
      CFDataRef value_cf_copy = CFDataCreateCopy(NULL, value_cf);
      // Return the CFDataRef
      return value_cf;
    } else {
      NSLog(@"value is not NSString or NSData, cannot convert to CFTypeRef");
      // Return NULL
      return NULL;
    }
  } else {
    NSLog(@"key not found in in iokit data");
    // Return NULL
    return NULL;
  }
}

CFMutableDictionaryRef IOServiceMatching(const char *name) {
  // printf("IOServiceMatching called with %s\n", name);
  //  return 0;
  //   Turn name into CFString
  CFStringRef name_cf =
      CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
  // Create a CFMutableDictionaryRef
  CFMutableDictionaryRef matching =
      CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                &kCFTypeDictionaryValueCallBacks);
  // Add the name to the dictionary
  CFDictionaryAddValue(matching, CFSTR("IOProviderClass"), name_cf);
  // Return the dictionary
  return matching;
}

io_service_t IOServiceGetMatchingService(mach_port_t masterPort,
                                         CFDictionaryRef matching) {
  // Get the IOProviderClass
  CFStringRef provider_class =
      CFDictionaryGetValue(matching, CFSTR("IOProviderClass"));

  // Check if it is 'IOPlatformExpertDevice'
  if (CFSTR_CMP(provider_class, CFSTR("IOPlatformExpertDevice"))) {
    return 92;
  }
  NSLog(@"IOServiceGetMatchingService returning 0");
  return 0;
}

bool ITER_93_SHOULD_RETURN_MAC = false;
kern_return_t IOServiceGetMatchingServices(mach_port_t masterPort,
                                           CFDictionaryRef matching,
                                           io_iterator_t *existing) {
  // printf("IOServiceGetMatchingServices called with port: %d matching: \n",
  //        masterPort);
  // CFShow(matching);
  if (CFSTR_CMP(CFDictionaryGetValue(matching, CFSTR("IOProviderClass")),
                CFSTR("IOEthernetInterface"))) {
    // printf("IOServiceGetMatchingServices returning 0\n");
    *existing = 93;
    ITER_93_SHOULD_RETURN_MAC = true;
    NSLog(@"IOServiceGetMatchingServices setting up 'iterator'");
    return 0;
  }
  NSLog(@"IOServiceGetMatchingServices returning -1");
  return -1;
}

io_object_t IOIteratorNext(io_iterator_t iterator) {
  // NSLog("IOIteratorNext\n");
  if (iterator == 93 && ITER_93_SHOULD_RETURN_MAC) {
    NSLog(@"IOIteratorNext returning 'item'");
    ITER_93_SHOULD_RETURN_MAC = false;
    return 94;
  }
  NSLog(@"IOIteratorNext returning 0");
  return 0;
}

void IOObjectRelease(io_object_t object) { /*printf("IOObjectRelease\n");*/
} // We don't care about memory managing our 'objects' lol

kern_return_t IORegistryEntryGetParentEntry(io_registry_entry_t entry,
                                            const io_name_t plane,
                                            io_registry_entry_t *parent) {
  NSLog(@"IORegistryEntryGetParentEntry called with entry: %d returning entry "
        @"+ 100",
        entry);
  // Set parent to entry + 100
  *parent = entry + 100;
  // printf("IORegistryEntryGetParentEntry returning 0\n");
  return 0;
}

// DISK ARBITRATION
// #import <DiskArbitration/DiskArbitration.h>

const CFStringRef kDADiskDescriptionVolumeUUIDKey =
    CFSTR("DADiskDescriptionVolumeUUIDKey");

CFNumberRef DASessionCreate(void *alloc) {
  NSLog(@"DASessionCreate");
  // Create a CFNumberRef
  // Create a CFNumberRef from 201
  int value = 201;
  CFNumberRef value_cf = CFNumberCreate(NULL, kCFNumberIntType, &value);
  return value_cf;
  // return 201;
}

CFNumberRef DADiskCreateFromBSDName(CFAllocatorRef allocator,
                                    CFNumberRef session, const char *name) {
  NSLog(@"DADiskCreateFromBSDName session: %@ name: %s", session, name);
  // return 202;
  int value = 202;
  CFNumberRef value_cf = CFNumberCreate(NULL, kCFNumberIntType, &value);
  return value_cf;
}

// DADiskCopyDescription(DADiskRef  _Nonnull disk)
CFDictionaryRef DADiskCopyDescription(CFNumberRef disk) {
  NSLog(@"DADiskCopyDescription called with disk: %@\n", disk);
  // Create a CFMutableDictionaryRef
  CFMutableDictionaryRef dict =
      CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                &kCFTypeDictionaryValueCallBacks);
  // printf("dict: %p\n", dict);
  //  Add the UUID to the dictionary
  //  Load the UUID from data.plist
  NSDictionary *data_plist = read_data_plist();
  // printf("data_plist: %p\n", data_plist);
  //  Get root_disk_uuid
  NSString *root_disk_uuid = [data_plist objectForKey:@"root_disk_uuid"];
  // Convert the NSString to a CFStringRef
  CFStringRef root_disk_uuid_cf = (__bridge_retained CFStringRef)root_disk_uuid;
  // Convert it to a CFUUIDRef
  CFUUIDRef root_disk_uuid_cfuuid =
      CFUUIDCreateFromString(NULL, root_disk_uuid_cf);
  // printf("root_disk_uuid_cf: %p\n", root_disk_uuid_cf);
  //  Add the UUID to the dictionary
  CFDictionaryAddValue(dict, kDADiskDescriptionVolumeUUIDKey,
                       root_disk_uuid_cfuuid);
  // printf("dict: %p\n", dict);
  //  Make a copy of the CFDictionaryRef so that we are not returning an ARC
  //  object
  // CFDictionaryRef dict_copy = CFDictionaryCreateCopy(NULL, dict);
  // printf("dict_copy: %p\n", dict_copy);
  //  Return the dictionary
  return dict;
}

// sysctlbyname needs to be stubbed for Darling...

int sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp,
                      size_t newlen) {
  NSLog(@"sysctlbyname_hook called with name: %s", name);
  // If it's kern.osversion
  if (strcmp(name, "kern.osversion")) {
    // Write string 22E261 to oldp
    *oldlenp = 6;
    if (oldp != NULL) {
      strcpy(oldp, "22E261");
    }

    // Return 0
    return 0;
  } else if (strcmp(name, "kern.osrevision")) {
    // Write number 199506 to oldp
    *oldlenp = 4;
    if (oldp != NULL) {
      unsigned long n = 199506;

      ((unsigned char *)oldp)[0] = (n >> 24) & 0xFF;
      ((unsigned char *)oldp)[1] = (n >> 16) & 0xFF;
      ((unsigned char *)oldp)[2] = (n >> 8) & 0xFF;
      ((unsigned char *)oldp)[3] = n & 0xFF;
    }

    return 0;
  }

  return ENOENT;
}