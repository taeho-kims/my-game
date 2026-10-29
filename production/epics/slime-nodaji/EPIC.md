# Epic: slime-nodaji

> **Source**: `design/game-brief.md`
> **Tier**: minimal (no GDDs, ADRs or layers — the brief is the design record)

## Goal

영웅을 하늘에서 떨어뜨려 슬라임을 쓸고, 커서로 전리품을 쓸어 담아 상자를 터뜨린 뒤, 그 골드로 영웅단을 키워 다시 출격하는 짧은 런형 수집 게임.

## Scope (Brief MVP)

1. 영웅 강하 + 착지 충격 + 기사 자동전투 (손맛의 핵심)
2. 슬라임 스폰/이동과 코인 드롭, 판마다 스케일 `1.07^판 수`
3. 커서 자석 코인 수집 + 상자 5등급과 배율
4. 시간제 한 판 + 상자 개봉 연출 + 마지막 수확(5초) + 정산 화면
5. 스킬 트리 16노드 + 골드 소비 + 저장
6. 궁수·광전사 영웅 타입 + 숫자키 1·2·3 선택 (핫바)
7. 트리가 해금하는 이벤트 4종

수치는 프로토타입 `slime-nodaji.html`(`NODES`, `TIERS`, `1.07^runs` 등)의 값을 그대로 유지한다.

## Build order

1. 슬라임 필드 → 강하·착지 충격·기사 자동전투 → 커서 자석 수집 (손맛 검증)
2. 상자 등급·배율 + 시간제 한 판 + 개봉 + 마지막 수확 + 정산
3. 스킬 트리 + 저장 + 판마다 스케일
4. 궁수·광전사 + 핫바
5. 이벤트 4종

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 슬라임 필드와 코인 드롭 | Logic | Complete | N/A |
| 002 | 영웅 강하·착지 충격·기사 자동전투 | Visual/Feel | Complete | N/A |
| 003 | 커서 자석 수집 + 상자 5등급·배율 | Logic | Complete | N/A |
| 004 | 시간제 한 판 + 상자 개봉·마지막 수확·정산 화면 | UI | Complete | N/A |
| 005 | 스킬 트리 16노드 + 골드 소비 + 저장 | Integration | Complete | N/A |
| 006 | 궁수·광전사 + 핫바 | Logic | Complete | N/A |
| 007 | 이벤트 4종 | Logic | Complete | N/A |
