# Story 007: 이벤트 4종 (황금 슬라임·슬라임 비·보물 고블린·대왕 푸딩)

> **Epic**: slime-nodaji
> **Status**: In Progress
> **Layer**: N/A (minimal — no layers)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-29

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

*수치는 `assets/data/run_events.json`(아래 `golden.*`, `rain.*`, `goblin.*`, `boss.*`, `banner.*`)이 기준이다. 판 수에 따른 체력 배율은 `slime_field.json`의 `run_scale_base`, 해금 확률은 `skill_tree.json`의 `stats.golden_base`·`golden_per_level`·`rain_per_level`이다. 문서의 값이 아니라 파일의 값이 맞다.*

- [x] 황금 슬라임: 스폰 시 확률 `stats.golden_base + stats.golden_per_level × golden 레벨`로 나온다. 프로토타입처럼 golden 레벨 0(노드 미구매)이어도 `stats.golden_base` 확률로 나온다. 체력 `golden.base_hp × run_scale_base^판 수`, 처치 시 코인 `golden.kill_coins`개를 풍성하게 떨어뜨린다 (보석·은 비율은 `rich_coin_kind_chance`, 나머지 구리).
- [x] 슬라임 비: 확률 `stats.rain_per_level × rain 레벨`로 한 판에 한 번, 시각은 `rain.window_start`초 이후~종료 `rain.window_end_margin`초 전 사이 무작위다. 슬라임 `rain.count`마리가 높이 `rain.height_min`~`rain.height_max`에서 떨어지고 `banner.text.rain` 배너가 나온다.
- [x] 보물 고블린: `goblin 레벨`이 1 이상일 때 `goblin.window_start`초~시간의 `goblin.window_end_ratio` 사이 무작위 시각에 필드 가장자리에서 나온다. 체력 `goblin.base_hp × run_scale_base^판 수`, 영웅에게서 도망친다.
- [x] 고블린은 피격 시 `goblin.hit_drop_chance` 확률로 코인(`goblin.hit_drop_coins`개)을 떨어뜨리고, 처치 시 코인 `goblin.kill_coins`개를 떨어뜨린다. `goblin.life`초 후에는 화면 밖으로 사라진다.
- [x] 대왕 푸딩: `boss 레벨`이 1 이상일 때 한 판의 `boss.time_ratio` 시점에 높이 `boss.drop_height`에서 필드 중앙으로 떨어진다. 반경 `boss.radius`, 체력 `boss.base_hp × run_scale_base^판 수`이다.
- [x] 보스는 착지 시 착지 충격과 화면 흔들림(`boss.landing_shake`)을 내고, 처치 시 코인 `boss.kill_coins`개(풍성 드롭)와 `banner.text.boss_killed` 배너를 낸다.
- [x] 해당 노드를 사지 않았으면 슬라임 비·보물 고블린·대왕 푸딩은 나오지 않는다. **황금 슬라임만 예외**로, 노드 없이도 `stats.golden_base` 확률로 나온다(프로토타입과 같음).
- [x] 이벤트별 배너가 `banner.duration`초 동안 크게 나타났다 사라진다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `spawnSlime`(종류별 값), `update`의 이벤트 구간, `kill`, `hurt`, 고블린 AI다.
- 이벤트 시각은 판이 시작될 때 한 번 정한다 (프로토타입 `newRun`).
- **단위 변환 (2026-10-27):** 낙하 높이(200~600 → 100~300, 500 → 250), 보스 반경(40 → 20), 보스 착지 흔들림(12 → 6px)은 1280×720 기준 프로토타입 값의 0.5배다. 고블린의 도망 속도 등 다른 공간 단위 값도 구현 때 같은 기준(0.5배)으로 옮긴다. 체력·확률·시간·코인 개수는 그대로다.
- 이벤트 수치도 데이터 파일(`assets/data/run_events.json`)에서 읽는다.

---

## Out of Scope

- story 005: 이벤트를 해금하는 노드의 구매 UI

---

## Files

src/gameplay/hero/berserker.gd
src/gameplay/hero/hero.gd
src/gameplay/hero/hero_squad.gd
src/gameplay/hero/landing_impact.gd
src/gameplay/run/run_scene.gd
src/gameplay/slime/slime.gd
src/gameplay/slime/slime_field.gd
assets/data/run_events.json
src/gameplay/events/run_events.gd
src/gameplay/slime/boss_pudding.gd
src/gameplay/slime/golden_slime.gd
src/gameplay/slime/treasure_goblin.gd
src/ui/banner/event_banner.gd
tests/unit/events/events_test.gd

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*`qa.level: minimal`: 테스트는 면제(권고)이며, 유지되는 스크린샷은 면제되지 않는다.*

**Story Type**: Logic
**Required evidence**: `tests/unit/events/events_test.gd` (권고)

**Status**: [x] Created — `tests/unit/events/events_test.gd` 34개 통과 (전체 173개 통과). 스크린샷 `production/qa/evidence/story-007-run-events/`

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-001-slime-field.md`, `production/epics/slime-nodaji/story-002-hero-drop-combat.md`, `production/epics/slime-nodaji/story-005-skill-tree-save.md`
- Unlocks: None
