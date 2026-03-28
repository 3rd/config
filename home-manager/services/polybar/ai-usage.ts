#!/usr/bin/env bun

import {
  closeSync,
  constants as fsConstants,
  existsSync,
  mkdirSync,
  openSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const CACHE_PATH = "/tmp/polybar-ai-usage.json";
const LOCK_PATH = "/tmp/polybar-ai-usage.lock";
const REFRESH_FLAG = "--refresh";
const XDG_CACHE_FALLBACK_DIR = ".cache";
const PERSISTENT_CACHE_DIR = "polybar-ai-usage";
const CLAUDE_STATE_FILE = "claude.json";

const OPENAI_TOKEN_URL = "https://auth.openai.com/oauth/token";
const OPENAI_USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const CLAUDE_TOKEN_URL = "https://platform.claude.com/v1/oauth/token";
const ANTHROPIC_USAGE_URL = "https://api.anthropic.com/api/oauth/usage";

const FORM_CONTENT_TYPE = "application/x-www-form-urlencoded";
const JSON_CONTENT_TYPE = "application/json";
const USER_AGENT = "polybar-ai-usage";
const CLAUDE_USER_AGENT = "claude-code/unknown";
const ANTHROPIC_BETA = "oauth-2025-04-20";
const CLAUDE_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";

const HTTP_TIMEOUT_MS = 12_000;
const LOCK_STALE_MS = 60_000;
const LOCK_WAIT_TIMEOUT_MS = 30_000;
const LOCK_WAIT_POLL_MS = 250;
const CLAUDE_REFRESH_WINDOW_MS = 5 * 60 * 1000;
const ERROR_TTL_SECONDS = 300;
const MINUTE_SECONDS = 60;
const HOUR_SECONDS = 60 * MINUTE_SECONDS;
const DAY_SECONDS = 24 * HOUR_SECONDS;

const SEGMENT_GAP = "  ";
const RESET_COLOR = "%{F-}";
const VALUE_DIVIDER = "/";

const PROVIDER_COLORS = {
  critical: "#c2290a",
  healthy: "#66b814",
  icon: "#848095",
  separator: "#4C495E",
  unknown: "#848095",
  warning: "#c2940a",
} as const;

type ProviderName = "claude" | "codex";
type ProviderSource = "api";
type ProviderErrorCode = "unavailable";
type ResetAtValue = number | string | null;
type JsonObject = Record<string, unknown>;

const PROVIDER_LABELS = {
  claude: "CC",
  codex: "CX",
} as const satisfies Record<ProviderName, string>;

const PROVIDER_TTLS = {
  claude: 60,
  codex: 60,
} as const satisfies Record<ProviderName, number>;

const PROVIDER_ORDER = ["claude", "codex"] as const satisfies readonly ProviderName[];

const CODEX_AUTH_PATHS = [
  "~/.codex/auth.json",
  "~/.config/codex/auth.json",
] as const;
const CLAUDE_CREDENTIALS_PATH = "~/.claude/.credentials.json";
const CLAUDE_DEFAULT_SCOPES = [
  "user:profile",
  "user:inference",
  "user:sessions:claude_code",
  "user:mcp_servers",
] as const;

const CODEX_PERCENT_HEADERS = {
  session: "x-codex-primary-used-percent",
  weekly: "x-codex-secondary-used-percent",
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
  sessionUsed: number | null;
  weeklyUsed: number | null;
  remaining5h: number | null;
  remaining7d: number | null;
  sessionResetAt: ResetAtValue;
  weeklyResetAt: ResetAtValue;
  fetchedAt: number;
  retryAt: number | null;
  error: ProviderErrorCode | null;
}

interface CacheData {
  claude?: ProviderEntry;
  codex?: ProviderEntry;
  updatedAt?: number;
}

interface ClaudePersistentState {
  lastGood?: ProviderEntry;
  retryAt?: number;
  updatedAt?: number;
}

interface BuildProviderEntryOptions {
  provider: ProviderName;
  source?: ProviderSource | null;
  plan?: string | null;
  sessionUsed?: number | null;
  weeklyUsed?: number | null;
  sessionResetAt?: ResetAtValue;
  weeklyResetAt?: ResetAtValue;
  fetchedAt?: number;
  retryAt?: number | null;
  error?: ProviderErrorCode | null;
}

interface CodexTokensRecord extends JsonObject {
  access_token?: unknown;
  refresh_token?: unknown;
  id_token?: unknown;
  account_id?: unknown;
}

interface CodexAuthFile extends JsonObject {
  tokens: CodexTokensRecord;
  last_refresh?: unknown;
}

interface ClaudeOauthRecord extends JsonObject {
  accessToken?: unknown;
  expiresAt?: unknown;
  refreshToken?: unknown;
  scopes?: unknown;
  subscriptionType?: unknown;
}

interface ClaudeCredentialsFile extends JsonObject {
  claudeAiOauth: ClaudeOauthRecord;
}

interface ErrnoLikeError {
  code?: string;
}

class UsageFetchError extends Error {
  status: number | null;
  retryAt: number | null;

  constructor(
    message: string,
    options: {
      status?: number | null;
      retryAt?: number | null;
    } = {},
  ) {
    super(message);
    this.name = "UsageFetchError";
    this.status = options.status ?? null;
    this.retryAt = options.retryAt ?? null;
  }
}

const homeDirectory = (): string => process.env.HOME ?? homedir();

const xdgCacheHome = (): string =>
  process.env.XDG_CACHE_HOME ?? join(homeDirectory(), XDG_CACHE_FALLBACK_DIR);

const claudeStatePath = (): string => join(xdgCacheHome(), PERSISTENT_CACHE_DIR, CLAUDE_STATE_FILE);

const configurePath = (): void => {
  const home = homeDirectory();
  const prefixes = [
    `${home}/.nix-profile/bin`,
    `${home}/.bun/bin`,
    "/run/current-system/sw/bin",
  ];
  const existingPath = process.env.PATH ?? "";
  process.env.PATH = [...prefixes, existingPath].filter(Boolean).join(":");
};

const nowEpoch = (): number => Math.floor(Date.now() / 1000);

const isoNow = (): string => new Date().toISOString();

const expandHomePath = (filePath: string): string =>
  filePath.startsWith("~/") ? `${homeDirectory()}/${filePath.slice(2)}` : filePath;

const isJsonObject = (value: unknown): value is JsonObject =>
  value !== null && typeof value === "object" && !Array.isArray(value);

const isNumber = (value: unknown): value is number =>
  typeof value === "number" && Number.isFinite(value);

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

const asProviderSource = (value: unknown): ProviderSource | null => (value === "api" ? "api" : null);

const asProviderError = (value: unknown): ProviderErrorCode | null =>
  value === "unavailable" ? "unavailable" : null;

const firstString = (value: unknown): string | null => {
  if (typeof value === "string") {
    return value;
  }

  if (!Array.isArray(value)) {
    return null;
  }

  for (const item of value) {
    if (typeof item === "string") {
      return item;
    }
  }

  return null;
};

const stringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];

