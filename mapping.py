#! /usr/bin/env python3
import re
from signal import signal, SIGPIPE, SIG_DFL
from xml.etree import ElementTree as ET


def unicode_range(s):
    m = re.match('(\w+)\.\.(\w+);', s)
    if not m:
        raise 'Invalid range: %s' % s
    return tuple(map(lambda x: int(x, base=16), m.groups()))


def load_blocks(path='Blocks.txt'):
    with open(path) as f:
        ret = {}
        for line in f:
            line = line.strip()
            if not line or line[0] == '#':
                continue
            line_parts = line.split(' ')
            _range = unicode_range(line_parts[0])
            block_name = ' '.join(line_parts[1:])
            ret[block_name] = _range
    return ret


def load_cmap(path):
    root = ET.parse(path).getroot()
    # Only supporting format '4' seems sufficient for now
    cmap4 = root.find('.//cmap_format_4')
    ret = {}
    for el in cmap4.iter('map'):
        k = int(el.attrib['code'], base=16)
        ret[k] = el.attrib['name']
    return ret


def load_block_ranges(path):
    blocks = load_blocks()
    ret = []
    with open(path) as f:
        for line in f:
            ret.append(blocks[line.strip()])
    return ret


def in_range(block_ranges, code):
    return any(r[0] <= code and code <= r[1] for r in block_ranges)


def mappings(m1, m2=None):
    for k in m1.keys():
        if m2 and k not in m2:
            continue
        if m2:
            yield (m1[k], m2[k])
        else:
            yield (m1[k], m1[k])


def print_mapping(t):
    print('%s %s' % tuple(map(lambda x: x.replace('cid', ''), t)))


def print_mappings(p_blocks, p1, p2=None):
    print('mergefonts')
    block_ranges = load_block_ranges(p_blocks)
    m1_all = load_cmap(p1)
    m1 = {k: v for (k,v) in m1_all.items() if in_range(block_ranges, k)}
    if p2:
        m2 = load_cmap(p2)
        ms = mappings(m1, m2)
    else:
        ms = mappings(m1)
    for mapping in ms:
        print_mapping(mapping)


if __name__ == '__main__':
    from sys import argv
    # Don't complain about e.g. ./this_script.py | head
    signal(SIGPIPE,SIG_DFL)
    print_mappings(*argv[1:])
