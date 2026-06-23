#!/usr/bin/env python3
"""
Generate ClashDash.xcodeproj/project.pbxproj.
Uses the same structure as the working authenticator project.
"""
import os

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_ROOT = os.path.join(PROJECT_DIR, "ClashDash")
XCODEPROJ = os.path.join(PROJECT_DIR, "ClashDash.xcodeproj")
PROJECT_NAME = "ClashDash"
BUNDLE_ID = "com.clashdash.app"
TEAM_ID = "ZJB59HBZGC"

# Files grouped by directory (relative to SRC_ROOT)
FILES = {
    "App": ["ClashDashApp.swift"],
    "Models": [
        "ConnectionInfo.swift",
        "ConnectionSnapshot.swift",
        "ProxyGroup.swift",
        "ProxyNode.swift",
        "ProxyProvider.swift",
        "RuleItem.swift",
        "ServerConfig.swift",
        "TrafficInfo.swift",
    ],
    "Views": [
        "ContentView.swift",
        "DebugLogView.swift",
    ],
    "Views/Overview": [
        "OverviewView.swift",
    ],
    "Views/Proxies": [
        "ProxiesView.swift",
    ],
    "Views/Rules": [
        "RulesView.swift",
    ],
    "Views/Connections": [
        "ConnectionsView.swift",
    ],
    "Views/Settings": [
        "AddServerView.swift",
        "SettingsView.swift",
        "WelcomeView.swift",
    ],
    "ViewModels": [
        "ConnectionsViewModel.swift",
        "OverviewViewModel.swift",
        "ProxiesViewModel.swift",
        "RulesViewModel.swift",
        "SettingsViewModel.swift",
    ],
    "Services": [
        "DebugLog.swift",
        "DebugServer.swift",
        "HapticService.swift",
        "MihomoAPIService.swift",
        "ServerConfigService.swift",
        "WebSocketService.swift",
    ],
    "Extensions": [
        "ColorExt.swift",
        "Formatters.swift",
    ],
}

def scan_and_validate():
    """Validate all files in FILES exist on disk."""
    all_files = []
    for dirname, names in FILES.items():
        for name in names:
            path = os.path.join(SRC_ROOT, dirname, name)
            if not os.path.exists(path):
                print(f"WARNING: {path} not found!")
            else:
                all_files.append((dirname, name))
    print(f"Found {len(all_files)} valid source files")
    return all_files

def make_bid(n):
    """Build file ID: A1A1..."""
    return f"A1A1A1A1A1A1A1A1A1A1{n:04d}"

def make_fid(n):
    """File ref ID: F1F1..."""
    return f"F1F1F1F1F1F1F1F1F1F1{n:04d}"

def make_gid(n):
    """Group ID: G1G1..."""
    return f"G1G1G1G1G1G1G1G1G1G1{n:04d}"

