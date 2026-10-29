# Story 005: 스킬 트리 16노드 + 골드 소비 + 저장

> **Epic**: slime-nodaji
> **Status**: Complete
> **Layer**: N/A (minimal — no layers)
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5 — 스킬 트리 16노드 + 골드 소비 + 저장 (프로토타입 `NODES` 값 그대로, 데이터 파일로 분리)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop 4, Player goal & fail state), values from the prototype:*

- [ ] 16개 노드(hero, dmg, spd, archer, arrows, land, barb, magnet, coin, golden, chest, boss, time, density, rain, goblin)가 프로토타입의 `max`, `base`, `g`, `req`, 격자 위치 그대로 데이터 파일에 정의된다.
- [ ] 비용은 `round(base × g^현재 레벨)`이고, 선행 노드 레벨이 1 이상이어야 구매할 수 있다. 최대 레벨이면 MAX로 표시된다.
- [ ] 골드가 충분하면 구매 시 골드가 차감되고 레벨이 1 오른다. 부족하면 '골드가 N 부족합니다' 메시지가 나온다.
- [ ] 노드 상태가 구분된다: 구매 가능(금테), MAX, 잠김(흐림). 선행 노드와는 선으로 이어지고, 습득한 선은 색이 바뀐다.
- [ ] 레벨이 능력치로 반영된다: 기사 `2+hero`, 공격력 `5×(1+0.25×dmg)`, 쿨다운 `0.75/(1+0.15×spd)`, 화살 `1+arrows`, 착지 피해 `8+10×land`, 착지 범위 `23+3.5×land`, 자석 `24+5×magnet`, 코인 `1+0.3×coin`, 시간 `24+4×time`, 슬라임 수 `12+4×density`, 황금 `0.015+0.02×golden`, 비 `0.3×rain`, 상자 보너스 `0.1×chest`.
- [ ] 골드, 판 수, 노드 레벨, 최고 기록이 `user://`에 저장되고 재시작 후 복원된다. 저장 파일이 없거나 깨져 있으면 새 게임으로 시작한다.
- [ ] 저장 형식은 브리프의 확장 설계 원칙을 따른다: 최상위에 버전 필드가 있고, 데이터는 시스템별 하위 키(`meta`: 골드·판 수·최고 기록, `skill_tree`: 노드 레벨)로 나뉜다. 불러올 때 이전 버전은 버전별 마이그레이션 함수로 올리고, 없는 키는 기본값으로 채우며, 모르는 키(이후 `maps`·`equipment`·`cards`·`collection` 등)는 지우지 않고 그대로 다시 저장한다.
- [ ] 초기화 버튼은 2.5초 안에 두 번 눌러야 동작하고, 첫 번째 누름은 확인 문구만 보여준다.
- [ ] 트리 화면 하단에 다음 판 요약(시간, 영웅 수, 최고 기록)이 보인다.
- [ ] 트리 화면의 스크린샷이 유지된다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `NODES`, `cost`, `unlocked`, `stats`, `renderTree`, 저장 코드(`KEY`)다.
- 노드 정의는 `assets/data/skill_tree.json`에, 능력치 계산은 별도 클래스에 두어 단위 테스트가 가능하게 한다 (싱글톤 대신 의존성 주입).
- 저장 형식에는 버전 필드를 둔다. 하위 키 구성·마이그레이션·모르는 키 보존은 `design/game-brief.md`의 "확장 설계 원칙 — 저장 데이터"를 따른다 (2026-10-27 추가). 1단계의 마이그레이션은 버전 1 하나뿐이어도 버전별 함수 자리를 둔다.
- **단위 변환 (2026-10-27):** 착지 범위와 자석 반경은 공간 단위 값이라 1280×720 기준 프로토타입 값의 0.5배다 (`46+7×land` → `23+3.5×land`, `34+10×magnet` → `17+5×magnet`). 피해·시간·배율 등 비공간 값은 그대로다. 단, 자석 기본 반경은 플레이 테스트로 17에서 24로 올려 확정했다 (`design/game-brief.md`의 "손맛 조정으로 프로토타입과 달라진 값").
- 능력치 계산(`PlayerStats`)은 이미 각 시스템이 가진 공식 함수를 불러 쓰고, 어느 시스템도 갖지 않은 값(화살, 황금, 비)만 `assets/data/skill_tree.json`의 `stats`에 둔다. 자석 장갑 노드 설명의 증가량도 같은 이유로 `+10`에서 `+5`로 옮겼다.

---

## Out of Scope

- story 006, 007: 노드가 해금하는 영웅·이벤트의 동작 (이 스토리는 레벨을 올리고 저장하는 데까지)
- 클라우드 세이브

---

## Files

- src/meta/skill_tree.gd — node rules: cost, unlock, purchase, node state (pure statics)
- src/meta/player_stats.gd — next-run stats from the levels, reusing each system's own formulas
- src/meta/save_data.gd — versioned save: migration, defaults, unknown keys kept, corrupt file = new game
- src/ui/skill_tree/skill_tree_screen.gd (+ .tscn)
- src/gameplay/run/run_scene.gd — loads/saves the SaveData, opens the tree, applies the run result
- assets/data/skill_tree.json — 16 nodes, stats, save settings, tree layout, texts
- tests/integration/skill-tree/skill_tree_save_test.gd (+ .uid) — 16 tests (written although qa.level is minimal, at the user's request)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/skill-tree/skill_tree_save_test.gd` (권고) + 트리 화면 스크린샷(필수) → `production/qa/evidence/`

**Status**: [x] Created — `tests/integration/skill-tree/skill_tree_save_test.gd`, `production/qa/evidence/story-005-skill-tree-save/` (트리 화면 스크린샷 1280×720, `stamp.txt`)

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-004-run-timer-burst.md`
- Unlocks: `production/epics/slime-nodaji/story-007-run-events.md`

---

## Completion Notes
**Completed**: 2026-10-29
**Criteria**: 10/10 passing (트리 구매, 저장 복원, 깨진·없는 저장 파일, 초기화 두 번 누르기, 레벨의 능력치 반영은 사용자가 직접 플레이로 확인)
**Deviations**: ADVISORY — `src/ui/skill_tree/skill_tree_screen.gd`의 화면 배치 상수(골드 라벨 너비, 간격, 테두리·모서리)와 `src/meta/skill_tree.gd`의 `format_amount` 표시 단위는 코드에 하드코딩 (게임플레이 값 아님; 게임플레이 값은 모두 `assets/data/skill_tree.json`). 참고 — 자석 장갑 노드 설명의 증가량을 640×360 기준에 맞춰 `+10`에서 `+5`로 옮김.
**Test Evidence**: `tests/integration/skill-tree/skill_tree_save_test.gd` (16개, qa.level minimal에서는 면제이지만 작성함; 저장 코드를 일부러 망가뜨려 관련 테스트가 실패하는 것을 확인), `production/qa/evidence/story-005-skill-tree-save/` (트리 화면 스크린샷, 스탬프 일치)
**Reviewed by**: self, no independent review (엔진 API 점검은 별도로 실행, 지적은 반영)
