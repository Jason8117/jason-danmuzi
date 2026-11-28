/** What the place search asks a provider for (SPEC-PLACE-001 design.md D2). */
export interface PlaceQuery {
  keyword: string;
  /** Already rounded to 3 decimals (about 100 m) before it reaches a provider. */
  near?: { lat: number; lng: number };
  radiusM: number;
  limit: number;
}

/** A place as the provider gave it, before the number check. */
export interface ProviderPlace {
  providerPlaceId: string;
  name: string;
  category: string | null;
  address: string | null;
  distanceM: number | null;
  phone: string | null;
}

export interface PlaceSearchProvider {
  readonly name: "kakao" | "simulated";
  search(query: PlaceQuery, signal: AbortSignal): Promise<ProviderPlace[]>;
}

export type PhoneCheck = "ok" | "invalid" | "blocked" | "missing";

/** One candidate in the POST /v1/places/search response (design.md D1). */
export interface PlaceCandidate {
  id: string;
  name: string;
  category: string | null;
  address: string | null;
  distanceM: number | null;
  phone: string | null;
  phoneNumber: string | null;
  phoneCheck: PhoneCheck;
}

export type PlaceSearchFailure = "timeout" | "network" | "status" | "format" | "unexpected";

/**
 * The only error the place search lets out. It never carries a cause, the provider's message or its
 * response body, so a search term or a result cannot reach a log through it (REQ-004, REQ-005).
 */
// @MX:ANCHOR: [AUTO] Every place search failure crosses the HTTP boundary as this type; the error handler turns it into a bare 502.
// @MX:REASON: Adding a cause or copying a message here would let search terms and results reach request.log.error (epic D-8).
// @MX:SPEC: SPEC-PLACE-001
export class PlaceSearchError extends Error {
  constructor(
    readonly kind: PlaceSearchFailure,
    readonly status?: number,
  ) {
    super("Place search failed");
    this.name = "PlaceSearchError";
  }
}
