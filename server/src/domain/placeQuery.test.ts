import { describe, expect, it } from "vitest";
import { PHONE_PLACEHOLDER } from "./intake.js";
import { cleanPlaceQuery, placeQueryFor } from "./placeQuery.js";

describe("place query rules (SPEC-PLACE-001 0.2.0)", () => {
  // AC-023 / REQ-023 — design.md D6 shared table; packages/kolbi_core/test/places_test.dart pins the same column.
  it.each([
    ["강남역 근처 파스타집, 금요일 7시 2명 예약해 줘", "강남역 파스타집"],
    ["근처 약국 오늘 몇 시까지 하는지 물어봐 줘", "약국"],
    ["내일 치과 예약 바꿔 줘", "치과"],
    ["내 주변 세탁소 문의해 줘", "세탁소"],
    ["가까운 꽃집에 장미 있는지 알아봐 줘", "꽃집"],
    ["해 줘", null],
    ["근처 치과 내일 오전 예약해 줘", "치과"],
    ["근처 미용실 토요일 오후 3시반에 예약해 줘", "미용실"],
    ["다음 주 수요일 저녁에 근처 고깃집 4명 예약해 줘", "고깃집"],
    ["지금 근처 약국 몇 시까지 하는지 물어봐 줘", "약국"],
    ["12월 24일 저녁 강남역 이탈리안 레스토랑 예약해 줘", "강남역 이탈리안 레스토랑"],
    ["주말 아침에 동네 빵집 몇 시에 여는지 물어봐 줘", "동네 빵집"],
    ["주말 오후 3시 반에 미용실 예약 가능한지 물어봐 줘", "미용실"],
    ["근처 미용실 3시 반에 예약해 줘", "미용실"],
    ["오후 2시 30분에 근처 네일샵 예약해 줘", "네일샵"],
    ["10일 오전 11시에 시청 앞 꽃집 예약해 줘", "시청 앞 꽃집"],
    ["다음 주 화요일 저녁에 동네 치과 예약해 줘", "동네 치과"],
    ["토요일 오전 10시 반쯤 근처 카페 예약해 줘", "카페"],
    ["반찬가게 3시 반까지 하는지 물어봐 줘", "반찬가게"],
    ["엄마한테 저녁에 늦는다고 전화해 줘", "엄마"],
    ["김 대리님께 회의 30분 늦는다고 전해 줘", "김 대리님"],
    ["친구에게 내일 못 간다고 연락해 줘", "친구"],
  ])("place query vectors shared with the app: %s", (text, expected) => {
    expect(placeQueryFor(text, null)).toBe(expected);
  });

  it("uses the name when there is one, and skips masked numbers", () => {
    expect(placeQueryFor("라 파스타에 금요일 예약해 줘", "라 파스타")).toBe("라 파스타");
    expect(placeQueryFor("근처 약국", "근처 약국")).toBe("약국");
    expect(placeQueryFor(`${PHONE_PLACEHOLDER}로 내일 오전 치과 예약`, null)).toBe("치과");
    expect(placeQueryFor(`${"가".repeat(40)} 예약해 줘`, null)).toBe("가".repeat(30));
  });

  it("cleans a brain-provided place query", () => {
    expect(cleanPlaceQuery("치과")).toBe("치과");
    expect(cleanPlaceQuery("  근처   치과 010-1234-5678 ")).toBe("치과");
    expect(cleanPlaceQuery(`주변 ${PHONE_PLACEHOLDER}`)).toBe("");
    expect(cleanPlaceQuery("   ")).toBe("");
    expect(cleanPlaceQuery(undefined)).toBe("");
    expect(cleanPlaceQuery("😀".repeat(40))).toBe("😀".repeat(30));
  });
});
