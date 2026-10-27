# Story 002: 영웅 강하·착지 충격·기사 자동전투

> **Epic**: slime-nodaji
> **Status**: Ready
> **Layer**: N/A (minimal — no layers)
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1 — 영웅 강하 + 착지 충격 + 기사 자동전투 (손맛의 핵심, 최우선 품질 목표)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop, Who it's for), values from the prototype:*

- [ ] 필드를 클릭하면 그 자리에 기사가 높이 210에서 낙하한다 (중력 550). 낙하 중 그림자는 높이에 따라 작아졌다 커진다.
- [ ] 출격 시 기사 `2 + hero 레벨`명이 있고, 클릭마다 1명씩 소모된다. 0명이면 더 떨어뜨릴 수 없다.
- [ ] 착지 순간 반경 `23 + 3.5×land 레벨`의 충격이 퍼지고, 바닥에 있는 슬라임에게 `(8 + 10×land 레벨) × 1.07^(판 수/2)` 피해를 준다 (세로 거리는 1.4배 가중).
- [ ] 착지 연출이 함께 나온다: 화면 흔들림 `1.5 + 0.25×land 레벨`(px), 먼지 파티클 12개, 0.35초 링 이펙트, 낮은 톱니파 효과음.
- [ ] 마우스를 올리면 착지 범위가 점선 타원으로 미리 보인다.
- [ ] 기사는 착지 후 가장 가까운 슬라임을 속도 45로 추적하고, 사거리 `8 + 슬라임 반경`에서 공격한다.
- [ ] 공격 쿨다운은 `0.75 / (1 + 0.15×spd 레벨)`초, 피해는 `5 × (1 + 0.25×dmg 레벨) × (0.9~1.1)`이다.
- [ ] 피격한 슬라임은 0.12초 흰색으로 번쩍이고 피해 숫자가 떠오른다. 체력이 줄면 체력 바가 보인다.
- [ ] 낙하 중인 영웅은 공격·이동하지 않는다.
- [ ] 640×360 정수 배율에서 착지 순간이 "묵직하고 쫀득하게" 느껴진다 — 유지되는 스크린샷과 서명으로 확인한다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `land`, `update`의 영웅 구간, `pointerdown` 처리다.
- 픽셀 스프라이트는 8×8 도트를 2배로 키운 형태다 (프로토타입 `SPR.knight`는 3배).
- **단위 변환 (2026-10-27):** 프로토타입 수치는 약 1280×720 기준 픽셀값이다. 640×360에서는 거리·크기·속도·중력·높이·흔들림 같은 공간 단위 값만 0.5배로 옮겼다. 체력, 피해, 확률, 시간, 개수는 그대로다. 위 수치는 이미 변환된 값이다.
- 손맛 수치(흔들림, 파티클, 히트 플래시)는 데이터 파일로 빼서 조정하기 쉽게 한다.

---

## Out of Scope

- story 006: 궁수·광전사와 핫바 (이 스토리는 기사 한 종류)
- story 003: 코인 수집

---

## Files

- src/gameplay/hero/hero.gd
- src/gameplay/hero/hero.tscn
- src/gameplay/hero/landing_impact.gd
- assets/data/hero_knight.json
- tests/unit/heroes/landing_damage_test.gd

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: 유지되는 스크린샷(착지 순간) + 서명 → `production/qa/evidence/hero-drop-combat-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-001-slime-field.md`
- Unlocks: `production/epics/slime-nodaji/story-006-archer-berserker-hotbar.md`, `production/epics/slime-nodaji/story-007-run-events.md`