const clampPercent = (value: unknown): number | null => {
  const parsed = asNumber(value);
  if (parsed === null) {
    return null;
  }

  return Math.max(0, Math.min(100, Math.round(parsed)));
};

const remainingPercent = (usedPercent: number | null): number | null =>
  usedPercent === null ? null : Math.max(0, 100 - usedPercent);

const providerHasValues = (entry: ProviderEntry | undefined): boolean =>
  entry !== undefined && (isNumber(entry.remaining5h) || isNumber(entry.remaining7d));

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

const buildProviderEntry = ({
  provider,
  source = null,
  plan = null,
  sessionUsed = null,
  weeklyUsed = null,
  sessionResetAt = null,
  weeklyResetAt = null,
  fetchedAt = nowEpoch(),
  retryAt = null,
  error = null,
}: BuildProviderEntryOptions): ProviderEntry => ({
  provider,
  source,
  plan,
  sessionUsed,
  weeklyUsed,
  remaining5h: remainingPercent(sessionUsed),
  remaining7d: remainingPercent(weeklyUsed),
  sessionResetAt,
  weeklyResetAt,
  fetchedAt,
  retryAt,
  error,
});

const normalizeProviderEntry = (
  provider: ProviderName,
  value: unknown,
): ProviderEntry | undefined => {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const fetchedAt = asNumber(value.fetchedAt ?? value.fetched_at);
  if (fetchedAt === null) {
    return undefined;
  }

  return buildProviderEntry({
    provider,
    source: asProviderSource(value.source),
    plan: asString(value.plan),
    sessionUsed: clampPercent(value.sessionUsed ?? value.session_used),
    weeklyUsed: clampPercent(value.weeklyUsed ?? value.weekly_used),
    sessionResetAt: asResetAtValue(value.sessionResetAt ?? value.session_reset_at),
    weeklyResetAt: asResetAtValue(value.weeklyResetAt ?? value.weekly_reset_at),
    fetchedAt,
    retryAt: asNumber(value.retryAt ?? value.retry_at),
    error: asProviderError(value.error),
  });
};