def generate(all_files):
    n = len(all_files)

    # Map each file to stable IDs
    file_bids = {}
    file_fids = {}
    for i, (d, name) in enumerate(all_files):
        file_bids[(d, name)] = make_bid(i + 1)
        file_fids[(d, name)] = make_fid(i + 1)

    # Build group hierarchy
    # dirname -> (gid, subdir_gids)
    # Groups needed: unique dirnames + intermediate paths
    all_dirs = sorted(set(d for d, _ in all_files))
    # Collect all path prefixes
    prefixes = set()
    for d in all_dirs:
        parts = d.split("/")
        for i in range(1, len(parts) + 1):
            prefixes.add("/".join(parts[:i]))
    prefixes = sorted(prefixes)

    group_ids = {}
    for i, p in enumerate(prefixes):
        group_ids[p] = make_gid(10 + i)

    root_gid = make_gid(1)
    src_gid = make_gid(2)
    prod_gid = make_gid(3)
    target_id = "T1T1T1T1T1T1T1T1T1T10001"
    project_id = "P1P1P1P1P1P1P1P1P1P10001"
    sources_bp_id = "B1B1B1B1B1B1B1B1B1B10001"
    resources_bp_id = "B1B1B1B1B1B1B1B1B1B10002"
    info_plist_fid = make_fid(n + 1)
    assets_fid = make_fid(n + 2)
    product_fid = make_fid(n + 3)
    assets_bid = make_bid(n + 1)

    cfg_list_proj = "C1C1C1C1C1C1C1C1C1C10001"
    cfg_list_target = "C1C1C1C1C1C1C1C1C1C10002"
    cfg_debug_proj = "CFG000000001"
    cfg_release_proj = "CFG000000002"
    cfg_debug_target = "CFG000000003"
    cfg_release_target = "CFG000000004"

    lines = []
    def w(s): lines.append(s)

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w("")

    # PBXBuildFile
    w("/* Begin PBXBuildFile section */")
    for (d, name), bid in file_bids.items():
        fid = file_fids[(d, name)]
        w(f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')
    w(f'\t\t{assets_bid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_fid} /* Assets.xcassets */; }};')
    w("/* End PBXBuildFile section */")
    w("")

    # PBXFileReference
    w("/* Begin PBXFileReference section */")
    for (d, name), fid in file_fids.items():
        w(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};')
    w(f'\t\t{info_plist_fid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    w(f'\t\t{assets_fid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
    w(f'\t\t{product_fid} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    w("/* End PBXFileReference section */")
    w("")

    # PBXGroup
    w("/* Begin PBXGroup section */")

    # Root
    w(f'\t\t{root_gid} = {{')
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f'\t\t\t\t{src_gid} /* {PROJECT_NAME} */,')
    w(f'\t\t\t\t{prod_gid} /* Products */,')
    w("\t\t\t);")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

    # Source root
    w(f'\t\t{src_gid} = {{')
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    # Top-level subdirectories
    top_dirs = sorted(set(p.split("/")[0] for p in prefixes if "/" not in p or p.count("/") == 0))
    for td in top_dirs:
        w(f'\t\t\t\t{group_ids[td]} /* {td} */,')
    # Info.plist & Assets at source root
    w(f'\t\t\t\t{info_plist_fid} /* Info.plist */,')
    w(f'\t\t\t\t{assets_fid} /* Assets.xcassets */,')
    w("\t\t\t);")
    w(f'\t\t\tpath = {PROJECT_NAME};')
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

    # Products
    w(f'\t\t{prod_gid} = {{')
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w(f'\t\t\t\t{product_fid} /* {PROJECT_NAME}.app */,')
    w("\t\t\t);")
    w("\t\t\tname = Products;")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

    # Subdirectory groups
    for p in prefixes:
        gid = group_ids[p]
        parts = p.split("/")
        name = parts[-1]

        # Children: subdirs + files
        children = []
        # Subdirectories (direct children only)
        for pp in prefixes:
            if pp != p and pp.startswith(p + "/") and pp.count("/") == p.count("/") + 1:
                children.append((group_ids[pp], pp.split("/")[-1]))
        # Files in this directory
        if p in FILES:
            for fname in sorted(FILES[p]):
                children.append((file_fids[(p, fname)], fname))

        w(f'\t\t{gid} = {{')
        w("\t\t\tisa = PBXGroup;")
        w("\t\t\tchildren = (")
        for cid, cname in children:
            w(f'\t\t\t\t{cid} /* {cname} */,')
        w("\t\t\t);")
        w(f'\t\t\tpath = {name};')
        w('\t\t\tsourceTree = "<group>";')
        w("\t\t};")

    w("/* End PBXGroup section */")
    w("")

    # PBXNativeTarget
    w("/* Begin PBXNativeTarget section */")
    w(f'\t\t{target_id} /* {PROJECT_NAME} */ = {{')
    w("\t\t\tisa = PBXNativeTarget;")
    w(f'\t\t\tbuildConfigurationList = {cfg_list_target} /* Build configuration list for PBXNativeTarget "{PROJECT_NAME}" */;')
    w("\t\t\tbuildPhases = (")
    w(f'\t\t\t\t{sources_bp_id} /* Sources */,')
    w(f'\t\t\t\t{resources_bp_id} /* Resources */,')
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w(f'\t\t\tname = {PROJECT_NAME};')
    w(f'\t\t\tproductName = {PROJECT_NAME};')
    w(f'\t\t\tproductReference = {product_fid} /* {PROJECT_NAME}.app */;')
    w('\t\t\tproductType = "com.apple.product-type.application";')
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w("")

    # PBXProject
    w("/* Begin PBXProject section */")
    w(f'\t\t{project_id} /* Project object */ = {{')
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 1620;")
    w("\t\t\t\tLastUpgradeCheck = 1620;")
    w("\t\t\t};")
    w(f'\t\t\tbuildConfigurationList = {cfg_list_proj} /* Build configuration list for PBXProject "{PROJECT_NAME}" */;')
    w('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w('\t\t\t\t"zh-Hans",')
    w("\t\t\t);")
    w(f'\t\t\tmainGroup = {root_gid};')
    w(f'\t\t\tproductRefGroup = {prod_gid} /* Products */;')
    w('\t\t\tprojectDirPath = "";')
    w('\t\t\tprojectRoot = "";')
    w("\t\t\ttargets = (")
    w(f'\t\t\t\t{target_id} /* {PROJECT_NAME} */,')
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w("")

    # PBXResourcesBuildPhase
    w("/* Begin PBXResourcesBuildPhase section */")
    w(f'\t\t{resources_bp_id} /* Resources */ = {{')
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w(f'\t\t\t\t{assets_bid} /* Assets.xcassets in Resources */,')
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w("")

    # PBXSourcesBuildPhase
    w("/* Begin PBXSourcesBuildPhase section */")
    w(f'\t\t{sources_bp_id} /* Sources */ = {{')
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for (d, name), bid in file_bids.items():
        w(f'\t\t\t\t{bid} /* {name} in Sources */,')
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w("")

    # XCBuildConfiguration
    w("/* Begin XCBuildConfiguration section */")

    # Project configs
    for (cid, cname, is_dbg) in [(cfg_debug_proj, "Debug", True), (cfg_release_proj, "Release", False)]:
        w(f'\t\t{cid} /* {cname} */ = {{')
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
        if is_dbg:
            w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
            w("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
            w('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";')
            w('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
        else:
            w("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
            w("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
            w("\t\t\t\tVALIDATE_PRODUCT = YES;")
        w("\t\t\t\tMTL_FAST_MATH = YES;")
        w("\t\t\t\tSDKROOT = iphoneos;")
        w("\t\t\t};")
        w(f'\t\t\tname = {cname};')
        w("\t\t};")

    # Target configs
    for (cid, cname) in [(cfg_debug_target, "Debug"), (cfg_release_target, "Release")]:
        w(f'\t\t{cid} /* {cname} */ = {{')
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        w("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        w("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        w(f'\t\t\t\tDEVELOPMENT_TEAM = {TEAM_ID};')
        w("\t\t\t\tENABLE_PREVIEWS = YES;")
        w("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
        w(f'\t\t\t\tINFOPLIST_FILE = {PROJECT_NAME}/Info.plist;')
        w(f'\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = {PROJECT_NAME};')
        w("\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;")
        w('\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";')
        w('\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";')
        w("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
        w('\t\t\t\t\t"$(inherited)",')
        w('\t\t\t\t\t"@executable_path/Frameworks",')
        w("\t\t\t\t);")
        w("\t\t\t\tMARKETING_VERSION = 1.0;")
        w(f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};')
        w('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
        w("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        w("\t\t\t\tSWIFT_VERSION = 5.0;")
        w('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
        w("\t\t\t};")
        w(f'\t\t\tname = {cname};')
        w("\t\t};")

    w("/* End XCBuildConfiguration section */")
    w("")

    # XCConfigurationList
    w("/* Begin XCConfigurationList section */")
    w(f'\t\t{cfg_list_proj} /* Build configuration list for PBXProject "{PROJECT_NAME}" */ = {{')
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f'\t\t\t\t{cfg_debug_proj} /* Debug */,')
    w(f'\t\t\t\t{cfg_release_proj} /* Release */,')
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")

    w(f'\t\t{cfg_list_target} /* Build configuration list for PBXNativeTarget "{PROJECT_NAME}" */ = {{')
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w(f'\t\t\t\t{cfg_debug_target} /* Debug */,')
    w(f'\t\t\t\t{cfg_release_target} /* Release */,')
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w("/* End XCConfigurationList section */")
    w("")

    w("\t};")
    w(f"\trootObject = {project_id} /* Project object */;")
    w("}")
    w("")

    return "\n".join(lines)

def main():
    all_files = scan_and_validate()
    content = generate(all_files)

    os.makedirs(XCODEPROJ, exist_ok=True)
    path = os.path.join(XCODEPROJ, "project.pbxproj")
    with open(path, "w") as f:
        f.write(content)
    print(f"Generated {path} with {len(all_files)} files")

    # Info.plist
    plist = os.path.join(SRC_ROOT, "Info.plist")
    os.makedirs(os.path.dirname(plist), exist_ok=True)
    with open(plist, "w") as f:
        f.write('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>UILaunchScreen</key>
\t<dict/>
\t<key>NSAppTransportSecurity</key>
\t<dict>
\t\t<key>NSAllowsArbitraryLoads</key>
\t\t<true/>
\t</dict>
</dict>
</plist>
''')

    # Assets.xcassets (empty)
    assets = os.path.join(SRC_ROOT, "Assets.xcassets")
    os.makedirs(assets, exist_ok=True)
    contents_json = os.path.join(assets, "Contents.json")
    if not os.path.exists(contents_json):
        import json
        with open(contents_json, "w") as f:
            json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    # Add a minimal AppIcon
    appicon = os.path.join(assets, "AppIcon.appiconset")
    if not os.path.exists(appicon):
        os.makedirs(appicon, exist_ok=True)
        with open(os.path.join(appicon, "Contents.json"), "w") as f:
            import json
            json.dump({
                "images": [],
                "info": {"author": "xcode", "version": 1}
            }, f, indent=2)

if __name__ == "__main__":
    main()
