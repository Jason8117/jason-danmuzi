import { checkTargetNumber } from "../domain/phone.js";
import { type PlaceCandidate, type PlaceQuery, PlaceSearchError, type PlaceSearchProvider, type ProviderPlace } from "./types.js";

export interface PlaceSearchRequest {
  query: string;
  near?: { lat: number; lng: number };
}

export interface PlaceSearchResult {
  source: "kakao" | "simulated";
  places: PlaceCandidate[];
}

export interface PlaceSearch {
  readonly source: "kakao" | "simulated";
  search(request: PlaceSearchRequest): Promise<PlaceSearchResult>;
}

const LIMIT = 5;
const RADIUS_M = 2000;

/** About 100 m: the server never forwards a finer position than this (design.md D2). */
const round3 = (value: number) => Math.round(value * 1000) / 1000;

function toCandidate(place: ProviderPlace): PlaceCandidate {
  const base = {
    id: place.providerPlaceId,
    name: place.name,
    category: place.category,
    address: place.address,
    distanceM: place.distanceM,
    phone: place.phone,
  };
  if (place.phone === null) return { ...base, phoneNumber: null, phoneCheck: "missing" };
  const check = checkTargetNumber(place.phone);
  return check.kind === "ok" ? { ...base, phoneNumber: check.e164, phoneCheck: "ok" } : { ...base, phoneNumber: null, phoneCheck: check.kind };
}

/**
 * Fills the provider query, applies the time limit and judges every number with checkTargetNumber.
 * Holds no state: the same request twice calls the provider twice (REQ-004).
 */
// @MX:ANCHOR: [AUTO] The one path every place search takes, whichever provider is wired; numbers are judged here, not in providers.
// @MX:REASON: Wrapping every failure as a fresh, cause-less PlaceSearchError is what keeps results out of logs (design.md D2, D4).
// @MX:SPEC: SPEC-PLACE-001
export function createPlaceSearch(provider: PlaceSearchProvider, { timeoutMs = 5000 }: { timeoutMs?: number } = {}): PlaceSearch {
  return {
    source: provider.name,
    async search(request) {
      const query: PlaceQuery = {
        keyword: request.query.trim(),
        limit: LIMIT,
        radiusM: RADIUS_M,
        ...(request.near ? { near: { lat: round3(request.near.lat), lng: round3(request.near.lng) } } : {}),
      };
      const controller = new AbortController();
      let timer: NodeJS.Timeout | undefined;
      // Also settles when a provider ignores the signal, so a hung request cannot outlive the limit.
      const deadline = new Promise<never>((_resolve, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(new PlaceSearchError("timeout"));
        }, timeoutMs);
      });
      try {
        const found = await Promise.race([provider.search(query, controller.signal), deadline]);
        return { source: provider.name, places: found.map(toCandidate) };
      } catch (error) {
        // Re-created, never re-thrown: nothing from the original error object survives.
        if (error instanceof PlaceSearchError) throw new PlaceSearchError(error.kind, error.status);
        if (controller.signal.aborted) throw new PlaceSearchError("timeout");
        throw new PlaceSearchError("unexpected");
      } finally {
        clearTimeout(timer);
      }
    },
  };
}
