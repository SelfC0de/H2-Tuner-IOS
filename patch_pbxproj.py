with open("H2 Tuner.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# 1. File references
if 'FW001' not in content:
    content = content.replace(
        '/* End PBXFileReference section */',
        '\t\tFW001 /* LibXray.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = "H2 Tuner/LibXray.xcframework"; sourceTree = "<group>"; };\n'
        '\t\tSW001 /* ToolkitView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ToolkitView.swift; sourceTree = "<group>"; };\n'
        '/* End PBXFileReference section */'
    )

# 2. Build files
if 'FW002' not in content:
    content = content.replace(
        '/* End PBXBuildFile section */',
        '\t\tFW002 /* LibXray.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = FW001 /* LibXray.xcframework */; };\n'
        '\t\tSW002 /* ToolkitView.swift in Sources */ = {isa = PBXBuildFile; fileRef = SW001 /* ToolkitView.swift */; };\n'
        '/* End PBXBuildFile section */'
    )

# 3. Add to group
if 'FW001' not in content.split('path = "H2 Tuner"')[0]:
    content = content.replace(
        'A015,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";',
        'A015,\n\t\t\t\tFW001,\n\t\t\t\tSW001,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";'
    )

# 4. Frameworks build phase
if 'PH_FRAMEWORKS' not in content:
    content = content.replace(
        '/* Begin PBXSourcesBuildPhase section */',
        '/* Begin PBXFrameworksBuildPhase section */\n'
        '\t\tPH_FRAMEWORKS = {\n'
        '\t\t\tisa = PBXFrameworksBuildPhase;\n'
        '\t\t\tbuildActionMask = 2147483647;\n'
        '\t\t\tfiles = (FW002);\n'
        '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        '\t\t};\n'
        '/* End PBXFrameworksBuildPhase section */\n\n'
        '/* Begin PBXSourcesBuildPhase section */'
    )

# 5. Add ToolkitView to sources — exact match from pbxproj
if 'SW002' not in content:
    content = content.replace(
        '\t\t\t\tB011, B012, B013,\n',
        '\t\t\t\tB011, B012, B013, SW002,\n'
    )

# 6. Add PH_FRAMEWORKS to target build phases
if 'PH_FRAMEWORKS' not in content.split('buildPhases')[1][:300]:
    content = content.replace(
        'buildPhases = (\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);',
        'buildPhases = (\n\t\t\t\tPH_FRAMEWORKS,\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);'
    )

# 7. Bridging header
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
