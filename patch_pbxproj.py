with open("H2 Tuner.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# File reference with relative path from project root
fw_ref = '\t\tFW001 /* LibXray.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = "H2 Tuner/LibXray.xcframework"; sourceTree = "<group>"; };\n'
fw_build = '\t\tFW002 /* LibXray.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = FW001 /* LibXray.xcframework */; };\n'
sw_ref = '\t\tSW001 /* ToolkitView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ToolkitView.swift; sourceTree = "<group>"; };\n'
sw_build = '\t\tSW002 /* ToolkitView.swift in Sources */ = {isa = PBXBuildFile; fileRef = SW001 /* ToolkitView.swift */; };\n'

if 'FW001' not in content:
    content = content.replace('/* End PBXFileReference section */', fw_ref + sw_ref + '/* End PBXFileReference section */')
if 'FW002' not in content:
    content = content.replace('/* End PBXBuildFile section */', fw_build + sw_build + '/* End PBXBuildFile section */')

# Add to H2 Tuner group
if 'FW001' not in content.split('path = "H2 Tuner"')[0]:
    content = content.replace(
        'A015,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";',
        'A015,\n\t\t\t\tFW001,\n\t\t\t\tSW001,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";'
    )

# Frameworks build phase
if 'PH_FRAMEWORKS' not in content:
    fw_phase = '\t\tPH_FRAMEWORKS = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (FW002);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n'
    content = content.replace('/* Begin PBXSourcesBuildPhase section */', fw_phase + '/* Begin PBXSourcesBuildPhase section */')
    content = content.replace(
        'buildPhases = (\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);',
        'buildPhases = (\n\t\t\t\tPH_FRAMEWORKS,\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);'
    )

# Add ToolkitView to sources
if 'SW002' not in content:
    content = content.replace(
        'B013,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase',
        'B013,\n\t\t\t\tSW002,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase'
    )

# Bridging header
bridge = '\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "H2 Tuner/H2Tuner-Bridging-Header.h";\n'
if 'SWIFT_OBJC_BRIDGING_HEADER' not in content:
    content = content.replace(
        '\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t};\n\t\t\tname = Release;',
        '\t\t\t\tSWIFT_VERSION = 5.0;\n' + bridge + '\t\t\t};\n\t\t\tname = Release;'
    )

with open("H2 Tuner.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print("pbxproj patched OK")
