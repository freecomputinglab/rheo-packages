"""Atom-parsing helpers shared by ../demo/check.sh and ./run.sh.

Both callers are grep/parse checks over REAL built feeds rather than a test
framework — see ../demo/check.sh's own header for why the package ships no
runner. These four helpers were copied verbatim into both scripts and had
already drifted by one function, so they live here once instead.

Standard library only, deliberately: the scripts run under whatever `python3`
is on PATH, with no install step and no dependency to keep in sync.

`entries()` takes TEXT, not a path — that is the shape both callers can use
(check.sh read a path, run.sh already had a string in hand).
"""

import re

_ENTRY_RE = re.compile(r"<entry>(.*?)</entry>", re.S)
_LINK_RE = re.compile(r'<link rel="alternate" href="([^"]+)"/>')


def entries(text):
    """Every `<entry>`'s inner XML, in document order."""
    return _ENTRY_RE.findall(text)


def field(entry, tag):
    """One element's text out of an entry, or None when it has no such tag."""
    m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", entry, re.S)
    return m.group(1) if m else None


def link(entry):
    """An entry's `rel="alternate"` href, or None.

    Call it on ONE entry's inner XML, never on a whole feed: since the feed
    itself also carries a `rel="alternate"` link (the site root, beside its
    `rel="self"`), this pattern would otherwise match that one too.
    """
    m = _LINK_RE.search(entry)
    return m.group(1) if m else None


class Checker:
    """Collects failures so a script can report all of them, then exit once."""

    def __init__(self):
        self.bad = False

    def fail(self, msg):
        print(f"FAIL: {msg}")
        self.bad = True

    def exit_code(self):
        return 1 if self.bad else 0
