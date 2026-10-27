# Story 006: 궁수·광전사 + 핫바(숫자키 1·2·3)

> **Epic**: slime-nodaji
> **Status**: Ready
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] 궁수는 `archer 레벨`명이 출격한다. 사거리 85, 이동 속도 35, 쿨다운 `기사 쿨다운 × 1.35`이다.
- [ ] 궁수는 한 번에 `1 + arrows 레벨`발을 서로 다른 목표에게 쏜다 (목표가 모자라면 같은 목표). 화살 속도 210, 피해 `공격력 × 0.9`이다.
- [ ] 광전사는 `barb 레벨`명이 출격한다. 사거리 `11 + 슬라임 반경`, 이동 속도 40, 쿨다운 `기사 쿨다운 × 1.25`이다.
- [ ] 광전사의 공격은 반경 22의 회전 베기이며 범위 안의 모든 바닥 슬라임에게 `공격력 × 1.1` 피해를 준다.
- [ ] 핫바는 보유한 영웅 타입만 보여주고, 각 카드에 남은 수와 선택 표시가 있다. 타입을 못 가졌으면 카드가 숨겨진다.
- [ ] 숫자키 1·2·3과 카드 클릭으로 영웅 타입을 고른다. 남은 수가 0인 타입은 고를 수 없다.
- [ ] 선택한 타입이 소진되면 남은 수가 있는 다음 타입으로 자동 전환된다.
- [ ] 세 영웅의 도트 스프라이트(8×8, 2배)와 핫바 카드 아이콘이 표시된다.
- [ ] 판이 끝나면 핫바가 비활성화된다.

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

- src/gameplay/hero/archer.gd
- src/gameplay/hero/berserker.gd
- src/gameplay/hero/arrow.gd
- src/ui/hotbar/hotbar.gd
- src/ui/hotbar/hotbar.tscn
- assets/data/hero_types.json
- tests/unit/heroes/hero_types_test.gd

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal`: 테스트는 면제(권고)이며, 유지되는 스크린샷은 면제되지 않는다.*

**Story Type**: Logic
**Required evidence**: `tests/unit/heroes/hero_types_test.gd` (권고)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-002-hero-drop-combat.md`
- Unlocks: None
