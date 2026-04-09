with open("H2 Tuner.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# 1. File references
if 'FW001' not in content:
    content = content.replace(
        '/* End PBXFileReference section */',
        '\t\tFW001 /* LibXray.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = "H2 Tuner/LibXray.xcframework"; sourceTree = "<group>"; };\n'
        '/* End PBXFileReference section */'
    )

# 2. Build files
if 'FW002' not in content:
    content = content.replace(
        '/* End PBXBuildFile section */',
        '\t\tFW002 /* LibXray.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = FW001 /* LibXray.xcframework */; };\n'
        '/* End PBXBuildFile section */'
    )

# 3. Add LibXray to group
if 'FW001' not in content.split('path = "H2 Tuner"')[0]:
    content = content.replace(
        'A016,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";',
        'A016,\n\t\t\t\tFW001,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";'
    )

# 4. Frameworks build phase with LibXray + libresolv
if 'PH_FRAMEWORKS' not in content:
    content = content.replace(
        '/* Begin PBXSourcesBuildPhase section */',
        '/* Begin PBXFrameworksBuildPhase section */\n'
        '\t\tPH_FRAMEWORKS = {\n'
        '\t\t\tisa = PBXFrameworksBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (FW002, LR001);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n'
        '/* End PBXFrameworksBuildPhase section */\n\n'
        '/* Begin PBXSourcesBuildPhase section */'
    )
    content = content.replace(
        'buildPhases = (\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);',
        'buildPhases = (\n\t\t\t\tPH_FRAMEWORKS,\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);'
    )

# 5. Bridging header
if 'SWIFT_OBJC_BRIDGING_HEADER' not in content:
    content = content.replace(
        '\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t};\n\t\t\tname = Release;',
        '\t\t\t\tSWIFT_VERSION = 5.0;\n'
        '\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "H2 Tuner/H2Tuner-Bridging-Header.h";\n'
        '\t\t\t};\n\t\t\tname = Release;'
    )

with open("H2 Tuner.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print("pbxproj patched OK")
