"""Optional generator command for CI/offline use. This is not required by projects."""
import argparse
import json
from pathlib import Path

from .generator import InputError, create_directory


def main():
    parser = argparse.ArgumentParser(description='Generate a standalone Zevui application')
    parser.add_argument('name')
    parser.add_argument('--title', default=None)
    parser.add_argument('--organization', default='dev.example')
    parser.add_argument('--version', default='0.1.0')
    parser.add_argument('--addon', action='append', default=[])
    parser.add_argument('--output', type=Path, default=Path('.'))
    args = parser.parse_args()
    try:
        dest = create_directory({
            'name': args.name, 'title': args.title or args.name,
            'organization': args.organization, 'version': args.version,
            'addons': args.addon,
        }, args.output)
    except (InputError, FileExistsError) as e:
        parser.error(str(e))
    print(f'Created {dest}\n  cd {dest}\n  zig build run')


if __name__ == '__main__':
    main()
