# Story 004: 시간제 한 판 + 상자 개봉·마지막 수확·정산 화면

> **Epic**: slime-nodaji
> **Status**: In Progress
> **Layer**: N/A (minimal — no layers)
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-28

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

- [ ] 한 판의 길이는 `assets/data/run.json`의 `run.base_time + run.time_per_level × time 레벨`초이고, HUD에 남은 시간 바와 숫자가 표시된다. `run.low_time_threshold` 미만이면 빨갛게 바뀐다.
- [ ] HUD에 골드, 상자 등급 이름·진행 바, 모은 전리품 양이 표시된다.
- [ ] 시간이 끝나면 영웅 투입이 멈추고, 상자가 필드 중앙으로 이동하며 커진다 (`burst.move_time`).
- [ ] `burst.open_time`에 상자가 열리며 화면이 크게 흔들리고(`burst.open_shake`), 전리품이 `rain.count_base`·`rain.count_per_sqrt_total`·`rain.count_max`로 정해진 개수만큼 쏟아져 필드 바닥에 떨어진다 (종류 비율은 `rain.kind_chance`).
- [ ] 기본 골드 = `round(모은 양 × 등급 배율)`이고, 상자 위에서 `burst.count_up_time` 동안 카운트업된다.
- [ ] **마지막 수확:** 쏟아진 전리품이 바닥에 떨어지면 `harvest.duration`의 수확 시간이 시작되고 남은 시간이 표시된다. 이 동안 커서 자석(반경은 `assets/data/chest_tiers.json`의 magnet 값)으로 전리품을 다시 주울 수 있다.
- [ ] **수확 보너스:** 주운 전리품 하나마다 `기본 가치 × 판 스케일 × 코인 레벨 보정`(코인 값과 보정은 `assets/data/slime_field.json`의 coin 값, 판 스케일은 `SlimeField.coin_value`와 같은 식)이 보너스로 더해지고(등급 배율 없음), 누적 보너스가 화면에 표시된다. 수확 시간이 끝나면 못 주운 전리품은 사라진다.
- [ ] 수확이 끝나면 결과 화면이 열리며 모은 전리품, 상자 등급, 배율, 처치한 슬라임, 기본 골드, 수확 보너스, 획득 골드(= 기본 + 보너스)를 보여준다. '스킬 트리로'와 '바로 재출격'을 고를 수 있고, 키보드 포커스로도 선택된다.
- [ ] 하드 실패는 없다: 항상 개봉하고 낮은 등급·배율을 받는다. 획득 골드(기본 + 보너스)가 보유 골드에 더해지고(저장은 story 005), 판 결과는 `RunResult` 데이터 객체 하나로 만들어 시그널로 내보낸다.
- [ ] HUD, 개봉 장면, 마지막 수확 장면, 결과 화면 각각의 스크린샷이 유지된다.

---

## Implementation Notes

- 값의 출처는 프로토타입의 `beginBurst`, `updateBurst`, `finishRun`, `hud`다. 마지막 수확은 프로토타입에 없는 기능이다 (브리프 1단계 MVP에 추가, 2026-10-27).
- 수확 시간(`harvest.duration`), 분출 비율(`rain.kind_chance`)과 개봉 연출 값은 `assets/data/run.json`에 두고, 수확 보너스는 코인 가치 공식(`SlimeField.coin_value`)을 재사용한다 (등급 배율 없음).
- **프로토타입과 다른 점 (의도적):** 상자 총합은 시간이 끝나는 순간이 아니라 개봉 순간(`burst.open_time`)에 확정한다 (날아가던 코인이 버려지지 않게). 카운트업은 프레임당이 아니라 초당 증가량(`burst.count_up_min_rate`)을 쓴다. **쏟아진 전리품은 필드 바닥이 아니라 상자 중심의 도넛형 링에 깔린다** (플레이 후 변경, `assets/data/run.json`의 `ring` 값; 보석은 바깥쪽 `ring.gem_band` 구간, 퍼지는 속도는 `ring.spread_speed`) — 커서를 상자 주위로 돌려 쓸어 담는다. 목록은 `design/game-brief.md`의 "손맛 조정으로 프로토타입과 달라진 값". 바닥 기준 분출 함수(`ChestBurst.step_loot`, `settle_loot`)와 `rain`의 해당 키는 더 이상 게임에서 쓰지 않지만 테스트와 함께 남겨 뒀다. 수확은 모든 코인이 바닥에 닿거나 `harvest.start_max_wait`가 지나면 시작한다. 보너스 공식은 사용자 결정("기본 골드 + 주운 만큼 보너스")을 따른 기본값이며 조정 가능하다.
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

- src/ui/hud/hud.gd (+ .tscn)
- src/ui/result/result_screen.gd (+ .tscn)
- src/gameplay/run/run_controller.gd
- src/gameplay/run/run_result.gd
- src/gameplay/run/final_harvest.gd
- src/gameplay/run/run_scene.gd (+ .tscn) — entry scene wiring the run, dev options (`-- --autostart --run-seconds=N --auto-drop=N --runs=N`)
- src/gameplay/run/run_view.gd — burst dim and raining loot
- src/gameplay/chest/chest_burst.gd
- src/gameplay/magnet/magnet.gd — `set_target(position, sink)` for the final harvest
- assets/data/run.json (incl. `ui` section: layout, colors, texts)
- tests/unit/run/run_result_test.gd — 44 tests (written although qa.level is minimal, at the user's request)
- tests/integration/run/run_data_test.gd — 11 tests

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
