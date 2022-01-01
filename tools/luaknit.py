# Copyright 2021-2022 Jason Tackaberry
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys
import os
import re
import logging
import argparse

log = logging.getLogger('luaknit')
logging.basicConfig(format='[%(levelname)s] %(message)s', level=logging.DEBUG)

modules = {}
aliases = {}

class FullHelpParser(argparse.ArgumentParser):
    def error(self, message):
        sys.stderr.write('error: %s\n' % message)
        self.print_help()
        sys.exit(2)

def get_global_module_name(name):
    return '__mod_' + re.sub(r'[^a-zA-Z\d_]', '_', name)


def get_stripped_source(fname):
    """
    Returns the contents of the given file with (most) comments removed out,
    whitespace stripped from either end, and, in some cases, inline
    whitespace removed.
    """
    contents = open(fname).read()
    # Remove multiline comments
    contents = re.sub(r'[^-]--\[\[.*?\]\](--)?', '', contents, flags=re.S)
    # Strip common informational fields
    contents = re.sub(
        r'''_(VERSION|DESCRIPTION|URL|LICENSE) *= *(\[\[.*?\]\]|'[^']*'|"[^"]*"),?''',
        '',
        contents,
        flags=re.S
    )
    for n, line in enumerate(contents.splitlines(), 1):
        # Remove single line comments.
        line = re.sub(r'^ *--.*', '', line)
        # We can't robustly remove end-of-line comments because we don't easily
        # know whether the '--' exists within a string without tokenizing, but
        # we can use a simple heuristic and assume any '--' without a quote
        # after it must be a comment.
        line = re.sub(r'''--[^'"]*$''', '', line).strip()
        # If the line contains no quotes at all (and therefore no strings to worry about
        # mangling), we can remove inline whitespace.
        if '"' not in line and "'" not in line:
            # Two character tokens
            line = re.sub(r' *(==|<=|>=|~=|\.\.) *', r'\1', line)
            # Single character tokens
            line = re.sub(r' *([=<>+\-*/,|&%()]) *', r'\1', line)
        elif re.search(r'''^[^'"]+=[^=]+$''', line):
            # Common case of foo = "bar"
            line = re.sub(r' *= *', '=', line)
            pass
        if line:
            yield n, line


def print_conditional_newline(last, out):
    if last and not re.search(r'''[(){}.'"=<>+\-*/,|&%]$''', last):
        out('\n')


def process(filename, module, symbol, seen, out, last=None):
    if os.path.isdir(filename):
        filename = os.path.join(filename, 'init.lua')
    if filename in seen:
        return
    seen.add(filename)
    modules[module] = symbol
    print_conditional_newline(last, out)
    out(f'{symbol}=(function()\n')
    last = None
    for n, line in get_stripped_source(filename):
        # Handle static import in the forms:
        #   require 'foo.bar'
        #   require('foo.bar')
        m = re.search(r'''^([^=]*= *require| *require) *\(? *["'](\S+)["']''', line)
        if m:
            submodule = m.group(2)
            subsymbol = modules.get(submodule)
            if not subsymbol:
                # Module wasn't yet loaded.  Do that now.
                #
                # Take the submodule and treat it as an exact path relative to pwd. It's
                # naive, but if we don't have a user-defined alias, it's all we can do.
                search_bases = [submodule.replace('.', os.path.sep)]
                # Do we have an alias that prefixes the requested module?
                for alias_symbol, (alias_path, _) in aliases.items():
                    if submodule == alias_symbol or submodule.startswith(alias_symbol + '.'):
                        # Yes, this alias matches the requested module (either exactly or as a
                        # prefix).  Normalize the alias path to a directory for the case where
                        # we had alias=somedir/init.lua
                        alias_dir = os.path.dirname(alias_path) if os.path.isfile(alias_path) else alias_path
                        # Strip off the part that matched
                        remaining = submodule[len(alias_symbol):].lstrip('.')
                        # Construct the candidate base name for this module
                        base = os.path.join(alias_dir, remaining.replace('.', os.path.sep))
                        if base:
                            search_bases.append(base)

                        # If the alias path was a specific file, try it directly.
                        if os.path.isfile(alias_path):
                            search_bases.append(os.path.splitext(alias_path)[0])

                for base in search_bases:
                    found = False
                    for suffix in '.lua', '/init.lua':
                        subfname = base + suffix
                        if os.path.exists(subfname):
                            subsymbol = get_global_module_name(submodule) + suffix.replace('.lua', '').replace('/', '_')
                            last = process(subfname, submodule, subsymbol, seen, out, last)
                            found = True
                            break
                    if found:
                        break
                else:
                    log.error('%s: lua file containing %s could not be located', filename, submodule)
                    sys.exit(1)

            # If return value from require statement is assigned, then we substitute the
            # global symbol for it, otherwise we skip the line (if it's a bare require)
            # as the module contents are now evaluated at this point.
            if '=' not in m.group(1):
                continue
            line = re.sub(''' *(= *require[ (]+["']\S+["']\)?)''', '=' + subsymbol, line)
        else:
            # Handle dynamic import in the form:
            #   require(variable)
            m = re.search('''= *require *\(([^"']\S+)\)''', line)
            if m:
                rewrite = '=load("return __mod_" .. {}:gsub("%.", "_"))()'.format(m.group(1))
                line = re.sub(''' *(= *require *\(\S+\))''', rewrite, line)

        print_conditional_newline(last, out)
        out(line)
        last = line
    print_conditional_newline(last, out)
    out('end)()\n')
    return last


def main():
    p = FullHelpParser(prog='luadox')
    p.add_argument('-c', '--comment', type=str, metavar='COMMENT',
                   default='This is generated code.',
                   help='Top-of-file comment (\\n is interpreted as newline)')
    p.add_argument('-o', '--output', type=str, metavar='FILE',
                   default='-',
                   help='Filename to write generated code to (- for stdout)')
    p.add_argument('files', type=str, metavar='[MODNAME=]PATH', nargs='+',
                   help='List of files to parse or directories to crawl with optional module name alias')
    args = p.parse_args()
    args.comment = args.comment.replace('\\n', '\n')
    out = ['-- {}\n'.format(line) for line in args.comment.splitlines()]

    return_symbol = None
    for f in args.files:
        module = f.replace('.lua', '').replace('/', '.')
        if '=' in f:
            symbol, f = f.split('=')
            return_symbol = symbol
        else:
            symbol = get_global_module_name(module)
        aliases[symbol] = (f, module)

    seen = set()
    for symbol, (f, module) in aliases.items():
        process(f, module, symbol, seen, out.append)

    if return_symbol:
        out.append('return {}'.format(return_symbol))

    with (sys.stdout if args.output == '-' else open(args.output, 'w')) as f:
        f.write(''.join(out) + '\n')

if __name__ == '__main__':
    main()