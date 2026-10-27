# Story 007: 이벤트 4종 (황금 슬라임·슬라임 비·보물 고블린·대왕 푸딩)

> **Epic**: slime-nodaji
> **Status**: Ready
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 7 — 트리가 해금하는 이벤트 4종

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (MVP 7), values from the prototype:*

- [ ] 황금 슬라임: 스폰 시 확률 `0.015 + 0.02×golden 레벨`로 나온다. 체력 `22 × 1.07^판 수`, 처치 시 코인 12개를 풍성하게 떨어뜨린다 (보석 25%, 은 35%, 나머지 구리).
- [ ] 슬라임 비: 확률 `0.3 × rain 레벨`로 한 판에 한 번, 시각은 6초 이후~종료 6초 전 사이 무작위다. 슬라임 22마리가 높이 200~600에서 떨어지고 '슬라임 비!' 배너가 나온다.
- [ ] 보물 고블린: `goblin 레벨`이 1 이상일 때 5초~시간의 60% 사이 무작위 시각에 필드 가장자리에서 나온다. 체력 `90 × 1.07^판 수`, 영웅에게서 도망친다.
- [ ] 고블린은 피격 시 60% 확률로 코인을 떨어뜨리고, 처치 시 코인 25개를 떨어뜨린다. 9초 후에는 화면 밖으로 사라진다.
- [ ] 대왕 푸딩: `boss 레벨`이 1 이상일 때 한 판의 40% 시점에 높이 500에서 필드 중앙으로 떨어진다. 반경 40, 체력 `420 × 1.07^판 수`이다.
- [ ] 보스는 착지 시 착지 충격과 화면 흔들림(12)을 내고, 처치 시 코인 45개(풍성 드롭)와 '대왕 푸딩 격파!' 배너를 낸다.
- [ ] 해당 노드를 사지 않았으면 이벤트는 나오지 않는다.
- [ ] 이벤트별 배너가 약 1초 동안 크게 나타났다 사라진다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `spawnSlime`(종류별 값), `update`의 이벤트 구간, `kill`, `hurt`, 고블린 AI다.
- 이벤트 시각은 판이 시작될 때 한 번 정한다 (프로토타입 `newRun`).
- 이벤트 수치도 데이터 파일(`assets/data/run_events.json`)에서 읽는다.

---

## Out of Scope

- story 005: 이벤트를 해금하는 노드의 구매 UI

---

## Files

- src/gameplay/events/run_events.gd
- src/gameplay/slime/golden_slime.gd
- src/gameplay/slime/treasure_goblin.gd
- src/gameplay/slime/boss_pudding.gd
- assets/data/run_events.json
- tests/unit/events/events_test.gd

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal`: 테스트는 면제(권고)이며, 유지되는 스크린샷은 면제되지 않는다.*

**Story Type**: Logic
**Required evidence**: `tests/unit/events/events_test.gd` (권고)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-001-slime-field.md`, `production/epics/slime-nodaji/story-002-hero-drop-combat.md`, `production/epics/slime-nodaji/story-005-skill-tree-save.md`
- Unlocks: None
