import { z } from "zod";
import type { Logger } from "../logger.js";
import { type PlaceQuery, PlaceSearchError, type PlaceSearchFailure, type PlaceSearchProvider, type ProviderPlace } from "./types.js";

export interface KakaoLocalOptions {
  apiKey: string;
  /** Defaults to https://dapi.kakao.com. */
  baseUrl?: string;
  /** Injectable for tests; defaults to the global fetch. */
  fetch?: typeof fetch;
  logger: Logger;
}

// Only the documented fields this SPEC uses (research.md R1); unknown fields are dropped.
const KakaoDocument = z.object({
  id: z.string(),
  place_name: z.string(),
  category_name: z.string().optional(),
  phone: z.string().optional(),
  address_name: z.string().optional(),
  road_address_name: z.string().optional(),
  distance: z.string().optional(),
});

const KakaoKeywordResponse = z.object({ documents: z.array(KakaoDocument) });

const blankToNull = (value: string | undefined) => (value && value.trim() ? value.trim() : null);

function toPlace(doc: z.infer<typeof KakaoDocument>): ProviderPlace {
  const category = doc.category_name?.split(" > ").at(-1);
  const distance = doc.distance?.trim() ?? "";
  return {
    providerPlaceId: doc.id,
    name: doc.place_name.trim(),
    category: blankToNull(category),
    address: blankToNull(doc.road_address_name) ?? blankToNull(doc.address_name),
    distanceM: /^\d+$/.test(distance) ? Number(distance) : null,
    phone: blankToNull(doc.phone),
  };
}

/** Kakao Local keyword search (GET /v2/local/search/keyword.json). The REST key stays in this process. */
export class KakaoLocalPlaceSearch implements PlaceSearchProvider {
  readonly name = "kakao" as const;

  constructor(private readonly options: KakaoLocalOptions) {}

  async search(query: PlaceQuery, signal: AbortSignal): Promise<ProviderPlace[]> {
    const url = new URL("/v2/local/search/keyword.json", this.options.baseUrl ?? "https://dapi.kakao.com");
    url.searchParams.set("query", query.keyword);
    url.searchParams.set("size", String(query.limit));
    url.searchParams.set("page", "1");
    if (query.near) {
      url.searchParams.set("x", String(query.near.lng));
      url.searchParams.set("y", String(query.near.lat));
      url.searchParams.set("radius", String(query.radiusM));
      url.searchParams.set("sort", "distance");
    }

    let response: Response;
    try {
      response = await (this.options.fetch ?? fetch)(url, {
        headers: { authorization: `KakaoAK ${this.options.apiKey}` },
        signal,
      });
    } catch {
      throw this.fail(signal.aborted ? "timeout" : "network");
    }
    // The body of a failed answer is never read: it could echo the query back.
    if (!response.ok) throw this.fail("status", response.status);

    let parsed: z.infer<typeof KakaoKeywordResponse>;
    try {
      const result = KakaoKeywordResponse.safeParse(await response.json());
      if (!result.success) throw new Error("format");
      parsed = result.data;
    } catch {
      throw this.fail(signal.aborted ? "timeout" : "format");
    }
    return parsed.documents.filter((doc) => doc.place_name.trim()).map(toPlace);
  }

  /** One warning with the status and kind only — no body, query, coordinates or original message. */
  private fail(kind: PlaceSearchFailure, status?: number): PlaceSearchError {
    this.options.logger.warn({ provider: "kakao", kind, status }, "Place search failed");
    return new PlaceSearchError(kind, status);
  }
}
