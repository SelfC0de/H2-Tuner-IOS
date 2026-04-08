import sys, os

with open("H2 Tuner.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# --- File references ---
new_refs = ""
files_to_add = [
    ("FW001", "LibXray.xcframework", "wrapper.xcframework"),
    ("SW001", "ToolkitView.swift",   "sourcecode.swift"),
]
for fid, fname, ftype in files_to_add:
    if fid not in content:
        new_refs += f'\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {fname}; sourceTree = "<group>"; }};\n'

if new_refs:
    content = content.replace(
        '/* End PBXFileReference section */',
        new_refs + '/* End PBXFileReference section */'
    )

# --- Build files ---
new_builds = ""
build_entries = [
    ("FW002", "FW001", "LibXray.xcframework"),
    ("SW002", "SW001", "ToolkitView.swift"),
]
for bid, fid, fname in build_entries:
    if bid not in content:
        new_builds += f'\t\t{bid} /* {fname} */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};\n'

if new_builds:
    content = content.replace(
        '/* End PBXBuildFile section */',
        new_builds + '/* End PBXBuildFile section */'
    )

# --- Add to group ---
if "FW001" not in content.split("path = \"H2 Tuner\"")[0] if "path = \"H2 Tuner\"" in content else True:
    content = content.replace(
        'A015,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";',
        'A015,\n\t\t\t\tFW001,\n\t\t\t\tSW001,\n\t\t\t);\n\t\t\tpath = "H2 Tuner";'
    )

# --- Frameworks build phase ---
if "PH_FRAMEWORKS" not in content:
    fw_phase = '\t\tPH_FRAMEWORKS = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (FW002);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n'
    content = content.replace(
        '/* Begin PBXSourcesBuildPhase section */',
        fw_phase + '/* Begin PBXSourcesBuildPhase section */'
    )

# --- Add ToolkitView to sources build phase ---
if "SW002" not in content:
    content = content.replace(
        'B013,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase',
        'B013,\n\t\t\t\tSW002,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase'
    )

# --- Add frameworks phase to target ---
if "PH_FRAMEWORKS" not in content.split("buildPhases")[1][:200] if "buildPhases" in content else True:
    content = content.replace(
        'buildPhases = (\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);',
        'buildPhases = (\n\t\t\t\tPH_FRAMEWORKS,\n\t\t\t\tPH_SOURCES,\n\t\t\t\tPH_RESOURCES,\n\t\t\t);'
    )

# --- Bridging header ---
bridge = '\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "H2 Tuner/H2Tuner-Bridging-Header.h";\n'
if 'SWIFT_OBJC_BRIDGING_HEADER' not in content:
    content = content.replace(
        '\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t};\n\t\t\tname = Release;',
        '\t\t\t\tSWIFT_VERSION = 5.0;\n' + bridge + '\t\t\t};\n\t\t\tname = Release;'
    )

with open("H2 Tuner.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print("pbxproj patched OK — LibXray.xcframework + ToolkitView.swift added")
