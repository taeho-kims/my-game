# Story 006: 궁수·광전사 + 핫바(숫자키 1·2·3)

> **Epic**: slime-nodaji
> **Status**: Complete
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6 — 궁수·광전사 영웅 타입 + 숫자키 1·2·3 선택 (핫바)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop 1, MVP 6), values from the prototype:*

*수치는 `assets/data/hero_types.json`(아래 `types.*`)이 기준이다. 문서의 값이 아니라 파일의 값이 맞다.*

- [x] 궁수는 `archer 레벨`명이 출격한다. 사거리 `types.archer.range`, 이동 속도 `types.archer.chase_speed`, 쿨다운 `기사 쿨다운 × types.archer.cooldown_multiplier`이다.
- [x] 궁수는 한 번에 `arrows_base + arrows 레벨`발(`skill_tree.json`의 `stats.arrows_base`)을 서로 다른 목표에게 쏜다 (목표가 모자라면 같은 목표). 화살 속도 `types.archer.arrow.speed`, 피해 `공격력 × types.archer.damage_multiplier`이다.
- [x] 광전사는 `barb 레벨`명이 출격한다. 사거리 `types.barb.range_base + 슬라임 반경`, 이동 속도 `types.barb.chase_speed`, 쿨다운 `기사 쿨다운 × types.barb.cooldown_multiplier`이다.
- [x] 광전사의 공격은 반경 `types.barb.slash.radius`(+ 슬라임 반경)의 회전 베기이며 범위 안의 모든 바닥 슬라임에게 `공격력 × types.barb.slash.damage_multiplier` 피해를 준다.
- [x] 핫바는 보유한 영웅 타입만 보여주고, 각 카드에 남은 수와 선택 표시가 있다. 타입을 못 가졌으면 카드가 숨겨진다.
- [x] 숫자키 1·2·3과 카드 클릭으로 영웅 타입을 고른다. 남은 수가 0인 타입은 고를 수 없다. (선택 규칙은 테스트로 검증, 실제 키·클릭 입력은 실행 중 관찰하지 않음)
- [x] 선택한 타입이 소진되면 남은 수가 있는 다음 타입으로 자동 전환된다.
- [x] 세 영웅의 도트 스프라이트(8×8, 2배)와 핫바 카드 아이콘이 표시된다.
- [x] 판이 끝나면 핫바가 비활성화된다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `update`의 영웅 구간, `buildHotbar`, `updateHotbar`, `keydown` 처리, `SPR` 스프라이트다.
- 기사의 이동·추적 로직은 story 002의 것을 재사용하고, 타입별 차이만 데이터로 둔다.
- **단위 변환 (2026-10-27):** 사거리·이동 속도·화살 속도·베기 반경은 1280×720 기준 프로토타입 값(170/70/420/22+r/80/44)의 0.5배다. 스프라이트는 3배 대신 2배다. 쿨다운·피해·개수는 그대로다.

---

## Out of Scope

- story 005: `archer`, `arrows`, `barb` 노드 구매 UI
- 신규 영웅 타입

---

## Files

src/gameplay/hero/archer.gd
src/gameplay/hero/berserker.gd
src/gameplay/hero/arrow.gd
src/gameplay/hero/hero_roster.gd
src/gameplay/hero/hero_types.gd
src/gameplay/hero/hero.gd
src/gameplay/hero/hero_squad.gd
src/gameplay/run/run_scene.gd
src/gameplay/slime/slime_field_demo.gd
src/ui/hotbar/hotbar.gd
src/ui/hotbar/hotbar.tscn
assets/data/hero_types.json
tests/unit/heroes/hero_types_test.gd

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal`: 테스트는 면제(권고)이며, 유지되는 스크린샷은 면제되지 않는다.*

**Story Type**: Logic
**Required evidence**: `tests/unit/heroes/hero_types_test.gd` (권고)

**Status**: [x] Created — `tests/unit/heroes/hero_types_test.gd` 24개 통과 (전체 139개 통과). 스크린샷 `production/qa/evidence/story-006-archer-berserker-hotbar/`

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-002-hero-drop-combat.md`
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-29
**Criteria**: 9/9 passing (none deferred)
**Deviations**: `hero_roster.gd`, `hero_types.gd` added beyond the original file list (advisory, already listed under `## Files`). 광전사 베기 반경은 `types.barb.slash.radius` + 슬라임 반경, 자동 전환은 핫바 순서상 남은 수가 있는 첫 타입 — 둘 다 사용자 확인 후 유지.
**Test Evidence**: `tests/unit/heroes/hero_types_test.gd` (24 tests, full suite 139 passing); screenshots in `production/qa/evidence/story-006-archer-berserker-hotbar/`; keys, click and auto-switch confirmed by the user in F5.
**Reviewed by**: self, no independent review
