"""Tests for the pure string transforms in scripts/flatten_arcticons.py.

Only ``parse_css`` and ``flatten`` are covered here — both are pure
str -> value functions with no I/O, which is why they are testable in
isolation. The ``main`` filesystem driver is not exercised (it is thin glue
over ``Path.glob``/``read_text``/``write_text``).

``flatten_arcticons`` is imported directly; pytest's ``pythonpath = ["scripts"]``
(pyproject.toml) puts the single-file script on the path, and its
``if __name__ == "__main__"`` guard keeps ``main`` from running on import.
"""

from __future__ import annotations

from pathlib import Path

import flatten_arcticons as fa

# ---------------------------------------------------------------------------
# parse_css
# ---------------------------------------------------------------------------


def test_single_rule_gets_trailing_semicolon() -> None:
    assert fa.parse_css(".a{fill:red}") == {"a": "fill:red;"}


def test_existing_trailing_semicolon_is_not_doubled() -> None:
    assert fa.parse_css(".a{fill:red;}") == {"a": "fill:red;"}


def test_grouped_selector_applies_body_to_every_class() -> None:
    # ".a,.b{...}" must land on both a and b (Arcticons groups shared rules).
    assert fa.parse_css(".a,.b{stroke:none}") == {
        "a": "stroke:none;",
        "b": "stroke:none;",
    }


def test_repeated_class_appends_in_cascade_order() -> None:
    # Later declarations append to earlier ones for the same class.
    assert fa.parse_css(".a{fill:red}.a{stroke:blue}") == {"a": "fill:red;stroke:blue;"}


def test_empty_rule_body_is_skipped() -> None:
    # ".a{}" carries no declarations, so no entry is created.
    assert fa.parse_css(".a{}") == {}


def test_non_class_selector_produces_no_entry() -> None:
    # A bare element selector has no ".name", so nothing is captured.
    assert fa.parse_css("svg{fill:red}") == {}


def test_hyphen_and_underscore_class_names() -> None:
    assert fa.parse_css(".cls-1,._x{fill:#000}") == {
        "cls-1": "fill:#000;",
        "_x": "fill:#000;",
    }


def test_empty_css_returns_empty_mapping() -> None:
    assert fa.parse_css("") == {}


# ---------------------------------------------------------------------------
# flatten
# ---------------------------------------------------------------------------


def test_svg_without_style_block_is_returned_unchanged() -> None:
    svg = '<svg><path class="a" d="M0 0"/></svg>'
    assert fa.flatten(svg) == svg


def test_style_block_with_no_class_rules_returns_input_unchanged() -> None:
    # A <style> whose rules are all element selectors yields no class map.
    svg = "<svg><defs><style>svg{fill:red}</style></defs><path/></svg>"
    assert fa.flatten(svg) == svg


def test_class_is_replaced_by_inline_style_and_class_attr_removed() -> None:
    svg = '<svg><defs><style>.a{fill:red}</style></defs><path class="a" d="M0 0"/></svg>'
    out = fa.flatten(svg)
    assert 'style="fill:red;"' in out
    assert "class=" not in out
    assert 'd="M0 0"' in out  # unrelated attributes are preserved


def test_style_and_empty_defs_nodes_are_stripped() -> None:
    svg = '<svg><defs><style>.a{fill:red}</style></defs><path class="a"/></svg>'
    out = fa.flatten(svg)
    assert "<style" not in out
    assert "<defs>" not in out


def test_multiple_classes_on_one_element_are_concatenated() -> None:
    svg = (
        "<svg><defs><style>.a{fill:red}.b{stroke:blue}</style></defs>"
        '<path class="a b"/></svg>'
    )
    out = fa.flatten(svg)
    assert 'style="fill:red;stroke:blue;"' in out


def test_existing_inline_style_is_merged_before_class_rules() -> None:
    svg = (
        "<svg><defs><style>.a{fill:red}</style></defs>"
        '<path style="opacity:0.5" class="a"/></svg>'
    )
    out = fa.flatten(svg)
    # Existing declaration keeps its place and gets a separator before the
    # appended class rule.
    assert 'style="opacity:0.5;fill:red;"' in out


def test_unknown_class_leaves_element_untouched_including_class_attr() -> None:
    # When a class has no matching rule, ``applied`` is empty and the element
    # is returned verbatim -- so the class= attribute is NOT stripped. This is
    # actual behavior worth pinning: flatten only rewrites elements it can
    # resolve to at least one declaration.
    svg = '<svg><defs><style>.a{fill:red}</style></defs><path class="z"/></svg>'
    out = fa.flatten(svg)
    assert 'class="z"' in out


def test_self_closing_and_open_tag_forms_both_flatten() -> None:
    open_form = '<svg><defs><style>.a{fill:red}</style></defs><g class="a"></g></svg>'
    out = fa.flatten(open_form)
    assert '<g style="fill:red;">' in out
    assert "</g>" in out


# ---------------------------------------------------------------------------
# main (filesystem driver) -- resilience
# ---------------------------------------------------------------------------


def test_one_unreadable_file_is_skipped_without_aborting_the_batch(
    tmp_path: Path,
) -> None:
    # Regression for audit L4: a single non-UTF-8 (or otherwise unreadable)
    # SVG must not kill the whole run and leave later files unprocessed.
    src = tmp_path / "in"
    dst = tmp_path / "out"
    src.mkdir()
    # Sorted glob visits "01-bad" before "02-good"; if the bad file aborts the
    # loop, the good file never gets written -- which is exactly what we assert
    # against.
    (src / "01-bad.svg").write_bytes(b"\xff\xfe not valid utf-8")
    (src / "02-good.svg").write_text(
        '<svg><defs><style>.a{fill:red}</style></defs><path class="a"/></svg>',
        encoding="utf-8",
    )

    rc = fa.main(["flatten_arcticons.py", str(src), str(dst)])

    # Non-zero so an automation caller notices the partial failure...
    assert rc == 1
    # ...but the good file after the bad one was still converted.
    good_out = dst / "02-good.svg"
    assert good_out.exists()
    assert 'style="fill:red;"' in good_out.read_text(encoding="utf-8")
    # The bad file is skipped, not written as garbage.
    assert not (dst / "01-bad.svg").exists()


def test_all_good_files_return_zero(tmp_path: Path) -> None:
    src = tmp_path / "in"
    dst = tmp_path / "out"
    src.mkdir()
    (src / "a.svg").write_text("<svg><path/></svg>", encoding="utf-8")

    assert fa.main(["flatten_arcticons.py", str(src), str(dst)]) == 0