const normalizeCacheData = (value: unknown): CacheData => {
  if (!isJsonObject(value)) {
    return {};
  }

  return {
    claude: normalizeProviderEntry("claude", value.claude),
    codex: normalizeProviderEntry("codex", value.codex),
    updatedAt: asNumber(value.updatedAt ?? value.updated_at) ?? undefined,
  };
};

const normalizeClaudePersistentState = (value: unknown): ClaudePersistentState => {
  if (!isJsonObject(value)) {
    return {};
  }

  return {
    lastGood: normalizeProviderEntry("claude", value.lastGood ?? value.last_good),
    retryAt: asNumber(value.retryAt ?? value.retry_at) ?? undefined,
    updatedAt: asNumber(value.updatedAt ?? value.updated_at) ?? undefined,
  };
};

const readClaudePersistentState = (): ClaudePersistentState =>
  normalizeClaudePersistentState(parseJsonFile(claudeStatePath()));

const writeClaudePersistentState = (state: ClaudePersistentState): void => {
  try {
    writeJsonAtomic(claudeStatePath(), state);
  } catch {
    return;
  }
};

const toLastGoodEntry = (entry: ProviderEntry): ProviderEntry => ({
  ...entry,
  error: null,
  retryAt: null,
});

const hydrateClaudeEntry = (
  cacheEntry: ProviderEntry | undefined,
  state: ClaudePersistentState,
): ProviderEntry | undefined => {
  const retryAt = state.retryAt ?? cacheEntry?.retryAt ?? null;
  const lastGood = providerHasValues(state.lastGood) ? state.lastGood : undefined;
  if (providerHasValues(cacheEntry)) {
    const sessionResetAt = cacheEntry.sessionResetAt ?? lastGood?.sessionResetAt ?? null;
    const weeklyResetAt = cacheEntry.weeklyResetAt ?? lastGood?.weeklyResetAt ?? null;
    return cacheEntry.retryAt === retryAt &&
      cacheEntry.sessionResetAt === sessionResetAt &&
      cacheEntry.weeklyResetAt === weeklyResetAt
      ? cacheEntry
      : {
          ...cacheEntry,
          retryAt,
          sessionResetAt,
          weeklyResetAt,
        };
  }

  if (lastGood) {
    return {
      ...lastGood,
      fetchedAt: cacheEntry?.fetchedAt ?? lastGood.fetchedAt,
      retryAt,
      error: cacheEntry?.error ?? (retryAt === null ? lastGood.error : "unavailable"),
    };
  }

  if (cacheEntry) {
    return cacheEntry.retryAt === retryAt ? cacheEntry : { ...cacheEntry, retryAt };
  }

  if (retryAt === null && state.updatedAt === undefined) {
    return undefined;
  }

  return buildProviderEntry({
    provider: "claude",
    fetchedAt: state.updatedAt ?? nowEpoch(),
    retryAt,
    error: "unavailable",
  });
};

const readCache = (): CacheData => {
  const cache = normalizeCacheData(parseJsonFile(CACHE_PATH));
  return {
    ...cache,
    claude: hydrateClaudeEntry(cache.claude, readClaudePersistentState()),
  };
};

const writeCache = (cache: CacheData): void => {
  writeJsonAtomic(CACHE_PATH, cache);
};

const cacheIsFresh = (cache: CacheData, provider: ProviderName): boolean => {
  const entry = cache[provider];
  if (!entry) {
    return false;
  }

  if (hasRetryWindow(entry.retryAt)) {
    return true;
  }

  const ttlSeconds = entry.error === null ? PROVIDER_TTLS[provider] : ERROR_TTL_SECONDS;
  return Date.now() - entry.fetchedAt * 1000 < ttlSeconds * 1000;
};

const cacheNeedsRefresh = (cache: CacheData): boolean =>
  PROVIDER_ORDER.some((provider) => !cacheIsFresh(cache, provider));

const shouldRefreshProvider = (
  cache: CacheData,
  provider: ProviderName,
  forceRefresh: boolean,
): boolean => forceRefresh || !cacheIsFresh(cache, provider);

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

