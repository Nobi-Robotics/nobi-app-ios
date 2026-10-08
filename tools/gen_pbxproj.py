#!/usr/bin/env python3
"""Regenerates the file/group/build-phase sections of Nobi.xcodeproj/project.pbxproj
from the files on disk, keeping the project, target and build settings exactly as they are.
Usage: python3 gen_pbxproj.py <project root containing Nobi/ and Nobi.xcodeproj/>"""
import hashlib, os, re, sys

root = sys.argv[1]
src_root = os.path.join(root, 'Nobi')
pbx_path = os.path.join(root, 'Nobi.xcodeproj', 'project.pbxproj')
text = open(pbx_path).read()

def oid(key):
    return hashlib.md5(('nobi:' + key).encode()).hexdigest()[:24].upper()

TARGET = re.search(r'(\w{24}) /\* Nobi \*/ = \{\s*isa = PBXNativeTarget;', text).group(1)
PRODUCT = re.search(r'(\w{24}) /\* Nobi\.app \*/ = \{isa = PBXFileReference;', text).group(1)
MAIN_GROUP = re.search(r'mainGroup = (\w{24});', text).group(1)
PRODUCTS_GROUP = re.search(r'productRefGroup = (\w{24})', text).group(1)

# ---- collect files
entries = []  # (relpath, kind)
for dirpath, dirnames, filenames in os.walk(src_root):
    dirnames[:] = sorted(d for d in dirnames if not d.startswith('.'))
    rel_dir = os.path.relpath(dirpath, src_root)
    if rel_dir.endswith('.xcassets') or '.xcassets' + os.sep in rel_dir + os.sep:
        continue
    for d in list(dirnames):
        if d.endswith('.xcassets'):
            entries.append((os.path.normpath(os.path.join(rel_dir, d)), 'assets'))
    for f in sorted(filenames):
        if f.startswith('.'):
            continue
        rel = os.path.normpath(os.path.join(rel_dir, f))
        if f.endswith('.swift'):
            entries.append((rel, 'swift'))
        elif f.endswith('.ttf'):
            entries.append((rel, 'font'))
        elif f.endswith('.plist'):
            entries.append((rel, 'plist'))
        elif f.endswith('.entitlements'):
            entries.append((rel, 'entitlements'))
entries.sort()

FTYPE = {
    'swift': 'sourcecode.swift', 'font': 'file', 'plist': 'text.plist',
    'entitlements': 'text.plist.entitlements', 'assets': 'folder.assetcatalog',
}

# ---- sections
build_files, file_refs, sources, resources = [], [], [], []
for rel, kind in entries:
    name = os.path.basename(rel)
    ref = oid('ref:' + rel)
    file_refs.append(f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {FTYPE[kind]}; path = "{name}"; sourceTree = "<group>"; }};')
    if kind == 'swift':
        bf = oid('src:' + rel)
        build_files.append(f'\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};')
        sources.append(f'\t\t\t\t{bf} /* {name} in Sources */,')
    elif kind in ('font', 'assets'):
        bf = oid('res:' + rel)
        build_files.append(f'\t\t{bf} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};')
        resources.append(f'\t\t\t\t{bf} /* {name} in Resources */,')
file_refs.append(f'\t\t{PRODUCT} /* Nobi.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Nobi.app; sourceTree = BUILT_PRODUCTS_DIR; }};')

# groups
tree = {}
for rel, kind in entries:
    parts = rel.split(os.sep)
    node = tree
    for p in parts[:-1]:
        node = node.setdefault(p, {})
    node.setdefault('__files__', []).append(rel)

groups = []
def emit_group(path, name, node, gid):
    children = []
    for k in sorted(k for k in node if k != '__files__'):
        sub = os.path.join(path, k) if path else k
        cid = oid('grp:' + sub)
        emit_group(sub, k, node[k], cid)
        children.append(f'\t\t\t\t{cid} /* {k} */,')
    for rel in node.get('__files__', []):
        children.append(f'\t\t\t\t{oid("ref:" + rel)} /* {os.path.basename(rel)} */,')
    groups.append(f'\t\t{gid} /* {name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n' + '\n'.join(children) +
                  f'\n\t\t\t);\n\t\t\tpath = "{name}";\n\t\t\tsourceTree = "<group>";\n\t\t}};')

SRC_GROUP = oid('grp:Nobi-root')
emit_group('', 'Nobi', tree, SRC_GROUP)
groups.append(f'\t\t{MAIN_GROUP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{SRC_GROUP} /* Nobi */,\n\t\t\t\t{PRODUCTS_GROUP} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t}};')
groups.append(f'\t\t{PRODUCTS_GROUP} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{PRODUCT} /* Nobi.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t}};')

SOURCES_PHASE = re.search(r'(\w{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;', text).group(1)
RES_PHASE = oid('phase:resources')

def replace_section(t, name, body):
    pat = re.compile(r'/\* Begin ' + name + r' section \*/\n.*?/\* End ' + name + r' section \*/\n', re.S)
    new = f'/* Begin {name} section */\n' + body + f'\n/* End {name} section */\n'
    if pat.search(t):
        return pat.sub(lambda m: new, t)
    # insert before the sources phase section
    anchor = '/* Begin PBXSourcesBuildPhase section */'
    return t.replace(anchor, new + '\n' + anchor)

text = replace_section(text, 'PBXBuildFile', '\n'.join(sorted(build_files)))
text = replace_section(text, 'PBXFileReference', '\n'.join(sorted(file_refs)))
text = replace_section(text, 'PBXGroup', '\n'.join(groups))
text = replace_section(text, 'PBXSourcesBuildPhase',
    f'\t\t{SOURCES_PHASE} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n'
    + '\n'.join(sources) + '\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};')
text = replace_section(text, 'PBXResourcesBuildPhase',
    f'\t\t{RES_PHASE} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n'
    + '\n'.join(resources) + '\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};')

# make sure the target runs the resources phase
text = re.sub(r'(buildPhases = \(\n\s*' + SOURCES_PHASE + r' /\* Sources \*/,\n)(?!\s*' + RES_PHASE + ')',
              lambda m: m.group(1) + f'\t\t\t\t{RES_PHASE} /* Resources */,\n', text)

open(pbx_path, 'w').write(text)
print(f'{len(sources)} sources, {len(resources)} resources, {len(groups)} groups')
