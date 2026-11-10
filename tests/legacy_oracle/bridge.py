"""Binary-safe, single-request interface used by the SolidStart Node API route.

Only stdin JSON -> stdout ZIP. Errors use stderr and exit codes; no shell.
Keep the Zig project generator as the single source of truth.
"""
from __future__ import annotations

import json
import sys

from .generator import InputError, archive

MAX_BYTES = 16 * 1024


def main() -> int:
    data = sys.stdin.buffer.read(MAX_BYTES + 1)
    if not data or len(data) > MAX_BYTES:
        print('Request must contain 1–16384 bytes', file=sys.stderr)
        return 2
    try:
        request = json.loads(data)
        result = archive(request)
    except (InputError, ValueError, TypeError, UnicodeError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    sys.stdout.buffer.write(result)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