const displayPercent = (value: number | null): string => (value === null ? "--" : String(value));

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

const formatRemainingTime = (resetAt: ResetAtValue): string | null => {
  const resetEpochSeconds = toResetEpochSeconds(resetAt);
  if (resetEpochSeconds === null) {
    return null;
  }

  const remainingSeconds = Math.max(0, resetEpochSeconds - nowEpoch());
  if (remainingSeconds >= DAY_SECONDS) {
    return `${Math.ceil(remainingSeconds / DAY_SECONDS)}d`;
  }

  if (remainingSeconds >= HOUR_SECONDS) {
    return `${Math.ceil(remainingSeconds / HOUR_SECONDS)}h`;
  }

  return `${Math.max(1, Math.ceil(remainingSeconds / MINUTE_SECONDS))}m`;
};

const formatWeeklyResetSuffix = (entry: ProviderEntry): string => {
  const remainingTime = formatRemainingTime(entry.weeklyResetAt);
  return remainingTime === null
    ? ""
    : ` %{F${PROVIDER_COLORS.separator}}${remainingTime}${RESET_COLOR}`;
};

const formatProviderOutput = (provider: ProviderName, entry?: ProviderEntry): string => {
  const label = `%{F${PROVIDER_COLORS.icon}}${PROVIDER_LABELS[provider]}${RESET_COLOR}`;
  if (!entry) {
    return `${label} %{F${PROVIDER_COLORS.unknown}}--%{F${PROVIDER_COLORS.separator}}${VALUE_DIVIDER}%{F${PROVIDER_COLORS.unknown}}--${RESET_COLOR}`;
  }

  const availableValues = [entry.remaining5h, entry.remaining7d].filter(isNumber);
  if (availableValues.length === 0) {
    return `${label} %{F${PROVIDER_COLORS.unknown}}--%{F${PROVIDER_COLORS.separator}}${VALUE_DIVIDER}%{F${PROVIDER_COLORS.unknown}}--${RESET_COLOR}`;
  }

  const sessionColor = colorForRemaining(entry.remaining5h);
  const weeklyColor = colorForRemaining(entry.remaining7d);
  return `${label} %{F${sessionColor}}${displayPercent(entry.remaining5h)}%{F${PROVIDER_COLORS.separator}}${VALUE_DIVIDER}%{F${weeklyColor}}${displayPercent(entry.remaining7d)}${RESET_COLOR}${formatWeeklyResetSuffix(entry)}`;
};

const formatOutput = (cache: CacheData): string =>
  PROVIDER_ORDER.map((provider) => formatProviderOutput(provider, cache[provider])).join(SEGMENT_GAP);

const unavailableEntry = (
  provider: ProviderName,
  options: Pick<BuildProviderEntryOptions, "fetchedAt" | "retryAt"> = {},
): ProviderEntry =>
  buildProviderEntry({
    provider,
    fetchedAt: options.fetchedAt,
    retryAt: options.retryAt,
    error: "unavailable",
  });

