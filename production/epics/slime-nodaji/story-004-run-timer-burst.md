# Story 004: 시간제 한 판 + 상자 개봉·마지막 수확·정산 화면

> **Epic**: slime-nodaji
> **Status**: Ready
> **Layer**: N/A (minimal — no layers)
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — 시간제 한 판 + 상자 개봉 연출 + 마지막 수확(쏟아진 전리품 다시 줍기, 5초) + 정산 화면

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (Core loop 3, Player goal & fail state, 확장 설계 원칙), values from the prototype:*

- [ ] 한 판의 길이는 `24 + 4×time 레벨`초이고, HUD에 남은 시간 바와 숫자가 표시된다. 5초 미만이면 빨갛게 바뀐다.
- [ ] HUD에 골드, 상자 등급 이름·진행 바, 모은 전리품 양이 표시된다.
- [ ] 시간이 끝나면 영웅 투입이 멈추고, 상자가 필드 중앙으로 이동하며 커진다 (약 1.1초).
- [ ] 1.3초에 상자가 열리며 화면이 크게 흔들리고, 전리품이 `min(180, 40 + √총합 × 4)`개 쏟아져 필드 바닥에 떨어진다 (보석 10% / 은 27% / 구리 63%, 프로토타입의 개봉 분출 비율).
- [ ] 기본 골드 = `round(모은 양 × 등급 배율)`이고, 상자 위에서 약 1.6초 동안 카운트업된다.
- [ ] **마지막 수확:** 쏟아진 전리품이 바닥에 떨어지면 5초(데이터 파일 값)의 수확 시간이 시작되고 남은 시간이 표시된다. 이 동안 커서 자석(반경 `24 + 5×magnet 레벨`)으로 전리품을 다시 주울 수 있다.
- [ ] **수확 보너스:** 주운 전리품 하나마다 `기본 가치(구리 1·은 4·보석 15) × 1.07^판 수 × (1 + 0.3×coin 레벨)`이 보너스로 더해지고(등급 배율 없음), 누적 보너스가 화면에 표시된다. 수확 시간이 끝나면 못 주운 전리품은 사라진다.
- [ ] 수확이 끝나면 결과 화면이 열리며 모은 전리품, 상자 등급, 배율, 처치한 슬라임, 기본 골드, 수확 보너스, 획득 골드(= 기본 + 보너스)를 보여준다. '스킬 트리로'와 '바로 재출격'을 고를 수 있고, 키보드 포커스로도 선택된다.
- [ ] 하드 실패는 없다: 항상 개봉하고 낮은 등급·배율을 받는다. 획득 골드(기본 + 보너스)가 보유 골드에 더해지고(저장은 story 005), 판 결과는 `RunResult` 데이터 객체 하나로 만들어 시그널로 내보낸다.
- [ ] HUD, 개봉 장면, 마지막 수확 장면, 결과 화면 각각의 스크린샷이 유지된다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `beginBurst`, `updateBurst`, `finishRun`, `hud`다. 마지막 수확은 프로토타입에 없는 기능이다 (브리프 1단계 MVP에 추가, 2026-10-27).
- 수확 시간(5초), 수확 보너스 계산(코인 가치 공식 재사용, 등급 배율 없음), 분출 비율은 데이터 파일에 둔다. 보너스 공식은 사용자 결정("기본 골드 + 주운 만큼 보너스")을 따른 기본값이며 조정 가능하다.
- 자석과 코인 비행은 story 003의 것을 재사용한다. 바닥 전리품의 가시성(크기·반짝임)도 003의 처리를 따른다.
- **확장 설계 원칙 (브리프):** 판 결과는 `RunResult`(맵 id, 기본 골드, 수확 보너스, 상자 등급, 처치 수, 보스 처치 여부, 드롭 목록)로 만들어 시그널로 내보내고, 골드 적용은 그 결과를 받는 처리기가 맡는다. 2단계의 상점·장비·카드·도감이 처리기를 추가해 붙을 수 있게 한다. 맵 id는 1단계에서 하나뿐이어도 필드로 둔다.
- 화면은 640×360 기준이며, 글꼴은 도트 느낌의 폰트를 쓴다 (프로토타입은 Jua, Gowun Dodum, Silkscreen).
- 타이틀 화면은 이 스토리의 범위 밖이다. 최소한의 시작 버튼만 둔다.
- 범위가 커져 추정을 M에서 L로 올렸다. 구현 중 너무 크면 `/create-stories`로 수확을 별도 스토리로 나눈다.

---

## Out of Scope

- story 005: 스킬 트리 화면, 저장, 초기화
- story 007: 이벤트 배너
- 2단계 기능(상점·장비·카드·도감)의 결과 처리기

---

## Files

- src/ui/hud/hud.gd
- src/ui/hud/hud.tscn
- src/ui/result/result_screen.gd
- src/ui/result/result_screen.tscn
- src/gameplay/run/run_controller.gd
- src/gameplay/run/run_result.gd
- src/gameplay/run/final_harvest.gd
- src/gameplay/chest/chest_burst.gd
- assets/data/run.json

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: 터치한 화면(HUD, 개봉 장면, 마지막 수확 장면, 결과 화면) 각각의 유지되는 스크린샷 → `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/slime-nodaji/story-003-magnet-chest-tiers.md`
- Unlocks: `production/epics/slime-nodaji/story-005-skill-tree-save.md`
