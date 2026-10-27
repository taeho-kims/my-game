## Technical Debt Register

Last updated: 2026-10-27
Total items: 4 | Estimated total effort: 4 S

| ID | Category | Description | Files | Effort | Impact | Priority | Status | Added | Sprint |
|----|----------|-------------|-------|--------|--------|----------|--------|-------|--------|
| TD-001 | Code Quality | Draw shapes and colors (shadow, eyes, highlight, HP bar, coin/gem shapes) are hardcoded art constants, not in the data file — from production/epics/slime-nodaji/story-001-slime-field.md | src/gameplay/slime/slime.gd, src/gameplay/coin/coin.gd | S | Low | — | Open | 2026-10-27 | Backlog |
| TD-002 | Documentation | slime_field.json schema is documented only in the SlimeField.load_config doc comment; data-files rule wants a JSON Schema or design-doc entry — from production/epics/slime-nodaji/story-001-slime-field.md | assets/data/slime_field.json, src/gameplay/slime/slime_field.gd | S | Low | — | Open | 2026-10-27 | Backlog |
| TD-003 | Code Quality | Coin.advance re-emits `expired` on every call after life runs out (no guard like Slime._dead) — from production/epics/slime-nodaji/story-001-slime-field.md | src/gameplay/coin/coin.gd | S | Low | — | Open | 2026-10-27 | Backlog |
| TD-004 | Dependency | res:// JSON loaded via FileAccess must be added to the export preset's include filter (`*.json`) or exported builds lose their data — from production/epics/slime-nodaji/story-001-slime-field.md | assets/data/slime_field.json | S | Med | — | Open | 2026-10-27 | Backlog |