const parseResponsePayload = (text: string): unknown => {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const retryAtFromHeader = (value: string | null): number | null => {
  if (value === null) {
    return null;
  }

  const seconds = asNumber(value);
  if (seconds !== null) {
    return nowEpoch() + Math.max(0, Math.ceil(seconds));
  }

  const parsedAt = Date.parse(value);
  return Number.isFinite(parsedAt) ? Math.max(nowEpoch(), Math.floor(parsedAt / 1000)) : null;
};

const toEpochMilliseconds = (value: unknown): number | null => {
  const numeric = asNumber(value);
  if (numeric !== null) {
    return numeric > 1_000_000_000_000 ? Math.floor(numeric) : Math.floor(numeric * 1000);
  }

  const stringValue = asString(value);
  if (stringValue === null) {
    return null;
  }

  const parsed = Date.parse(stringValue);
  return Number.isFinite(parsed) ? parsed : null;
};

const expiresWithinWindow = (value: unknown, windowMs: number): boolean => {
  const expiresAt = toEpochMilliseconds(value);
  return expiresAt !== null && Date.now() + windowMs >= expiresAt;
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

const httpForm = async (
  url: string,
  data: Record<string, string>,
  headers?: HeadersInit,
): Promise<HttpJsonResponse> =>
  httpJson(url, {
    method: "POST",
    headers,
    body: new URLSearchParams(data),
  });

const isCodexAuthFile = (value: unknown): value is CodexAuthFile =>
  isJsonObject(value) && isJsonObject(value.tokens);

const loadCodexAuth = (): { path: string; auth: CodexAuthFile } | null => {
  for (const candidatePath of CODEX_AUTH_PATHS) {
    const path = expandHomePath(candidatePath);
    const file = parseJsonFile(path);
    if (isCodexAuthFile(file)) {
      return {
        path,
        auth: file,
      };
    }
  }

  return null;
};

const resolveCodexClientId = (tokens: CodexTokensRecord): string | null => {
  const accessClaims = decodeJwtPayload(asString(tokens.access_token));
  const idClaims = decodeJwtPayload(asString(tokens.id_token));

  return (
    asString(accessClaims?.client_id) ??
    firstString(idClaims?.aud) ??
    firstString(accessClaims?.aud)
  );
};

const persistRefreshedCodexTokens = (
  authPath: string,
  auth: CodexAuthFile,
  payload: JsonObject,
): string | null => {
  const accessToken = asString(payload.access_token);
  if (!accessToken) {
    return null;
  }

  auth.tokens.access_token = accessToken;

  const refreshToken = asString(payload.refresh_token);
  if (refreshToken) {
    auth.tokens.refresh_token = refreshToken;
  }

  const idToken = asString(payload.id_token);
  if (idToken) {
    auth.tokens.id_token = idToken;
  }

  auth.last_refresh = isoNow();
  writeJsonAtomic(authPath, auth);
  return accessToken;
};

const refreshCodexAccessToken = async (
  authPath: string,
  auth: CodexAuthFile,
): Promise<string | null> => {
  const refreshToken = asString(auth.tokens.refresh_token);
  const clientId = resolveCodexClientId(auth.tokens);
  if (!refreshToken || !clientId) {
    return null;
  }

  const response = await httpForm(
    OPENAI_TOKEN_URL,
    {
      grant_type: "refresh_token",
      client_id: clientId,
      refresh_token: refreshToken,
    },
    {
      "Content-Type": FORM_CONTENT_TYPE,
    },
  );

  if (response.status !== 200 || !isJsonObject(response.payload)) {
    return null;
  }

  return persistRefreshedCodexTokens(authPath, auth, response.payload);
};

const requestCodexUsage = async (
  accessToken: string,
  accountId: string | null,
): Promise<HttpJsonResponse> =>
  httpJson(OPENAI_USAGE_URL, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: JSON_CONTENT_TYPE,
      "User-Agent": USER_AGENT,
      ...(accountId ? { "ChatGPT-Account-Id": accountId } : {}),
    },
  });

const buildCodexEntry = (payload: JsonObject, response: HttpJsonResponse): ProviderEntry => {
  const rateLimit = isJsonObject(payload.rate_limit) ? payload.rate_limit : {};
  const primaryWindow = isJsonObject(rateLimit.primary_window) ? rateLimit.primary_window : {};
  const secondaryWindow = isJsonObject(rateLimit.secondary_window) ? rateLimit.secondary_window : {};

  const sessionUsed = clampPercent(
    response.headers.get(CODEX_PERCENT_HEADERS.session) ?? primaryWindow.used_percent,
  );
  const weeklyUsed = clampPercent(
    response.headers.get(CODEX_PERCENT_HEADERS.weekly) ?? secondaryWindow.used_percent,
  );

  return buildProviderEntry({
    provider: "codex",
    source: "api",
    plan: asString(payload.plan_type),
    sessionUsed,
    weeklyUsed,
    sessionResetAt: asResetAtValue(primaryWindow.reset_at),
    weeklyResetAt: asResetAtValue(secondaryWindow.reset_at),
  });
};

const fetchCodexUsage = async (): Promise<ProviderEntry> => {
  const codexAuth = loadCodexAuth();
  if (!codexAuth) {
    throw new Error("codex auth.json not found");
  }

  const accessToken = asString(codexAuth.auth.tokens.access_token);
  const accountId = asString(codexAuth.auth.tokens.account_id);
  if (!accessToken) {
    throw new Error("codex access token missing");
  }

  let currentToken = accessToken;
  let response = await requestCodexUsage(currentToken, accountId);

  if (UNAUTHORIZED_STATUSES.has(response.status)) {
    const refreshedToken = await refreshCodexAccessToken(codexAuth.path, codexAuth.auth);
    if (refreshedToken) {
      currentToken = refreshedToken;
      response = await requestCodexUsage(currentToken, accountId);
    }
  }

  if (response.status !== 200 || !isJsonObject(response.payload)) {
    throw new Error(`codex usage request failed (${response.status})`);
  }

  return buildCodexEntry(response.payload, response);
};

