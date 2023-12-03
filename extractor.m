// Tool to extract IOKit data from a running machine and save it to a plist
//
// Usage: ./extractor <plist file>

#include <Foundation/Foundation.h>
#include <IOKit/IOKitLib.h>

// Uses NSURL to get the root disk UUID
// Why were we using DiskArbitration anyway?
NSString *get_root_disk_uuid() {
  NSURL *pathUrl = [NSURL fileURLWithPath:@"/"];
  NSString *volumeUUID = nil;
  NSError *error = nil;
  BOOL success = [pathUrl getResourceValue:&volumeUUID
                                    forKey:NSURLVolumeUUIDStringKey
                                     error:&error];

  if (!success) {
    NSLog(@"Error getting volume UUID: %@", error);
    return nil;
  } else {
    return volumeUUID;
  }
}

// Gets the derived obfuscated iMessage keys from IOKit
// What are these for?
#define G_NAME "Gq3489ugfi"
#define F_NAME "Fyp98tpgj"
#define K_NAME "kbjfrfpoJU"
#define O_NAME "oycqAZloTNDm"
#define A_NAME "abKPld1EcMni"
NSDictionary *get_imessage_keys() {
  io_service_t power_service =
      IORegistryEntryFromPath(kIOMasterPortDefault, "IOPower:/");

  return @{
    @G_NAME : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        power_service, CFSTR(G_NAME), kCFAllocatorDefault, 0),
    @F_NAME : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        power_service, CFSTR(F_NAME), kCFAllocatorDefault, 0),
    @K_NAME : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        power_service, CFSTR(K_NAME), kCFAllocatorDefault, 0),
    @O_NAME : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        power_service, CFSTR(O_NAME), kCFAllocatorDefault, 0),
    @A_NAME : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        power_service, CFSTR(A_NAME), kCFAllocatorDefault, 0),
  };
}

// Gets the MAC address of the primary ethernet interface
// This might not work properly if you have multiple internal ethernet
// interfaces
NSData *get_mac_address() {
  // Contruct a filter for IOEthernetInterface
  CFMutableDictionaryRef filter = IOServiceMatching("IOEthernetInterface");
  // Add a key to the filter for IOPrimaryInterface = 1
  CFMutableDictionaryRef property_match =
      CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                &kCFTypeDictionaryValueCallBacks);
  CFDictionaryAddValue(property_match, CFSTR("IOPrimaryInterface"),
                       kCFBooleanTrue);
  CFDictionaryAddValue(filter, CFSTR("IOPropertyMatch"), property_match);

  // Get a list of ethernet services that match the filter
  io_iterator_t ethernet_services_iter;
  IOServiceGetMatchingServices(kIOMasterPortDefault, filter,
                               &ethernet_services_iter);
  // Get the first ethernet service
  io_service_t ethernet_service = IOIteratorNext(ethernet_services_iter);
  // Get the parent of the ethernet service
  io_service_t ethernet_service_parent;
  IORegistryEntryGetParentEntry(ethernet_service, kIOServicePlane,
                                &ethernet_service_parent);
  // Get the MAC address
  return (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
      ethernet_service_parent, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);
}

// Gets the board id, product name, IOPlatformSerialNumber and IOPlatformUUID
// from IOKit
NSDictionary *get_device_info() {
  io_service_t device_tree_service =
      IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/");

  return @{
    @"board-id" : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        device_tree_service, CFSTR("board-id"), kCFAllocatorDefault, 0),
    @"product-name" :
        (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
            device_tree_service, CFSTR("product-name"), kCFAllocatorDefault, 0),
    @"IOPlatformUUID" :
        (__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(
            device_tree_service, CFSTR("IOPlatformUUID"), kCFAllocatorDefault,
            0),
    @"IOPlatformSerialNumber" :
        (__bridge_transfer NSString *)IORegistryEntryCreateCFProperty(
            device_tree_service, CFSTR("IOPlatformSerialNumber"),
            kCFAllocatorDefault, 0),
  };
}

// Gets the MLB and ROM from IOKit using the special NVRAM keys
#define ROM_KEY "4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:ROM"
#define MLB_KEY "4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:MLB"
NSDictionary *get_nvram_info() {
  io_service_t options_service =
      IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/options");

  return @{
    @ROM_KEY : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        options_service, CFSTR(ROM_KEY), kCFAllocatorDefault, 0),
    @MLB_KEY : (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(
        options_service, CFSTR(MLB_KEY), kCFAllocatorDefault, 0),
  };
}

int main(int argc, const char *argv[]) {
  NSMutableDictionary *iokit_data = [[NSMutableDictionary alloc] init];

  @try {
    [iokit_data addEntriesFromDictionary:get_imessage_keys()];
  } @catch (NSException *exception) {
    NSLog(@"Failed to get iMessage keys: %@", exception);
  } 
  
  @try {
    [iokit_data addEntriesFromDictionary:get_device_info()];
  } @catch (NSException *exception) {
    NSLog(@"Failed to get device info: %@", exception);
  }

  @try {
    [iokit_data addEntriesFromDictionary:get_nvram_info()];
  } @catch (NSException *exception) {
    NSLog(@"Failed to get NVRAM info: %@", exception);
  }

  @try {
    [iokit_data setObject:get_mac_address() forKey:@"IOMACAddress"];
  } @catch (NSException *exception) {
    NSLog(@"Failed to get MAC address: %@", exception);
  }

  NSMutableDictionary *data = [[NSMutableDictionary alloc] init];

  [data setObject:iokit_data forKey:@"iokit"];
  [data setObject:get_root_disk_uuid() forKey:@"root_disk_uuid"];

  NSLog(@"data: %@", data);

  // Write the data to a plist
  NSString *plist_path = @"data.plist";
  if (argc > 1) {
    plist_path = [NSString stringWithUTF8String:argv[1]];
  }
  [data writeToFile:plist_path atomically:YES];
}
