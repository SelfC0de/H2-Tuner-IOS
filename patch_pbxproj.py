import sys

with open("H2 Tuner.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

fw_ref = '\t\tFW001 /* LibXray.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = LibXray.xcframework; sourceTree = "<group>"; };\n'
fw_build = '\t\tFW002 /* LibXray.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = FW001 /* LibXray.xcframework */; };\n'

content = content.replace('/* End PBXFileReference section */', fw_ref + '/* End PBXFileReference section */')
content = content.replace('/* End PBXBuildFile section */', fw_build + '/* End PBXBuildFile section */')
content = content.replace('A015,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";', 'A015,\n\t\t\t\tFW001,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";')

fw_phase = '\t\tPH_FRAMEWORKS = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (FW002);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n'
content = content.replace('/* Begin PBXSourcesBuildPhase section */', fw_phase + '/* Begin PBXSourcesBuildPhase section */')
content = content.replace(
    'buildPhases = (\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);',
    'buildPhases = (\n\t\t\t\tPH_FRAMEWORKS,\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);'
)

bridge = '\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "H2 Tuner/H2Tuner-Bridging-Header.h";\n'
content = content.replace(
    '\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t};\n\t\t\tname = Release;',
    '\t\t\t\tSWIFT_VERSION = 5.0;\n' + bridge + '\t\t\t};\n\t\t\tname = Release;'
)

with open("H2 Tuner.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print("pbxproj patched OK")
