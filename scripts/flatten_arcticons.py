#!/usr/bin/env python3
"""
Flatten Arcticons SVGs so KOReader's NanoSVG renderer can display them.

NanoSVG doesn't understand <style> blocks or class= references. Every
Arcticons icon ships its drawing rules inside <defs><style>.x{...}</style></defs>
and references them as class="x" on each path/line/circle, so NanoSVG
strips them and falls back to fill=black, stroke=none. The result on
KOReader is a solid black blob where the icon should be.

This script:
  1. Parses each .svg in the input dir.
  2. Extracts the CSS rules from any <style> blocks under <defs>.
  3. For every element with a class= attribute, replaces class= with an
     inline style= attribute holding the equivalent declarations.
  4. Removes the now-redundant <style>/<defs> nodes.
  5. Writes the result to the output dir.

The transformation is intentionally minimal — only rules of the form
".name{prop:val;...}" (single class, possibly grouped via comma) are
handled. Arcticons uses nothing more complex than that.

Usage: flatten_arcticons.py <input-dir> <output-dir>
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def parse_css(css_text: str) -> dict[str, str]:
    """Return {class_name: declarations} for every rule found.

    Handles grouped selectors like ".a,.b{...}". Later rules append to
    earlier ones for the same class (matches CSS cascade well enough for
    Arcticons' use of layered .b/.c definitions).
    """
    rules: dict[str, str] = {}
    for selectors_raw, body in re.findall(r"([^{}]+)\{([^}]*)\}", css_text):
        body = body.strip()
        if not body:
            continue
        if not body.endswith(";"):
            body += ";"
        for cls in re.findall(r"\.([A-Za-z_][\w-]*)", selectors_raw):
            rules[cls] = rules.get(cls, "") + body
    return rules


def flatten(svg_text: str) -> str:
    style_blocks = re.findall(r"<style[^>]*>(.*?)</style>", svg_text, flags=re.DOTALL)
    if not style_blocks:
        return svg_text

    rules: dict[str, str] = {}
    for block in style_blocks:
        for cls, decls in parse_css(block).items():
            rules[cls] = rules.get(cls, "") + decls
    if not rules:
        return svg_text

    tag_re = re.compile(
        r"<(?P<name>[A-Za-z][\w-]*)\b(?P<attrs>[^>]*?)(?P<slash>\s*/?)>",
        flags=re.DOTALL,
    )

    def rewrite_tag(match: re.Match[str]) -> str:
        name = match.group("name")
        attrs = match.group("attrs")
        slash = match.group("slash")
        class_match = re.search(r'\s+class\s*=\s*"([^"]+)"', attrs)
        if not class_match:
            return match.group(0)
        class_names = class_match.group(1).split()
        applied = "".join(rules.get(c, "") for c in class_names)
        if not applied:
            return match.group(0)

        # Drop class=
        new_attrs = attrs[: class_match.start()] + attrs[class_match.end() :]
        # Merge into existing style= if present, else append a new one.
        style_match = re.search(r'\s+style\s*=\s*"([^"]*)"', new_attrs)
        if style_match:
            existing = style_match.group(1)
            if existing and not existing.endswith(";"):
                existing += ";"
            merged = existing + applied
            new_attrs = (
                new_attrs[: style_match.start()]
                + f' style="{merged}"'
                + new_attrs[style_match.end() :]
            )
        else:
            new_attrs = new_attrs.rstrip() + f' style="{applied}"'
        return f"<{name}{new_attrs}{slash}>"

    out = tag_re.sub(rewrite_tag, svg_text)
    out = re.sub(r"<style[^>]*>.*?</style>", "", out, flags=re.DOTALL)
    out = re.sub(r"<defs>\s*</defs>", "", out)
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    src = Path(argv[1])
    dst = Path(argv[2])
    dst.mkdir(parents=True, exist_ok=True)

    converted = 0
    skipped = 0
    for path in sorted(src.glob("*.svg")):
        text = path.read_text(encoding="utf-8")
        flat = flatten(text)
        (dst / path.name).write_text(flat, encoding="utf-8")
        if flat == text:
            skipped += 1
        else:
            converted += 1
    print(f"Flattened {converted} SVGs, {skipped} unchanged, output in {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
