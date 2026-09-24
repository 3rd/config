#!/usr/bin/env bun

import {
  accessSync,
  closeSync,
  constants as fsConstants,
  existsSync,
  mkdirSync,
  openSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { Database } from "bun:sqlite";

const CACHE_PATH = "/tmp/polybar-ai-usage.json";
const LOCK_PATH = "/tmp/polybar-ai-usage.lock";
const CLAUDE_STATUSLINE_CACHE_PATH = "/tmp/polybar-ai-usage-claude-statusline.json";
const CLAUDE_STATUSLINE_CACHE_PATH_2 = "/tmp/polybar-ai-usage-claude-statusline-2.json";
const CLAUDE_STATUSLINE_CACHE_PATH_3 = "/tmp/polybar-ai-usage-claude-statusline-3.json";
const REFRESH_FLAG = "--refresh";

const OPENAI_USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";

const CURSOR_USAGE_URL = "https://cursor.com/api/dashboard/get-current-period-usage";
const CURSOR_ORIGIN = "https://cursor.com";
const CURSOR_REFERER = "https://cursor.com/dashboard/spending";

const JSON_CONTENT_TYPE = "application/json";
const USER_AGENT = "polybar-ai-usage";

const HTTP_TIMEOUT_MS = 12_000;
const LOCK_STALE_MS = 60_000;
const LOCK_WAIT_TIMEOUT_MS = 30_000;
const LOCK_WAIT_POLL_MS = 250;
const ERROR_TTL_SECONDS = 300;
const MINUTE_SECONDS = 60;
const HOUR_SECONDS = 60 * MINUTE_SECONDS;
const DAY_SECONDS = 24 * HOUR_SECONDS;
const WEEKLY_RESET_WARNING_SECONDS = 4 * DAY_SECONDS;
const WEEKLY_RESET_CRITICAL_SECONDS = 2 * DAY_SECONDS;
const CLAUDE_STATUSLINE_MAX_AGE_SECONDS = 8 * DAY_SECONDS;
const CODEX_WINDOW_DURATION_SECONDS = {
  session: 5 * HOUR_SECONDS,
  weekly: 7 * DAY_SECONDS,
} as const;
const CODEX_WINDOW_DURATION_TOLERANCE = 0.05;
const CODEX_QUOTA_ORDER = ["session", "weekly"] as const;

const SEGMENT_GAP = "   ";
const RESET_COLOR = "%{F-}";
const VALUE_DIVIDER = " ";

const PROVIDER_COLORS = {
  critical: "#c2290a",
  healthy: "#66b814",
  icon: "#848095",
  separator: "#4C495E",
  unknown: "#848095",
  warning: "#c2940a",
} as const;

type ProviderName = "claude" | "codex" | "cursor";
type ProviderSource = "api" | "statusline";
type ProviderErrorCode = "unavailable";
type ProviderQuotaKind = "session" | "weekly" | "billingTotal" | "billingApi";
type CodexQuotaKind = Extract<ProviderQuotaKind, "session" | "weekly">;
type ResetAtValue = number | string | null;
type JsonObject = Record<string, unknown>;

const PROVIDER_ICONS = {
  claude: "\u{e861}",
  codex: "\u{e7cf}",
  cursor: "\u{f1b2}",
} as const satisfies Record<ProviderName, string>;

const PROVIDER_ICON_FONT_INDICES = {
  claude: 4,
  codex: 4,
  cursor: 4,
} as const satisfies Record<ProviderName, number>;

const PROVIDER_ICON_COLORS = {
  claude: "#C46849",
  codex: "#E6E6E6",
  cursor: "#6CB6FF",
} as const satisfies Record<ProviderName, string>;

const PROVIDER_TTLS = {
  claude: 60,
  codex: 60,
  cursor: 60,
} as const satisfies Record<ProviderName, number>;

const PROVIDER_ORDER = ["codex", "claude", "cursor"] as const satisfies readonly ProviderName[];
const PROVIDER_COMMANDS = {
  claude: "claude",
  codex: "codex",
  cursor: "cursor-agent",
} as const satisfies Record<ProviderName, string>;

const CODEX_AUTH_PATHS = ["~/.codex/auth.json", "~/.config/codex/auth.json"] as const;

const CODEX_ACCOUNTS_DIR_DEFAULT = "~/brain/config/workflow/agents/config/custom/codex/accounts";
const CODEX_ACCOUNTS_STATE_FILE = "state.json";

const CURSOR_STATE_DB_PATHS = [
  "~/.config/Cursor/User/globalStorage/state.vscdb",
  "~/.config/cursor/User/globalStorage/state.vscdb",
] as const;
const CURSOR_AUTH_TOKEN_KEY = "cursorAuth/accessToken";

const CODEX_PERCENT_HEADERS = {
  primary: "x-codex-primary-used-percent",
  secondary: "x-codex-secondary-used-percent",
} as const;

const UNAUTHORIZED_STATUSES = new Set([401, 403]);

interface HttpJsonResponse {
  status: number;
  headers: Headers;
  payload: unknown;
}

interface ProviderEntry {
  provider: ProviderName;
  source: ProviderSource | null;
  plan: string | null;
  quotas: ProviderQuota[];
  fetchedAt: number;
  retryAt: number | null;
  error: ProviderErrorCode | null;
}

interface ProviderQuota {
  kind: ProviderQuotaKind;
  used: number | null;
  remaining: number | null;
  resetAt: ResetAtValue;
}

interface BuildProviderQuotaOptions {
  kind: ProviderQuotaKind;
  used?: number | null;
  resetAt?: ResetAtValue;
}

interface BuildCodexQuotaOptions extends BuildProviderQuotaOptions {
  kind: CodexQuotaKind;
}

interface CodexAccountEntry {
  name: string | null;
  active: boolean;
  entry: ProviderEntry;
}

interface ProviderSegment {
  label: string | null;
  labelColor: string | null;
  entry: ProviderEntry | undefined;
}

interface CacheData {
  claude?: ProviderEntry;
  claude2?: ProviderEntry;
  claude3?: ProviderEntry;
  codexAccounts?: CodexAccountEntry[];
  cursor?: ProviderEntry;
  updatedAt?: number;
}

interface ClaudeStatuslineWindowCache {
  resetsAt: ResetAtValue;
  usedPercentage: number | null;
}

interface ClaudeStatuslineCache {
  fiveHour?: ClaudeStatuslineWindowCache;
  sevenDay?: ClaudeStatuslineWindowCache;
  updatedAt: number;
}

interface BuildProviderEntryOptions {
  provider: ProviderName;
  source?: ProviderSource | null;
  plan?: string | null;
  quotas?: BuildProviderQuotaOptions[];
  fetchedAt?: number;
  retryAt?: number | null;
  error?: ProviderErrorCode | null;
}

interface CodexTokensRecord extends JsonObject {
  access_token?: unknown;
  account_id?: unknown;
}

interface CodexAuthFile extends JsonObject {
  tokens: CodexTokensRecord;
}

interface ErrnoLikeError {
  code?: string;
}

const homeDirectory = (): string => process.env.HOME ?? homedir();

const configurePath = (): void => {
  const home = homeDirectory();
  const prefixes = [
    `${home}/.local/bin`,
    `${home}/.nix-profile/bin`,
    `${home}/.bun/bin`,
    "/run/current-system/sw/bin",
  ];
  const existingPath = process.env.PATH ?? "";
  process.env.PATH = [...prefixes, existingPath].filter(Boolean).join(":");
};

const commandExists = (command: string): boolean => {
  const pathEntries = (process.env.PATH ?? "").split(":").filter(Boolean);
  for (const pathEntry of pathEntries) {
    try {
      accessSync(join(pathEntry, command), fsConstants.X_OK);
      return true;
    } catch {
      continue;
    }
  }

  return false;
};

const availableProviders = (): ProviderName[] =>
  PROVIDER_ORDER.filter((provider) => commandExists(PROVIDER_COMMANDS[provider]));

const nowEpoch = (): number => Math.floor(Date.now() / 1000);

const expandHomePath = (filePath: string): string =>
  filePath.startsWith("~/") ? `${homeDirectory()}/${filePath.slice(2)}` : filePath;

const isJsonObject = (value: unknown): value is JsonObject =>
  value !== null && typeof value === "object" && !Array.isArray(value);

const isNumber = (value: unknown): value is number => typeof value === "number" && Number.isFinite(value);

const asString = (value: unknown): string | null => (typeof value === "string" ? value : null);

const asNumber = (value: unknown): number | null => {
  if (isNumber(value)) {
    return value;
  }

  if (typeof value !== "string" || value.trim() === "") {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const asResetAtValue = (value: unknown): ResetAtValue => asNumber(value) ?? asString(value) ?? null;

const asProviderSource = (value: unknown): ProviderSource | null =>
  value === "api" || value === "statusline" ? value : null;

const asProviderError = (value: unknown): ProviderErrorCode | null =>
  value === "unavailable" ? "unavailable" : null;

const asProviderQuotaKind = (value: unknown): ProviderQuotaKind | null =>
  value === "session" || value === "weekly" || value === "billingTotal" || value === "billingApi"
    ? value
    : null;

const clampPercent = (value: unknown): number | null => {
  const parsed = asNumber(value);
  if (parsed === null) {
    return null;
  }

  return Math.max(0, Math.min(100, Math.round(parsed)));
};

const remainingPercent = (usedPercent: number | null): number | null =>
  usedPercent === null ? null : Math.max(0, 100 - usedPercent);

const toResetEpochSeconds = (value: ResetAtValue): number | null => {
  if (typeof value === "number") {
    return value > 1_000_000_000_000 ? Math.floor(value / 1000) : Math.floor(value);
  }

  if (typeof value !== "string") {
    return null;
  }

  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? Math.floor(parsed / 1000) : null;
};

const hasProviderEntry = (entry: ProviderEntry | undefined): entry is ProviderEntry => entry !== undefined;

const providerHasValues = (entry: ProviderEntry | undefined): boolean =>
  hasProviderEntry(entry) && entry.quotas.some((quota) => isNumber(quota.remaining));

const hasRetryWindow = (retryAt: number | null): boolean => retryAt !== null && retryAt > nowEpoch();

const parseJsonFile = (path: string): unknown | null => {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
};

const decodeJwtPayload = (token: string | null): JsonObject | null => {
  if (!token) {
    return null;
  }

  const parts = token.split(".");
  if (parts.length < 2) {
    return null;
  }

  try {
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const payload = JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
    return isJsonObject(payload) ? payload : null;
  } catch {
    return null;
  }
};

const writeJsonAtomic = (path: string, payload: unknown): void => {
  mkdirSync(dirname(path), { recursive: true });
  const tempPath = `${path}.tmp`;
  writeFileSync(tempPath, JSON.stringify(payload, null, 2));
  renameSync(tempPath, path);
};

const buildProviderQuota = ({
  kind,
  used = null,
  resetAt = null,
}: BuildProviderQuotaOptions): ProviderQuota => ({
  kind,
  used,
  remaining: remainingPercent(used),
  resetAt,
});

const buildProviderEntry = ({
  provider,
  source = null,
  plan = null,
  quotas = [],
  fetchedAt = nowEpoch(),
  retryAt = null,
  error = null,
}: BuildProviderEntryOptions): ProviderEntry => ({
  provider,
  source,
  plan,
  quotas: quotas.map(buildProviderQuota),
  fetchedAt,
  retryAt,
  error,
});

const sanitizeProviderQuota = (quota: ProviderQuota): ProviderQuota => {
  const expired = (toResetEpochSeconds(quota.resetAt) ?? Infinity) <= nowEpoch();
  if (!expired) {
    return quota;
  }

  return {
    ...quota,
    used: null,
    remaining: null,
    resetAt: null,
  };
};

const sanitizeProviderEntry = (entry: ProviderEntry): ProviderEntry => {
  const quotas = entry.quotas.map(sanitizeProviderQuota);

  if (quotas.every((quota, index) => quota === entry.quotas[index])) {
    return entry;
  }

  return {
    ...entry,
    quotas,
  };
};

const normalizeProviderQuota = (value: unknown): ProviderQuota | undefined => {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const kind = asProviderQuotaKind(value.kind);
  if (!kind) {
    return undefined;
  }

  return buildProviderQuota({
    kind,
    used: clampPercent(value.used ?? value.usedPercent ?? value.used_percent),
    resetAt: asResetAtValue(value.resetAt ?? value.reset_at),
  });
};

const legacyQuotaKinds = (provider: ProviderName): [ProviderQuotaKind, ProviderQuotaKind] =>
  provider === "cursor" ? ["billingTotal", "billingApi"] : ["session", "weekly"];

const normalizeProviderQuotas = (provider: ProviderName, value: JsonObject): ProviderQuota[] => {
  if (Array.isArray(value.quotas)) {
    return value.quotas.flatMap((quota) => {
      const normalized = normalizeProviderQuota(quota);
      return normalized ? [normalized] : [];
    });
  }

  const [primaryKind, secondaryKind] = legacyQuotaKinds(provider);
  return [
    buildProviderQuota({
      kind: primaryKind,
      used: clampPercent(value.sessionUsed ?? value.session_used),
      resetAt: asResetAtValue(value.sessionResetAt ?? value.session_reset_at),
    }),
    buildProviderQuota({
      kind: secondaryKind,
      used: clampPercent(value.weeklyUsed ?? value.weekly_used),
      resetAt: asResetAtValue(value.weeklyResetAt ?? value.weekly_reset_at),
    }),
  ];
};

const normalizeProviderEntry = (provider: ProviderName, value: unknown): ProviderEntry | undefined => {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const fetchedAt = asNumber(value.fetchedAt ?? value.fetched_at);
  if (fetchedAt === null) {
    return undefined;
  }

  return sanitizeProviderEntry(
    buildProviderEntry({
      provider,
      source: asProviderSource(value.source),
      plan: asString(value.plan),
      quotas: normalizeProviderQuotas(provider, value),
      fetchedAt,
      retryAt: asNumber(value.retryAt ?? value.retry_at),
      error: asProviderError(value.error),
    }),
  );
};

const normalizeClaudeStatuslineWindowCache = (value: unknown): ClaudeStatuslineWindowCache | undefined => {
  if (!isJsonObject(value)) {
    return undefined;
  }

  return {
    usedPercentage: clampPercent(value.usedPercentage ?? value.used_percentage),
    resetsAt: asResetAtValue(value.resetsAt ?? value.resets_at),
  };
};

const normalizeClaudeStatuslineCache = (value: unknown): ClaudeStatuslineCache | undefined => {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const updatedAt = asNumber(value.updatedAt ?? value.updated_at);
  if (updatedAt === null) {
    return undefined;
  }

  return {
    updatedAt,
    fiveHour: normalizeClaudeStatuslineWindowCache(value.fiveHour ?? value.five_hour),
    sevenDay: normalizeClaudeStatuslineWindowCache(value.sevenDay ?? value.seven_day),
  };
};

const claudeWindowUsed = (window: ClaudeStatuslineWindowCache | undefined): number | null => {
  if (!window) {
    return null;
  }

  const resetEpoch = toResetEpochSeconds(window.resetsAt);
  if (resetEpoch !== null && resetEpoch <= nowEpoch()) {
    return 0;
  }

  return window.usedPercentage;
};

const readClaudeStatuslineEntry = (cachePath: string): ProviderEntry | undefined => {
  const cache = normalizeClaudeStatuslineCache(parseJsonFile(cachePath));
  if (!cache) {
    return undefined;
  }

  if (Date.now() - cache.updatedAt * 1000 > CLAUDE_STATUSLINE_MAX_AGE_SECONDS * 1000) {
    return undefined;
  }

  return buildProviderEntry({
    provider: "claude",
    source: "statusline",
    quotas: [
      {
        kind: "session",
        used: claudeWindowUsed(cache.fiveHour),
        resetAt: cache.fiveHour?.resetsAt ?? null,
      },
      {
        kind: "weekly",
        used: claudeWindowUsed(cache.sevenDay),
        resetAt: cache.sevenDay?.resetsAt ?? null,
      },
    ],
    fetchedAt: cache.updatedAt,
  });
};

const normalizeCodexAccount = (value: unknown): CodexAccountEntry | undefined => {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const entry = normalizeProviderEntry("codex", value.entry);
  if (!entry) {
    return undefined;
  }

  return {
    name: asString(value.name),
    active: value.active === true,
    entry,
  };
};

const normalizeCodexAccounts = (value: unknown): CodexAccountEntry[] | undefined => {
  if (!Array.isArray(value)) {
    return undefined;
  }

  const accounts = value.flatMap((item) => {
    const account = normalizeCodexAccount(item);
    return account ? [account] : [];
  });

  return accounts.length > 0 ? accounts : undefined;
};

export const normalizeCacheData = (value: unknown): CacheData => {
  if (!isJsonObject(value)) {
    return {};
  }

  return {
    codexAccounts: normalizeCodexAccounts(value.codexAccounts ?? value.codex_accounts),
    cursor: normalizeProviderEntry("cursor", value.cursor),
    updatedAt: asNumber(value.updatedAt ?? value.updated_at) ?? undefined,
  };
};

const readCache = (): CacheData => {
  const cache = normalizeCacheData(parseJsonFile(CACHE_PATH));
  return {
    ...cache,
    claude: readClaudeStatuslineEntry(CLAUDE_STATUSLINE_CACHE_PATH),
    claude2: readClaudeStatuslineEntry(CLAUDE_STATUSLINE_CACHE_PATH_2),
    claude3: readClaudeStatuslineEntry(CLAUDE_STATUSLINE_CACHE_PATH_3),
  };
};

const writeCache = (cache: CacheData): void => {
  writeJsonAtomic(CACHE_PATH, cache);
};

const entryIsFresh = (entry: ProviderEntry, provider: ProviderName): boolean => {
  if (hasRetryWindow(entry.retryAt)) {
    return true;
  }

  const ttlSeconds = entry.error === null ? PROVIDER_TTLS[provider] : ERROR_TTL_SECONDS;
  return Date.now() - entry.fetchedAt * 1000 < ttlSeconds * 1000;
};

const cacheIsFresh = (cache: CacheData, provider: ProviderName): boolean => {
  if (provider === "codex") {
    const accounts = cache.codexAccounts ?? [];
    return accounts.length > 0 && accounts.every((account) => entryIsFresh(account.entry, provider));
  }

  const entry = cache[provider];
  return entry ? entryIsFresh(entry, provider) : false;
};

const cacheNeedsRefresh = (cache: CacheData): boolean =>
  availableProviders().some((provider) => provider !== "claude" && !cacheIsFresh(cache, provider));

const shouldRefreshProvider = (cache: CacheData, provider: ProviderName, forceRefresh: boolean): boolean =>
  forceRefresh || !cacheIsFresh(cache, provider);

const colorForRemaining = (value: number | null): string => {
  if (value === null) {
    return PROVIDER_COLORS.unknown;
  }

  if (value <= 20) {
    return PROVIDER_COLORS.critical;
  }

  if (value <= 50) {
    return PROVIDER_COLORS.warning;
  }

  return PROVIDER_COLORS.healthy;
};

const colorForWeeklyReset = (remainingSeconds: number | null): string => {
  if (remainingSeconds === null) return PROVIDER_COLORS.separator;
  if (remainingSeconds <= WEEKLY_RESET_CRITICAL_SECONDS)
    return PROVIDER_COLORS.critical;
  if (remainingSeconds <= WEEKLY_RESET_WARNING_SECONDS)
    return PROVIDER_COLORS.warning;
  return PROVIDER_COLORS.separator;
};

const displayPercent = (value: number | null): string => (value === null ? "--" : String(value));

const colorForReset = (quota: ProviderQuota, remainingSeconds: number | null): string =>
  quota.kind === "weekly" ? colorForWeeklyReset(remainingSeconds) : PROVIDER_COLORS.separator;

const remainingResetSeconds = (resetAt: ResetAtValue): number | null => {
  const resetEpochSeconds = toResetEpochSeconds(resetAt);
  if (resetEpochSeconds === null) {
    return null;
  }

  const remainingSeconds = resetEpochSeconds - nowEpoch();
  if (remainingSeconds <= 0) {
    return null;
  }

  return remainingSeconds;
};

const formatRemainingTime = (remainingSeconds: number | null): string | null => {
  if (remainingSeconds === null) {
    return null;
  }

  if (remainingSeconds >= DAY_SECONDS) {
    return `${Math.ceil(remainingSeconds / DAY_SECONDS)}d`;
  }

  if (remainingSeconds >= HOUR_SECONDS) {
    return `${Math.ceil(remainingSeconds / HOUR_SECONDS)}h`;
  }

  return `${Math.max(1, Math.ceil(remainingSeconds / MINUTE_SECONDS))}m`;
};

const UNKNOWN_PAIR = `%{F${PROVIDER_COLORS.unknown}}--%{F${PROVIDER_COLORS.separator}}/%{F${PROVIDER_COLORS.unknown}}--${RESET_COLOR}`;

export const formatEntryValues = (entry?: ProviderEntry): string => {
  if (!entry) return UNKNOWN_PAIR;

  const availableValues = entry.quotas.map((quota) => quota.remaining).filter(isNumber);
  if (availableValues.length === 0) return UNKNOWN_PAIR;

  const remainingPart = entry.quotas
    .map((quota) => `%{F${colorForRemaining(quota.remaining)}}${displayPercent(quota.remaining)}`)
    .join(`%{F${PROVIDER_COLORS.separator}}/`);

  const resetTimes = entry.quotas.map((quota) => {
    const remainingSeconds = remainingResetSeconds(quota.resetAt);
    return {
      quota,
      remainingSeconds,
      text: formatRemainingTime(remainingSeconds),
    };
  });

  if (resetTimes.every((resetTime) => resetTime.text === null)) {
    return `${remainingPart}${RESET_COLOR}`;
  }

  const showTime = (time: string | null): string => time ?? "--";
  const timePart = resetTimes
    .map(
      (resetTime, index) =>
        `%{F${index === 0 ? PROVIDER_COLORS.separator : colorForReset(resetTime.quota, resetTime.remainingSeconds)}}${showTime(resetTime.text)}`,
    )
    .join(`%{F${PROVIDER_COLORS.separator}}/`);
  return `${remainingPart}${VALUE_DIVIDER}${timePart}${RESET_COLOR}`;
};

const formatProviderLabel = (provider: ProviderName, label: string | null, labelColor: string | null): string => {
  const labelText = label === null ? "" : labelColor === null ? label : `%{F${labelColor}}${label}`;
  return `%{F${PROVIDER_ICON_COLORS[provider]}}%{T${PROVIDER_ICON_FONT_INDICES[provider]}}${PROVIDER_ICONS[provider]}%{T-}${labelText}${RESET_COLOR}`;
};

const formatProviderOutput = (provider: ProviderName, segments: readonly ProviderSegment[]): string =>
  segments
    .map((segment) => `${formatProviderLabel(provider, segment.label, segment.labelColor)} ${formatEntryValues(segment.entry)}`)
    .join(SEGMENT_GAP);

const claudeSegments = (cache: CacheData): ProviderSegment[] => {
  const entries = [cache.claude, cache.claude2, cache.claude3];
  const showEntryNumbers = entries.filter(hasProviderEntry).length > 1;
  return entries.map((entry, index) => ({
    label: showEntryNumbers ? String(index + 1) : null,
    labelColor: null,
    entry,
  }));
};

export const codexSegments = (accounts: readonly CodexAccountEntry[]): ProviderSegment[] => {
  if (accounts.length === 0) {
    return [{ label: null, labelColor: null, entry: undefined }];
  }

  return accounts.map((account) => ({
    label: account.name,
    labelColor: account.active ? PROVIDER_ICON_COLORS.codex : PROVIDER_COLORS.icon,
    entry: account.entry,
  }));
};

const providerSegments = (cache: CacheData, provider: ProviderName): ProviderSegment[] => {
  if (provider === "claude") {
    return claudeSegments(cache);
  }

  if (provider === "codex") {
    return codexSegments(cache.codexAccounts ?? []);
  }

  return [{ label: null, labelColor: null, entry: cache[provider] }];
};

const formatOutput = (cache: CacheData): string =>
  availableProviders()
    .map((provider) => formatProviderOutput(provider, providerSegments(cache, provider)))
    .join(SEGMENT_GAP);

const unavailableEntry = (provider: ProviderName): ProviderEntry =>
  buildProviderEntry({
    provider,
    error: "unavailable",
  });

const parseResponsePayload = (text: string): unknown => {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const httpJson = async (url: string, init?: RequestInit): Promise<HttpJsonResponse> => {
  const response = await fetch(url, {
    ...init,
    signal: AbortSignal.timeout(HTTP_TIMEOUT_MS),
  });
  const text = await response.text();

  return {
    status: response.status,
    headers: response.headers,
    payload: text === "" ? null : parseResponsePayload(text),
  };
};

const isCodexAuthFile = (value: unknown): value is CodexAuthFile =>
  isJsonObject(value) && isJsonObject(value.tokens);

const loadCodexAuth = () => {
  for (const candidatePath of CODEX_AUTH_PATHS) {
    const path = expandHomePath(candidatePath);
    const file = parseJsonFile(path);
    if (isCodexAuthFile(file)) {
      return file;
    }
  }

  return null;
};

const requestCodexUsage = async (accessToken: string, accountId: string | null): Promise<HttpJsonResponse> =>
  httpJson(OPENAI_USAGE_URL, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: JSON_CONTENT_TYPE,
      "User-Agent": USER_AGENT,
      ...(accountId ? { "ChatGPT-Account-Id": accountId } : {}),
    },
  });

const isApproximateWindowDuration = (actualSeconds: number, expectedSeconds: number): boolean =>
  Math.abs(actualSeconds - expectedSeconds) <= expectedSeconds * CODEX_WINDOW_DURATION_TOLERANCE;

const codexQuotaKindForDuration = (
  durationSeconds: number | null,
  fallbackKind: CodexQuotaKind,
): CodexQuotaKind => {
  if (durationSeconds === null) {
    return fallbackKind;
  }

  if (isApproximateWindowDuration(durationSeconds, CODEX_WINDOW_DURATION_SECONDS.session)) {
    return "session";
  }

  if (isApproximateWindowDuration(durationSeconds, CODEX_WINDOW_DURATION_SECONDS.weekly)) {
    return "weekly";
  }

  return fallbackKind;
};

const buildCodexQuota = (
  value: unknown,
  fallbackKind: CodexQuotaKind,
  percentHeader: string,
  response: HttpJsonResponse,
): BuildCodexQuotaOptions | null => {
  if (!isJsonObject(value)) {
    return null;
  }

  return {
    kind: codexQuotaKindForDuration(asNumber(value.limit_window_seconds), fallbackKind),
    used: clampPercent(response.headers.get(percentHeader) ?? value.used_percent),
    resetAt: asResetAtValue(value.reset_at),
  };
};

const orderedCodexQuotas = (
  quotas: readonly (BuildCodexQuotaOptions | null)[],
): BuildCodexQuotaOptions[] =>
  quotas
    .filter((quota): quota is BuildCodexQuotaOptions => quota !== null)
    .sort(
      (left, right) => CODEX_QUOTA_ORDER.indexOf(left.kind) - CODEX_QUOTA_ORDER.indexOf(right.kind),
    );

export const buildCodexEntry = (payload: JsonObject, response: HttpJsonResponse): ProviderEntry => {
  const rateLimit = isJsonObject(payload.rate_limit) ? payload.rate_limit : {};
  const quotas = orderedCodexQuotas([
    buildCodexQuota(
      rateLimit.primary_window,
      "session",
      CODEX_PERCENT_HEADERS.primary,
      response,
    ),
    buildCodexQuota(
      rateLimit.secondary_window,
      "weekly",
      CODEX_PERCENT_HEADERS.secondary,
      response,
    ),
  ]);

  return buildProviderEntry({
    provider: "codex",
    source: "api",
    plan: asString(payload.plan_type),
    quotas,
  });
};

const codexAccountsDir = (): string => {
  const fromEnv = process.env.AGENTS_CODEX_ACCOUNTS_DIR;
  if (fromEnv !== undefined && fromEnv !== "") {
    return fromEnv;
  }

  return expandHomePath(CODEX_ACCOUNTS_DIR_DEFAULT);
};

const listCodexProfiles = (): { name: string; path: string }[] => {
  const dir = codexAccountsDir();
  let fileNames: string[];
  try {
    fileNames = readdirSync(dir);
  } catch {
    return [];
  }

  return fileNames
    .filter((fileName) => fileName.endsWith(".json") && fileName !== CODEX_ACCOUNTS_STATE_FILE)
    .map((fileName) => ({
      name: fileName.slice(0, -".json".length),
      path: join(dir, fileName),
    }))
    .sort((left, right) => left.name.localeCompare(right.name));
};

const readCodexActiveProfileName = (): string | null => {
  const state = parseJsonFile(join(codexAccountsDir(), CODEX_ACCOUNTS_STATE_FILE));
  return isJsonObject(state) ? asString(state.active) : null;
};

const fetchCodexUsageForAuth = async (auth: CodexAuthFile): Promise<ProviderEntry> => {
  const accessToken = asString(auth.tokens.access_token);
  const accountId = asString(auth.tokens.account_id);
  if (!accessToken) {
    throw new Error("codex access token missing");
  }

  const response = await requestCodexUsage(accessToken, accountId);
  if (UNAUTHORIZED_STATUSES.has(response.status)) {
    return unavailableEntry("codex");
  }
  if (response.status !== 200 || !isJsonObject(response.payload)) {
    throw new Error(`codex usage request failed (${response.status})`);
  }

  return buildCodexEntry(response.payload, response);
};

const fetchLiveCodexEntry = async (): Promise<ProviderEntry> => {
  const codexAuth = loadCodexAuth();
  if (!codexAuth) {
    throw new Error("codex auth.json not found");
  }

  return fetchCodexUsageForAuth(codexAuth);
};

const fetchStoredCodexEntry = async (profilePath: string): Promise<ProviderEntry> => {
  const auth = parseJsonFile(profilePath);
  if (!isCodexAuthFile(auth)) {
    throw new Error(`invalid codex profile: ${profilePath}`);
  }

  return fetchCodexUsageForAuth(auth);
};

const readCursorSessionToken = (): string | null => {
  for (const candidatePath of CURSOR_STATE_DB_PATHS) {
    const path = expandHomePath(candidatePath);
    if (!existsSync(path)) {
      continue;
    }

    try {
      const db = new Database(path, { readonly: true });
      try {
        const row = db.query("SELECT value FROM ItemTable WHERE key = ?").get(CURSOR_AUTH_TOKEN_KEY) as {
          value?: unknown;
        } | null;
        const token = asString(row?.value);
        if (token) {
          return token;
        }
      } finally {
        db.close();
      }
    } catch {
      continue;
    }
  }

  return null;
};

const cursorTokenIsExpired = (token: string): boolean => {
  const exp = asNumber(decodeJwtPayload(token)?.exp);
  return exp !== null && exp <= nowEpoch();
};

const cursorUserIdFromToken = (token: string): string | null => {
  const sub = asString(decodeJwtPayload(token)?.sub);
  return sub ? (sub.split("|").pop() ?? null) : null;
};

const requestCursorUsage = async (cookie: string): Promise<HttpJsonResponse> =>
  httpJson(CURSOR_USAGE_URL, {
    method: "POST",
    headers: {
      Cookie: cookie,
      "Content-Type": JSON_CONTENT_TYPE,
      Accept: JSON_CONTENT_TYPE,
      Origin: CURSOR_ORIGIN,
      Referer: CURSOR_REFERER,
      "User-Agent": USER_AGENT,
    },
    body: "{}",
  });

export const buildCursorEntry = (payload: JsonObject): ProviderEntry => {
  const planUsage = isJsonObject(payload.planUsage) ? payload.planUsage : {};
  const resetAt = asResetAtValue(payload.billingCycleEnd);

  return buildProviderEntry({
    provider: "cursor",
    source: "api",
    quotas: [
      {
        kind: "billingTotal",
        used: clampPercent(planUsage.totalPercentUsed),
        resetAt,
      },
    ],
  });
};

const fetchCursorUsage = async (): Promise<ProviderEntry> => {
  const token = readCursorSessionToken();
  if (!token) {
    throw new Error("cursor session token not found");
  }

  if (cursorTokenIsExpired(token)) {
    throw new Error("cursor session token expired");
  }

  const userId = cursorUserIdFromToken(token);
  if (!userId) {
    throw new Error("cursor user id missing");
  }

  const response = await requestCursorUsage(`WorkosCursorSessionToken=${userId}::${token}`);
  if (response.status !== 200 || !isJsonObject(response.payload)) {
    throw new Error(`cursor usage request failed (${response.status})`);
  }

  return buildCursorEntry(response.payload);
};

const isErrnoLikeError = (value: unknown): value is ErrnoLikeError =>
  isJsonObject(value) && (value.code === undefined || typeof value.code === "string");

const recoverProviderEntry = (
  provider: ProviderName,
  previousEntry: ProviderEntry | undefined,
): ProviderEntry => {
  if (hasProviderEntry(previousEntry) && providerHasValues(previousEntry)) {
    return {
      ...previousEntry,
      fetchedAt: nowEpoch(),
      retryAt: null,
      error: "unavailable",
    };
  }

  return unavailableEntry(provider);
};

const previousCodexEntriesByName = (cache: CacheData): Map<string | null, ProviderEntry> =>
  new Map((cache.codexAccounts ?? []).map((account) => [account.name, account.entry]));

export const fetchCodexAccounts = async (
  previousEntriesByName: ReadonlyMap<string | null, ProviderEntry>,
): Promise<CodexAccountEntry[]> => {
  const profiles = listCodexProfiles();

  if (profiles.length === 0) {
    let entry: ProviderEntry;
    try {
      entry = await fetchLiveCodexEntry();
    } catch {
      entry = recoverProviderEntry("codex", previousEntriesByName.get(null));
    }

    return [{ name: null, active: true, entry }];
  }

  const activeName = readCodexActiveProfileName();
  return Promise.all(
    profiles.map(async (profile) => {
      let entry: ProviderEntry;
      try {
        entry = await fetchStoredCodexEntry(profile.path);
      } catch {
        entry = recoverProviderEntry("codex", previousEntriesByName.get(profile.name));
      }

      return {
        name: profile.name,
        active: profile.name === activeName,
        entry,
      };
    }),
  );
};

const refreshCodexAccounts = async (
  previousCache: CacheData,
  enabledProviders: ProviderName[],
  forceRefresh: boolean,
): Promise<CodexAccountEntry[] | undefined> => {
  if (!enabledProviders.includes("codex") || !shouldRefreshProvider(previousCache, "codex", forceRefresh)) {
    return previousCache.codexAccounts;
  }

  return fetchCodexAccounts(previousCodexEntriesByName(previousCache));
};

const refreshCursorEntry = async (
  previousCache: CacheData,
  enabledProviders: ProviderName[],
  forceRefresh: boolean,
): Promise<ProviderEntry> => {
  if (!enabledProviders.includes("cursor") || !shouldRefreshProvider(previousCache, "cursor", forceRefresh)) {
    return previousCache.cursor ?? unavailableEntry("cursor");
  }

  try {
    return await fetchCursorUsage();
  } catch {
    return recoverProviderEntry("cursor", previousCache.cursor);
  }
};

const refreshCache = async (
  options: {
    forceRefresh?: boolean;
  } = {},
): Promise<CacheData> => {
  const previousCache = readCache();
  const enabledProviders = availableProviders();
  const forceRefresh = options.forceRefresh ?? false;

  const [codexAccounts, cursor] = await Promise.all([
    refreshCodexAccounts(previousCache, enabledProviders, forceRefresh),
    refreshCursorEntry(previousCache, enabledProviders, forceRefresh),
  ]);

  const nextCache: CacheData = {
    claude: previousCache.claude,
    claude2: previousCache.claude2,
    claude3: previousCache.claude3,
    codexAccounts,
    cursor,
    updatedAt: nowEpoch(),
  };

  writeCache(nextCache);
  return nextCache;
};

const cleanupStaleLock = (): void => {
  if (!existsSync(LOCK_PATH)) {
    return;
  }

  try {
    const stats = statSync(LOCK_PATH);
    if (Date.now() - stats.mtimeMs > LOCK_STALE_MS) {
      rmSync(LOCK_PATH, { force: true });
    }
  } catch {
    return;
  }
};

const acquireRefreshLock = (): number | null => {
  cleanupStaleLock();

  try {
    return openSync(LOCK_PATH, fsConstants.O_CREAT | fsConstants.O_EXCL | fsConstants.O_RDWR, 0o644);
  } catch (error) {
    if (isErrnoLikeError(error) && error.code === "EEXIST") {
      return null;
    }

    throw error;
  }
};

const releaseRefreshLock = (fd: number | null): void => {
  if (fd === null) {
    return;
  }

  try {
    closeSync(fd);
  } finally {
    try {
      unlinkSync(LOCK_PATH);
    } catch {
      return;
    }
  }
};

const waitForUnlockedCache = async (): Promise<CacheData> => {
  const startedAt = Date.now();
  cleanupStaleLock();

  while (existsSync(LOCK_PATH) && Date.now() - startedAt < LOCK_WAIT_TIMEOUT_MS) {
    await Bun.sleep(LOCK_WAIT_POLL_MS);
    cleanupStaleLock();
  }

  return readCache();
};

const withRefreshLock = async (work: () => Promise<CacheData>): Promise<CacheData> => {
  const lockFd = acquireRefreshLock();
  if (lockFd === null) {
    return waitForUnlockedCache();
  }

  try {
    return await work();
  } finally {
    releaseRefreshLock(lockFd);
  }
};

const runRefresh = async (forceRefresh = false): Promise<number> => {
  const cache = await withRefreshLock(() => refreshCache({ forceRefresh }));
  console.log(formatOutput(cache));
  return 0;
};

const main = async (): Promise<number> => {
  configurePath();

  const cache = readCache();
  if (process.argv.includes(REFRESH_FLAG)) {
    return runRefresh(true);
  }

  if (cacheNeedsRefresh(cache)) {
    return runRefresh(false);
  }

  console.log(formatOutput(cache));
  return 0;
};

if (import.meta.main) {
  void main().then((exitCode) => {
    process.exit(exitCode);
  });
}
