import lief

STUB_IOKIT = True
STUB_DSKARB = True
OUTPUT = "IMDAppleServices.stubbed"

lib = lief.parse("IMDAppleServices")

# Write information about the binary to IMDAppleServices.h
# with open("IMDAppleServices.h", "w") as f:
#     f.write("// This file was autogenerated by stubber.py: DO NOT MODIFY\n")
#     f.write(f"#define IMD_PATH \"{OUTPUT}\"\n")
#     f.write(f"#define IMD_REF_SYM \"{lib.symbols[1].name[1:]}\"\n")
#     f.write(f"#define IMD_REF_ADDR 0x{lib.symbols[1].value:08X}\n")

REMOVING = [
    #"/System/Library/Frameworks/DiskArbitration.framework/Versions/A/DiskArbitration", # Necessary for calling NACInit
    #"/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", # Necessary for calling NACInit
    "/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation",
    "/System/Library/Frameworks/SecurityFoundation.framework/Versions/A/SecurityFoundation",
    #"/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation",
    #"/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
    "/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices",
    "/System/Library/Frameworks/SystemConfiguration.framework/Versions/A/SystemConfiguration",
    "/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices",
    "/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco",
    "/System/Library/Frameworks/Security.framework/Versions/A/Security",
    "/System/Library/PrivateFrameworks/MessageProtection.framework/Versions/A/MessageProtection",
    "/System/Library/PrivateFrameworks/ApplePushService.framework/Versions/A/ApplePushService",
    "/System/Library/PrivateFrameworks/IMDaemonCore.framework/Versions/A/IMDaemonCore",
]

STUB_LIST = []
IO_ORDINAL = 0
for sym in lib.symbols:
    name = sym.name[1:]
    if sym.binding_info:
        if sym.binding_info.library.name in REMOVING:
            STUB_LIST.append(name)
        # We move the sysctlbyname stub to IOKit so that we don't have to stub all of libSystem
        if sym.binding_info.library.name == "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit":
            IO_ORDINAL = sym.binding_info.library_ordinal
        if name == "sysctlbyname":
            print(f"Moving sysctlbyname stub from {sym.binding_info.library_ordinal} to {IO_ORDINAL}" )
            sym.binding_info.library_ordinal = IO_ORDINAL
        
for cmd in lib.commands:
    # Check if it is a LOAD_DYLIB command
    if (cmd.command == lief.MachO.LOAD_COMMAND_TYPES.LOAD_DYLIB):
        # Check if we are supposed to remove it
        if cmd.name in REMOVING:
            cmd.name = "STUB" + ("\0" * (len(cmd.name) - 4))
            cmd.compatibility_version = [0, 0, 0]
        # Special stubs for IOKit
        #if cmd.name == "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit": #or cmd.name == "/System/Library/Frameworks/DiskArbitration.framework/Versions/A/DiskArbitration":
        #if cmd.name == "/System/Library/Frameworks/DiskArbitration.framework/Versions/A/DiskArbitration":
        if (STUB_IOKIT and cmd.name == "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit") or (STUB_DSKARB and cmd.name == "/System/Library/Frameworks/DiskArbitration.framework/Versions/A/DiskArbitration"):
            print("IOKit/DA stub cmd", cmd.name)
            cmd.name = "VIOKit" + ("\0" * (len(cmd.name) - 6))
            cmd.compatibility_version = [0, 0, 0]
            

with open("stubs.m", "w") as f:
    # Write the header
    f.write("// This file was autogenerated by stubber.py: DO NOT MODIFY\n")
    f.write("#include <stdio.h>\n")
    f.write("@interface NSObject\n@end\n")
    # Write the stubs
    for stub in STUB_LIST:
        # If it's an Objective C class, we need to declare it
        if "OBJC_CLASS_$_" in stub:
            clsname = stub.replace("OBJC_CLASS_$_", "")
            f.write(f"@interface {clsname} : NSObject\n@end\n")
            f.write(f"@implementation {clsname}\n@end\n")
        elif "OBJC_METACLASS_$_" in stub:
            print("Skipping metaclass stub")
        else:
            # Create a stub for each symbol containing a call to printf with the symbol name
            f.write(f"void {stub}() {{ printf(\"{stub}\\n\"); }}\n")

# Write the new binary
lib.write(OUTPUT)