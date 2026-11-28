import { describe, expect, it } from "vitest";
import { loadConfig } from "./config.js";

describe("KAKAO_LOCAL_BASE_URL (SPEC-PLACE-001 sync audit 1 I3)", () => {
  it("accepts https and loopback http only, without echoing the value", () => {
    expect(loadConfig({}).KAKAO_LOCAL_BASE_URL).toBe("https://dapi.kakao.com");
    expect(loadConfig({ KAKAO_LOCAL_BASE_URL: "https://kakao-proxy.example" }).KAKAO_LOCAL_BASE_URL).toBe(
      "https://kakao-proxy.example",
    );
    for (const local of ["http://127.0.0.1:9", "http://localhost:8080/"]) {
      expect(loadConfig({ KAKAO_LOCAL_BASE_URL: local }).KAKAO_LOCAL_BASE_URL).toBe(local);
    }

    for (const bad of ["http://marker-host-71c2.example", "ftp://marker-host-71c2.example", "marker-host-71c2", "http://localhost.marker-host-71c2.example"]) {
      let message = "";
      expect(() => {
        try {
          loadConfig({ KAKAO_LOCAL_BASE_URL: bad, KAKAO_REST_API_KEY: "marker-key-71c2" });
        } catch (error) {
          message = error instanceof Error ? error.message : String(error);
          throw error;
        }
      }, bad).toThrow();
      expect(message).toContain("KAKAO_LOCAL_BASE_URL");
      expect(message).not.toContain("marker-host-71c2");
      expect(message).not.toContain("marker-key-71c2");
    }
  });
});
