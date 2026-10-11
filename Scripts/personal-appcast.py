#!/usr/bin/env python3
"""Generate the personal feed from the signed archive, never the upstream feed."""
import argparse
import base64
import plistlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)

def make_feed(archive, info, tag, signature, output):
    assert info['CFBundleIdentifier'] == 'com.shaoyou11.codenotcht', 'Wrong app identity'
    version = info['CFBundleShortVersionString']
    build = str(info['CFBundleVersion'])
    assert re.fullmatch(r'\d+(?:\.\d+){1,3}', version)
    assert re.fullmatch(r'\d+', build)
    assert re.fullmatch(r'codenotcht-v' + re.escape(version) + r'-[0-9a-f]{12}', tag)
    assert archive.name == f'CodenotchT-{version}.zip'
    assert len(base64.b64decode(signature, validate=True)) == 64
    root = ET.Element('rss', {'version': '2.0'})
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'CodenotchT 个人版更新'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'CodenotchT {version} · 构建 {build}'
    ET.SubElement(item, 'description').text = '个人版更新：保留中文界面、缩放、小胶囊和控制弧隐藏。安装后自动重新打开。'
    ET.SubElement(item, f'{{{SPARKLE}}}minimumSystemVersion').text = info.get('LSMinimumSystemVersion', '14.0')
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/shaoyou11/codenotch/releases/download/{tag}/{archive.name}',
        'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
        f'{{{SPARKLE}}}version': build,
        f'{{{SPARKLE}}}shortVersionString': f'{version}（构建 {build}）',
        f'{{{SPARKLE}}}edSignature': signature,
    })
    ET.indent(root)
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('archive', type=Path)
    p.add_argument('info', type=Path)
    p.add_argument('tag')
    p.add_argument('signature', type=Path)
    p.add_argument('output', type=Path)
    a = p.parse_args()
    make_feed(a.archive, plistlib.loads(a.info.read_bytes()), a.tag, a.signature.read_text().strip(), a.output)