const isClaudeCredentialsFile = (value: unknown): value is ClaudeCredentialsFile =>
  isJsonObject(value) && isJsonObject(value.claudeAiOauth);

const isErrnoLikeError = (value: unknown): value is ErrnoLikeError =>
  isJsonObject(value) && (value.code === undefined || typeof value.code === "string");

const loadClaudeCredentials = (): { path: string; credentials: ClaudeCredentialsFile } | null => {
  const path = expandHomePath(CLAUDE_CREDENTIALS_PATH);
  const file = parseJsonFile(path);
  return isClaudeCredentialsFile(file)
    ? {
        path,
        credentials: file,
      }
    : null;
};

const resolveClaudeScopes = (oauth: ClaudeOauthRecord): string[] => {
  const scopes = stringArray(oauth.scopes).filter((scope) => scope.trim() !== "");
  return scopes.length > 0 ? scopes : [...CLAUDE_DEFAULT_SCOPES];
};

const persistRefreshedClaudeTokens = (
  credentialsPath: string,
  credentials: ClaudeCredentialsFile,
  payload: JsonObject,
): string | null => {
  const accessToken = asString(payload.access_token);
  if (!accessToken) {
    return null;
  }

  credentials.claudeAiOauth.accessToken = accessToken;

  const refreshToken = asString(payload.refresh_token);
  if (refreshToken) {
    credentials.claudeAiOauth.refreshToken = refreshToken;
  }

  const expiresInSeconds = asNumber(payload.expires_in);
  if (expiresInSeconds !== null) {
    credentials.claudeAiOauth.expiresAt = Date.now() + Math.max(0, expiresInSeconds) * 1000;
  }

  const scope = asString(payload.scope);
  if (scope) {
    credentials.claudeAiOauth.scopes = scope.split(/\s+/).filter(Boolean);
  }

  writeJsonAtomic(credentialsPath, credentials);
  return accessToken;
};

const refreshClaudeAccessToken = async (
  credentialsPath: string,
  credentials: ClaudeCredentialsFile,
): Promise<string | null> => {
  const refreshToken = asString(credentials.claudeAiOauth.refreshToken);
  if (!refreshToken) {
    return null;
  }

  const response = await httpJson(CLAUDE_TOKEN_URL, {
    method: "POST",
    headers: {
      "Content-Type": JSON_CONTENT_TYPE,
    },
    body: JSON.stringify({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: CLAUDE_CLIENT_ID,
      scope: resolveClaudeScopes(credentials.claudeAiOauth).join(" "),
    }),
  });

  if (response.status !== 200 || !isJsonObject(response.payload)) {
    return null;
  }

  return persistRefreshedClaudeTokens(credentialsPath, credentials, response.payload);
};

const requestClaudeUsage = async (accessToken: string): Promise<HttpJsonResponse> =>
  httpJson(ANTHROPIC_USAGE_URL, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: JSON_CONTENT_TYPE,
      "Content-Type": JSON_CONTENT_TYPE,
      "User-Agent": CLAUDE_USER_AGENT,
      "anthropic-beta": ANTHROPIC_BETA,
    },
  });

const buildClaudeEntry = (
  oauth: ClaudeOauthRecord,
  payload: JsonObject,
): ProviderEntry => {
  const fiveHour = isJsonObject(payload.five_hour) ? payload.five_hour : {};
  const sevenDay = isJsonObject(payload.seven_day) ? payload.seven_day : {};

  return buildProviderEntry({
    provider: "claude",
    source: "api",
    plan: asString(oauth.subscriptionType),
    sessionUsed: clampPercent(fiveHour.utilization),
    weeklyUsed: clampPercent(sevenDay.utilization),
    sessionResetAt: asResetAtValue(fiveHour.resets_at),
    weeklyResetAt: asResetAtValue(sevenDay.resets_at),
  });
};

