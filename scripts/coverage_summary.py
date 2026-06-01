#!/usr/bin/env python3
"""Summarize Flutter lcov.info for CI logs and GITHUB_STEP_SUMMARY."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


def parse_lcov(path: Path) -> tuple[int, int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines_found = sum(int(m.group(1)) for m in re.finditer(r"^LF:(\d+)", text, re.MULTILINE))
    lines_hit = sum(int(m.group(1)) for m in re.finditer(r"^LH:(\d+)", text, re.MULTILINE))
    return lines_hit, lines_found


def main() -> int:
    lcov = Path("coverage/lcov.info")
    if not lcov.is_file():
        print("coverage/lcov.info not found", file=sys.stderr)
        return 1

    hit, total = parse_lcov(lcov)
    pct = (100.0 * hit / total) if total else 0.0
    summary = f"**Line coverage:** {hit}/{total} ({pct:.1f}%)"

    print(summary)
    report_path = Path("coverage/coverage-summary.md")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        "# Coverage summary\n\n"
        f"- Lines hit: {hit}\n"
        f"- Lines total: {total}\n"
        f"- Percentage: **{pct:.1f}%**\n",
        encoding="utf-8",
    )

    github_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary:
        with open(github_summary, "a", encoding="utf-8") as fh:
            fh.write("## Flutter coverage\n\n")
            fh.write(summary + "\n")
            fh.write(f"\nArtifact: `coverage/lcov.info`\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
