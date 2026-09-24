import { afterEach, beforeEach, describe, expect, mock, spyOn, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  buildCodexEntry,
  buildCursorEntry,
  codexSegments,
  fetchCodexAccounts,
  formatEntryValues,
  normalizeCacheData,
} from "./ai-usage";

const codexEntry = (usedPercent: number) => {
  const payload = {
    plan_type: "pro",
    rate_limit: {
      primary_window: {
        used_percent: usedPercent,
        limit_window_seconds: 18_000,
        reset_at: Math.floor(Date.now() / 1000) + 60 * 60,
      },
      secondary_window: null,
    },
  };

  return buildCodexEntry(payload, {
    status: 200,
    headers: new Headers(),
    payload,
  });
};

test("labels codex segments with profile names and highlights the active account", () => {
  const personalEntry = codexEntry(10);
  const workEntry = codexEntry(20);

  const segments = codexSegments([
    { name: "personal", active: false, entry: personalEntry },
    { name: "work", active: true, entry: workEntry },
  ]);

  expect(segments.map((segment) => segment.label)).toEqual(["personal", "work"]);
  expect(segments[1].labelColor).not.toBe(segments[0].labelColor);
  expect(segments.map((segment) => segment.entry)).toEqual([personalEntry, workEntry]);
});

test("renders a single unnamed codex account without a label", () => {
  const segments = codexSegments([{ name: null, active: true, entry: codexEntry(10) }]);

  expect(segments).toHaveLength(1);
  expect(segments[0].label).toBeNull();
});

test("restores per-account codex entries from a cached payload", () => {
  const cache = {
    codexAccounts: [
      { name: "work", active: true, entry: codexEntry(30) },
      { name: null, active: false, entry: codexEntry(40) },
    ],
    updatedAt: 123,
  };

  const restored = normalizeCacheData(JSON.parse(JSON.stringify(cache)));

  expect(restored.codexAccounts?.map((account) => [account.name, account.active])).toEqual([
    ["work", true],
    [null, false],
  ]);
  expect(restored.codexAccounts?.[0].entry.quotas).toEqual(cache.codexAccounts[0].entry.quotas);
});

test("classifies a weekly-only primary Codex window", () => {
  const payload = {
    plan_type: "pro",
    rate_limit: {
      primary_window: {
        used_percent: 46,
        limit_window_seconds: 604_800,
        reset_at: 1_784_354_524,
      },
      secondary_window: null,
    },
  };

  const entry = buildCodexEntry(payload, {
    status: 200,
    headers: new Headers(),
    payload,
  });

  expect(entry.quotas).toEqual([
    {
      kind: "weekly",
      used: 46,
      remaining: 54,
      resetAt: 1_784_354_524,
    },
  ]);
});

test("orders Codex windows by duration instead of response position", () => {
  const payload = {
    plan_type: "pro",
    rate_limit: {
      primary_window: {
        used_percent: 40,
        limit_window_seconds: 604_800,
        reset_at: 2_000,
      },
      secondary_window: {
        used_percent: 25,
        limit_window_seconds: 18_000,
        reset_at: 1_000,
      },
    },
  };

  const entry = buildCodexEntry(payload, {
    status: 200,
    headers: new Headers(),
    payload,
  });

  expect(entry.quotas).toEqual([
    {
      kind: "session",
      used: 25,
      remaining: 75,
      resetAt: 1_000,
    },
    {
      kind: "weekly",
      used: 40,
      remaining: 60,
      resetAt: 2_000,
    },
  ]);
});

test("preserves positional Codex window fallback without duration metadata", () => {
  const payload = {
    plan_type: "pro",
    rate_limit: {
      primary_window: {
        used_percent: 25,
        reset_at: 1_000,
      },
      secondary_window: {
        used_percent: 40,
        reset_at: 2_000,
      },
    },
  };

  const entry = buildCodexEntry(payload, {
    status: 200,
    headers: new Headers(),
    payload,
  });

  expect(entry.quotas.map((quota) => quota.kind)).toEqual(["session", "weekly"]);
});

