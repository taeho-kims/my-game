# Story 001: 슬라임 필드와 코인 드롭

> **Epic**: slime-nodaji
> **Status**: Complete
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-27

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2 — 슬라임 스폰/이동과 코인 드롭, 판마다 스케일 `1.07^판 수`

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop, MVP 2); values from the prototype `slime-nodaji.html`:*

- [ ] 일반 슬라임이 0.3초 간격으로 스폰되어 필드에 최대 `12 + 4×density 레벨`마리까지 유지된다 (기본 12). 출격 시 8마리로 시작한다.
- [ ] 슬라임은 반경 11~15, 4색(초록·하늘·분홍·보라) 중 무작위이며, 체력은 `10 × 1.07^판 수`이다.
- [ ] 슬라임은 0.8~2초마다 속도 25~55로 튀며 필드 경계(상단 18px, 하단 `H-70`)에서 반사된다.
- [ ] 처치 시 코인 1개를 떨어뜨리고, 40% 확률로 1개 더 떨어뜨린다.
- [ ] 코인 종류 확률은 구리 85% / 은 13% / 보석 2%이고, 기본 가치는 구리 1·은 4·보석 15이다.
- [ ] 코인 가치 = 기본 가치 × `1.07^판 수` × `(1 + 0.3×coin 레벨)`.
- [ ] 코인은 튀어 오르며 흩어지고, 수명 9초 후 사라진다 (마지막 2초 깜빡임).
- [ ] 위 모든 수치는 외부 데이터 파일에서 읽는다 (코드에 하드코딩하지 않는다).

---

## Implementation Notes

- 값의 출처는 프로토타입의 `spawnSlime`, `kill`, `dropCoins`, `newRun`, `stats`다. 값을 바꾸지 않고 그대로 옮긴다.
- 판 수 스케일은 매개변수로 받는다 (저장은 story 005).
- 황금 슬라임·고블린·보스 종류는 story 007에서 추가한다.

---

## Out of Scope

- story 002: 영웅과 전투
- story 003: 코인 수집과 상자
- story 007: 특수 슬라임 종류

---

## Files

- src/gameplay/slime/slime.gd (+ .uid)
- src/gameplay/slime/slime_field.gd (+ .uid)
- src/gameplay/coin/coin.gd (+ .uid)
- src/gameplay/slime/slime_field_demo.gd (+ .uid) — dev harness
- src/gameplay/slime/slime_field_demo.tscn — dev harness
- assets/data/slime_field.json
- .godot/global_script_class_cache.cfg (Slime, SlimeField, Coin registered)
- tests/unit/slime-field/slime_field_test.gd — not created (qa.level: minimal, tests waived)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal`: 테스트는 면제(권고)이며, Visual/Feel·UI 스토리의 유지되는 스크린샷은 면제되지 않는다.*

**Story Type**: Logic
**Required evidence**: `tests/unit/slime-field/slime_field_test.gd` (권고)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/slime-nodaji/story-002-hero-drop-combat.md`, `production/epics/slime-nodaji/story-003-magnet-chest-tiers.md`

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 8/8 passing (AC-1, 3, 4, 7 by the user's run; AC-2, 5 by the user's run plus an engine-executed check of `SlimeField.slime_hp` / `roll_coin_kind`; AC-6 by an engine-executed check of `SlimeField.coin_value` against the formula, 6 cases, 0 mismatches — not visible on screen; AC-8 by code search)
**Deviations**: advisory, logged as TD-001..TD-004 in `docs/tech-debt-register.md` — hardcoded draw shapes/colors in `slime.gd`/`coin.gd`; `slime_field.json` schema only in a code doc comment; `Coin.advance` can re-emit `expired`; `*.json` must be added to the export include filter
**Test Evidence**: waived at qa.level minimal; run evidence `production/qa/evidence/story-001-slime-field/` (2 screenshots + stamp, UNCHANGED at close)
**Reviewed by**: self, no independent review
