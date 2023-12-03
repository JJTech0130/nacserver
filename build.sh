set -e
xcrun clang ./extractor.m -o extractor -framework Foundation -fobjc-arc -framework DiskArbitration -framework IOKit -Wno-deprecated-declarations
./extractor