test("renders a single available Codex window without placeholders", () => {
  const resetAt = Math.floor(Date.now() / 1000) + 5 * 24 * 60 * 60;
  const payload = {
    plan_type: "pro",
    rate_limit: {
      primary_window: {
        used_percent: 48,
        limit_window_seconds: 604_800,
        reset_at: resetAt,
      },
      secondary_window: null,
    },
  };
  const entry = buildCodexEntry(payload, {
    status: 200,
    headers: new Headers(),
    payload,
  });

  const rendered = formatEntryValues(entry).replaceAll(/%\{[^}]+\}/g, "");
  expect(rendered).toBe("52 5d");
});

test("renders Cursor usage once", () => {
  const resetAt = Math.floor(Date.now() / 1000) + 27 * 24 * 60 * 60;
  const entry = buildCursorEntry({
    billingCycleEnd: resetAt,
    planUsage: {
      totalPercentUsed: 0,
      apiPercentUsed: 0,
    },
  });

  const rendered = formatEntryValues(entry).replaceAll(/%\{[^}]+\}/g, "");
  expect(rendered).toBe("100 27d");
});

describe("read-only Codex usage", () => {
  const claims = Buffer.from(JSON.stringify({ client_id: "test-client" })).toString("base64url");
  const credentials = JSON.stringify({
    tokens: {
      access_token: `header.${claims}.signature`,
      refresh_token: "test-refresh-token",
      account_id: "test-account",
    },
  });
  let accountsDirectory: string;
  let previousAccountsDirectory: string | undefined;

  beforeEach(() => {
    accountsDirectory = mkdtempSync(join(tmpdir(), "polybar-accounts-test-"));
    previousAccountsDirectory = process.env.AGENTS_CODEX_ACCOUNTS_DIR;
    process.env.AGENTS_CODEX_ACCOUNTS_DIR = accountsDirectory;
    writeFileSync(join(accountsDirectory, "personal.json"), credentials);
    writeFileSync(join(accountsDirectory, "state.json"), JSON.stringify({ schemaVersion: 1, active: "personal" }));
  });

  afterEach(() => {
    mock.restore();

    if (previousAccountsDirectory === undefined) {
      delete process.env.AGENTS_CODEX_ACCOUNTS_DIR;
    } else {
      process.env.AGENTS_CODEX_ACCOUNTS_DIR = previousAccountsDirectory;
    }

    rmSync(accountsDirectory, { recursive: true, force: true });
  });

  test("reads usage without changing saved credentials", async () => {
    const request = spyOn(globalThis, "fetch").mockResolvedValue(
      Response.json({
        plan_type: "pro",
        rate_limit: {
          primary_window: { used_percent: 25, limit_window_seconds: 18_000, reset_at: 2_000 },
          secondary_window: null,
        },
      }),
    );

    const accounts = await fetchCodexAccounts(new Map());

    expect(accounts).toMatchObject([{
      name: "personal",
      active: true,
      entry: {
        error: null,
        quotas: [{ kind: "session", used: 25, remaining: 75, resetAt: 2_000 }],
      },
    }]);
    expect(request).toHaveBeenCalledTimes(1);
    expect(request).toHaveBeenCalledWith("https://chatgpt.com/backend-api/wham/usage", expect.objectContaining({
      headers: expect.objectContaining({
        Authorization: `Bearer header.${claims}.signature`,
        "ChatGPT-Account-Id": "test-account",
      }),
    }));
    expect(readFileSync(join(accountsDirectory, "personal.json"), "utf8")).toBe(credentials);
  });

  test.each([401, 403])("shows unavailable for HTTP %i without refreshing or rewriting credentials", async (status) => {
    const request = spyOn(globalThis, "fetch")
      .mockRejectedValue(new Error("Unexpected extra request"))
      .mockResolvedValueOnce(Response.json({}, { status }))
      .mockResolvedValueOnce(Response.json({ access_token: "new-access-token", refresh_token: "new-refresh-token" }));

    const accounts = await fetchCodexAccounts(new Map([["personal", codexEntry(25)]]));

    expect(request).toHaveBeenCalledTimes(1);
    expect(readFileSync(join(accountsDirectory, "personal.json"), "utf8")).toBe(credentials);
    expect(accounts.map((account) => account.entry.error)).toEqual(["unavailable"]);
    expect(accounts.map((account) => formatEntryValues(account.entry).replaceAll(/%\{[^}]+\}/g, ""))).toEqual(["--/--"]);
  });
});
