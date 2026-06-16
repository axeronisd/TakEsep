import sys

file_path = 'c:/Project TakEsep/TakEsep/apps/warehouse/ios/Runner.xcodeproj/project.pbxproj'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
in_build_settings = False
in_pbxgroup = False
added_file_ref = False

for line in lines:
    # Add CODE_SIGN_ENTITLEMENTS to build settings
    if 'buildSettings = {' in line:
        new_lines.append(line)
        in_build_settings = True
        continue
        
    if in_build_settings and 'CODE_SIGN_ENTITLEMENTS' not in line:
        # Check if we are ending the build settings block
        if '};' in line:
            new_lines.append('\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n')
            in_build_settings = False
            
    # Add file reference
    if '/* End PBXFileReference section */' in line and not added_file_ref:
        new_lines.append('\t\t111111111111111111111111 /* Runner.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; };\n')
        added_file_ref = True
        
    # Add to Runner group
    if '/* Runner */ = {' in line:
        new_lines.append(line)
        in_pbxgroup = True
        continue
        
    if in_pbxgroup:
        if 'isa = PBXGroup;' in line:
            new_lines.append(line)
            continue
        elif 'children = (' in line:
            new_lines.append(line)
            new_lines.append('\t\t\t\t111111111111111111111111 /* Runner.entitlements */,\n')
            in_pbxgroup = False
            continue
        elif 'isa =' in line:
            # Not a PBXGroup
            in_pbxgroup = False
            new_lines.append(line)
            continue

    if not in_pbxgroup:
        new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Patch applied successfully.")
