---
type: log
tags: [meta]
---

# Wiki Change Log

## [2026-05-26] create | initial vault creation
Entities, concepts, synthesis, templates, bases created. Full vault initialized.

## [2026-05-26] ingest | code-review-2026-05-24 + milestone_1 landed in raw/
Raw files `docs/raw/code-review-2026-05-24.md` and `docs/raw/milestone_1.md` added. Source notes created at [[sources/code-review-2026-05-24]] and [[sources/pdf-library]]. Bug inventory in [[synthesis/milestone-1-retrospective]] updated with CR-14, CR-15, B7, B11, S3, S4, A9, B8, B14.

## [2026-05-26] lint | wiki-lint pass
Ran lint_wiki.py + graph_analyzer.py. Real findings: 1 broken wikilink (alloy-vs-promtail, removed), 11 orphan pages (linked from index), log format mismatch (fixed). False positives: 26 "broken" wikilinks are `\|` table-cell escapes (correct Obsidian syntax; linter limitation), 35 "missing frontmatter" are schema mismatch (vault uses `type`/`tags`; linter expects `title`/`category`/`summary`).

## [2026-05-26] create | new concept and source pages
Added [[concepts/molecule-testing]], [[sources/pdf-library]], [[sources/code-review-2026-05-24]]. Updated [[index]] with orphan links, Raw Intake section, Operations/ADRs navigation.