const fetchClaudeUsage = async (): Promise<ProviderEntry> => {
  const claudeCredentials = loadClaudeCredentials();
  if (!claudeCredentials) {
    throw new UsageFetchError("claude credentials not found");
  }

  const { path, credentials } = claudeCredentials;
  const accessToken = asString(credentials.claudeAiOauth.accessToken);
  if (!accessToken) {
    throw new UsageFetchError("claude access token missing");
  }

  let currentToken = accessToken;
  if (expiresWithinWindow(credentials.claudeAiOauth.expiresAt, CLAUDE_REFRESH_WINDOW_MS)) {
    const refreshedToken = await refreshClaudeAccessToken(path, credentials);
    if (refreshedToken) {
      currentToken = refreshedToken;
    }
  }

  let response = await requestClaudeUsage(currentToken);
  if (UNAUTHORIZED_STATUSES.has(response.status)) {
    const refreshedToken = await refreshClaudeAccessToken(path, credentials);
    if (refreshedToken) {
      currentToken = refreshedToken;
      response = await requestClaudeUsage(currentToken);
    }
  }

  if (response.status !== 200 || !isJsonObject(response.payload)) {
    throw new UsageFetchError(`claude usage request failed (${response.status})`, {
      status: response.status,
      retryAt: retryAtFromHeader(response.headers.get("retry-after")),
    });
  }

  return buildClaudeEntry(credentials.claudeAiOauth, response.payload);
};

const readRetryAt = (error: unknown): number | null =>
  error instanceof UsageFetchError ? error.retryAt : null;

const recoverProviderEntry = (
  provider: ProviderName,
  previousEntry: ProviderEntry | undefined,
  error: unknown,
): ProviderEntry => {
  const retryAt = readRetryAt(error);
  if (providerHasValues(previousEntry)) {
    return {
      ...previousEntry,
      fetchedAt: nowEpoch(),
      retryAt,
      error: "unavailable",
    };
  }

  return unavailableEntry(provider, {
    retryAt,
  });
};

const persistClaudeSuccess = (entry: ProviderEntry): void => {
  writeClaudePersistentState({
    lastGood: toLastGoodEntry(entry),
    updatedAt: nowEpoch(),
  });
};

const persistClaudeFailure = (
  state: ClaudePersistentState,
  previousEntry: ProviderEntry | undefined,
  retryAt: number | null,
): void => {
  const lastGood =
    providerHasValues(state.lastGood)
      ? toLastGoodEntry(state.lastGood)
      : providerHasValues(previousEntry)
        ? toLastGoodEntry(previousEntry)
        : undefined;

  if (lastGood === undefined && retryAt === null) {
    return;
  }

  writeClaudePersistentState({
    lastGood,
    retryAt: retryAt ?? undefined,
    updatedAt: nowEpoch(),
  });
};

const refreshCache = async (
  options: {
    forceRefresh?: boolean;
  } = {},
): Promise<CacheData> => {
  const previousCache = readCache();
  const previousClaudeState = readClaudePersistentState();
  const forceRefresh = options.forceRefresh ?? false;
  const claudeNeedsRefresh = shouldRefreshProvider(previousCache, "claude", forceRefresh);
  const codexNeedsRefresh = shouldRefreshProvider(previousCache, "codex", forceRefresh);
  const [claudeResult, codexResult] = await Promise.allSettled([
    claudeNeedsRefresh
      ? fetchClaudeUsage()
      : Promise.resolve(previousCache.claude ?? unavailableEntry("claude")),
    codexNeedsRefresh
      ? fetchCodexUsage()
      : Promise.resolve(previousCache.codex ?? unavailableEntry("codex")),
  ]);

  const claude = claudeNeedsRefresh
    ? claudeResult.status === "fulfilled"
      ? claudeResult.value
      : recoverProviderEntry("claude", previousCache.claude, claudeResult.reason)
    : previousCache.claude ?? unavailableEntry("claude");
  const codex = codexNeedsRefresh
    ? codexResult.status === "fulfilled"
      ? codexResult.value
      : recoverProviderEntry("codex", previousCache.codex, codexResult.reason)
    : previousCache.codex ?? unavailableEntry("codex");

  if (claudeNeedsRefresh && claudeResult.status === "fulfilled") {
    persistClaudeSuccess(claude);
  } else if (claudeNeedsRefresh) {
    persistClaudeFailure(previousClaudeState, previousCache.claude, readRetryAt(claudeResult.reason));
  }

  const nextCache: CacheData = {
    claude,
    codex,
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

void main().then((exitCode) => {
  process.exit(exitCode);
});
