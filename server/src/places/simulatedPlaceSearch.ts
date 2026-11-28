import type { PlaceQuery, PlaceSearchProvider, ProviderPlace } from "./types.js";

/**
 * Practice places for servers without a Kakao key (architecture OD-K3). No network; the same keyword
 * always gives the same five places, covering a callable, a missing and an invalid number.
 */
const SLOTS: ReadonlyArray<{ suffix: string; phone: (code: string) => string | null; distanceM: number }> = [
  { suffix: "가", phone: (code) => `02-310-${code}`, distanceM: 180 },
  { suffix: "나", phone: (code) => `031-555-${code}`, distanceM: 420 },
  { suffix: "다", phone: () => null, distanceM: 760 },
  { suffix: "라", phone: () => "12", distanceM: 1150 },
  { suffix: "마", phone: (code) => `02-720-${code}`, distanceM: 1830 },
];

function hashOf(text: string): number {
  let hash = 0;
  for (const char of text) hash = (hash * 31 + (char.codePointAt(0) ?? 0)) >>> 0;
  return hash;
}

export class SimulatedPlaceSearch implements PlaceSearchProvider {
  readonly name = "simulated" as const;

  async search(query: PlaceQuery): Promise<ProviderPlace[]> {
    const hash = hashOf(query.keyword);
    const code = String(1000 + (hash % 9000));
    return SLOTS.slice(0, query.limit).map((slot, index) => ({
      providerPlaceId: `sim-${hash.toString(36)}-${index + 1}`,
      name: `연습용 ${query.keyword} ${slot.suffix}`,
      category: "연습용",
      address: `연습시 연습구 연습로 ${index + 1}`,
      distanceM: query.near ? slot.distanceM : null,
      phone: slot.phone(code),
    }));
  }
}
