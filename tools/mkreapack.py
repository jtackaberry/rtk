#!/usr/bin/env python3
import argparse
import logging
import os
import re
import sys
from subprocess import Popen, PIPE
from datetime import datetime

log = logging.getLogger('mkreapack')
logging.basicConfig(format='[%(levelname)s] %(message)s', level=logging.DEBUG)

def shell(cmd):
    p = Popen(cmd, shell=True, stdout=PIPE, close_fds=True)
    stdout, stderr = p.communicate()
    if p.returncode > 0:
        log.critical('command failure: %s', cmd)
        sys.exit(1)
    return stdout.decode()


def get_tag_timestamp(tag):
    ts = shell('git show -s --format=%cd ' + tag).strip()
    dt = datetime.strptime(ts, '%a %b %d %H:%M:%S %Y %z')
    return dt.strftime('%Y-%m-%dT%H:%M:%SZ')


def get_latest_from_manifest(manifest, opts):
    versions = open(os.path.join(opts.path, manifest)).read().splitlines()
    return sorted(versions, key=lambda v: int(v.split('.')[0]))[-1]


def parsever(v):
    return [int(part) for part in re.split(r'[.-]', v)]


def gen_reapack_version(xml, opts):
    manifest = get_latest_from_manifest('MANIFEST', opts)
    m = re.search(r'<version.*?name="([^"]+)', xml)
    if not m:
        return manifest
    else:
        reapack = m.group(1)

    if parsever(manifest) > parsever(reapack):
        # Latest from MANIFEST is newer than last ReaPack, so we can use it directly.
        return manifest

    parts = parsever(reapack)
    if len(parts) == 3:
        # This is our first increment
        return f'{manifest}-1'
    else:
        return f'{manifest}-{parts[-1] + 1}'


def get_manifest_versions(manifest, opts):
    versions = set()
    try:
        lines = open(os.path.join(opts.path, manifest))
    except OSError:
        pass
    else:
        for ver in lines:
            versions.add(ver.strip())
    return versions


def gen_changelog(opts):
    # Versions in the reapack manifest
    reapack = get_manifest_versions(opts.reapack_manifest, opts)
    manifest = get_manifest_versions('MANIFEST', opts)
    lines = ['This REAPER Toolkit bundle includes the following major API versions:\n']
    for ver in sorted(manifest, reverse=True):
        lines.append(f'# {ver}\n')
        if ver in reapack:
            lines.append('No changes to this API version in this release.\n')
        else:
            major = ver.split('.')[0]
            try:
                changes = open(os.path.join(opts.path, major, 'CHANGELOG.md')).read().strip()
            except OSError:
                changes = ''
            if not changes:
                lines.append('* Minor fixes\n')
            else:
                # Replace the version heading line as the changelog file includes that.
                lines[-1] = changes
        lines.append('')

    lines.append('\nFor a complete historical change log, visit https://reapertoolkit.dev/changelog\n')
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(prog='mkreapack')
    parser.add_argument('-t', '--tag', type=str, required=True,
                        help='Git tag name for release')
    parser.add_argument('-i', '--input', default='index.xml',
                        help='Previous ReaPack file for input (default: index.xml)')
    parser.add_argument('--reapack-manifest', default='MANIFEST.reapack',
                        help='Path to the MANIFEST that was used to generate input ReaPack file (default: MANIFEST.reapack)')
    parser.add_argument('-o', '--output', default='/dev/stdout',
                        help='ReaPack output file (default: stdout)')
    parser.add_argument('-m', '--maxversions', default=5, type=int,
                        help='Maximum number of historical versions to preserve (default: 5)')
    parser.add_argument('-p', '--path', default='./',
                        help='Path to the root of the repo (default: .)')
    parser.add_argument('-a', '--author', type=str, required=True,
                        help='Author name')
    parser.add_argument('-r', '--repo', type=str,
                        help='GitHub repo name (defaults to $GITHUB_REPOSITORY)')
    parser.add_argument('files', nargs='+',
                        help='Files to include in new ReaPack version')
    opts = parser.parse_args()

    if not opts.repo:
        opts.repo = os.getenv('GITHUB_REPOSITORY')
        if not opts.repo:
            log.critical('--repo not given and $GITHUB_REPOSITORY not set')
            return 1

    opts.path = os.path.abspath(opts.path)
    xml = open(os.path.join(opts.path, opts.input)).read()

    # Age out old versions
    nversions = 0
    def find(m):
        nonlocal nversions
        nversions += 1
        content = m.group(1)
        # Remove sufficiently old versions, but also remove versions that point to files
        # with the same tag and assume a replacement (e.g. if a tag was force-replaced).
        # This naive substring search should be good enough given release tags are fairly
        # unique.
        if nversions > opts.maxversions or opts.tag in content:
            return ''
        else:
            return content
    xml = re.sub(r'( *<version .*?</version>\n)', find, xml, flags=re.S)

    startcwd = os.getcwd()
    os.chdir(opts.path)
    tagtime = get_tag_timestamp(opts.tag)
    version = gen_reapack_version(xml, opts)
    lines = [f'<version name="{version}" author="{opts.author}" time="{tagtime}">']

    urlbase = f'https://raw.githubusercontent.com/{opts.repo}/{opts.tag}/'
    for fname in opts.files:
        fpath = os.path.abspath(fname)
        if not fpath.startswith(opts.path):
            log.error('%s is not relative to repo root %s', fname, opts.path)
            continue
        relpath = fpath[len(opts.path)+1:]
        lines.append(f'  <source file="../{relpath}" type="script" main="nomain">{urlbase + relpath}</source>')

    changelog = gen_changelog(opts)
    lines.append(f'  <changelog><![CDATA[{changelog}]]></changelog>')

    lines.append(f'</version>')
    verxml = '\n'.join('      ' + line for line in lines)


    # Insert new version below reapack tag.
    xml = re.sub(r'(<reapack.*\n)', '\\1' + verxml + '\n', xml)
    os.chdir(startcwd)
    with open(opts.output, 'w') as f:
        f.write(xml)
    print(opts)

if __name__ == '__main__':
    sys.exit(main() or 0)
