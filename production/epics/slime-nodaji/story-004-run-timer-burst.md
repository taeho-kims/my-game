# Story 004: 시간제 한 판 + 상자 개봉·정산 화면

> **Epic**: slime-nodaji
> **Status**: Ready
> **Layer**: N/A (minimal — no layers)
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — 시간제 한 판 + 상자 개봉 연출과 정산 화면

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop 3, Player goal & fail state), values from the prototype:*

- [ ] 한 판의 길이는 `24 + 4×time 레벨`초이고, HUD에 남은 시간 바와 숫자가 표시된다. 5초 미만이면 빨갛게 바뀐다.
- [ ] HUD에 골드, 상자 등급 이름·진행 바, 모은 전리품 양이 표시된다.
- [ ] 시간이 끝나면 자석과 영웅 투입이 멈추고, 상자가 필드 중앙으로 이동하며 커진다 (약 1.1초).
- [ ] 1.3초에 상자가 열리며 화면이 크게 흔들리고, 코인이 `min(180, 40 + √총합 × 4)`개 분출한다.
- [ ] 획득 골드 = `round(모은 양 × 등급 배율)`이고, 상자 위에서 약 1.6초 동안 카운트업된다.
- [ ] 3.8초에 결과 화면이 열리며 모은 전리품, 상자 등급, 배율, 처치한 슬라임, 획득 골드를 보여준다.
- [ ] 결과 화면에서 '스킬 트리로'와 '바로 재출격'을 고를 수 있고, 키보드 포커스로도 선택된다.
- [ ] 못 채워도 하드 실패는 없다: 항상 개봉하고 낮은 등급·배율을 받는다.
- [ ] 획득 골드가 보유 골드에 더해진다 (저장은 story 005).
- [ ] 한 판 진행 중 HUD와 결과 화면 각각의 스크린샷이 유지된다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `beginBurst`, `updateBurst`, `finishRun`, `hud`다.
- 화면은 640×360 기준이며, 글꼴은 도트 느낌의 폰트를 쓴다 (프로토타입은 Jua, Gowun Dodum, Silkscreen).
- 타이틀 화면은 이 스토리의 범위 밖이다. 최소한의 시작 버튼만 둔다.

---

## Out of Scope

- story 005: 스킬 트리 화면, 저장, 초기화
- story 007: 이벤트 배너

---

## Files

- src/ui/hud/hud.gd
- src/ui/hud/hud.tscn
- src/ui/result/result_screen.gd
- src/ui/result/result_screen.tscn
- src/gameplay/run/run_controller.gd
- src/gameplay/chest/chest_burst.gd

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: 터치한 화면(HUD, 개봉 장면, 결과 화면) 각각의 유지되는 스크린샷 → `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-003-magnet-chest-tiers.md`
- Unlocks: `production/epics/slime-nodaji/story-005-skill-tree-save.md`
