import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const ORIGIN = "https://huynhw19.github.io";
const REDIRECT_URI = "https://gwhqnqzzlgslwgijkkpt.supabase.co/functions/v1/configkit-slack?action=callback";
const SCOPES = "chat:write,channels:read";
const cors = {
  "Access-Control-Allow-Origin": ORIGIN,
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin",
};

function reply(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" },
  });
}
function redirect(url: string) {
  return new Response(null, { status: 302, headers: { Location: url, "Cache-Control": "no-store" } });
}
function randomState() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function cryptoKey() {
  const secret = Deno.env.get("SLACK_TOKEN_ENCRYPTION_KEY") || "";
  if (secret.length < 32) throw new Error("Slack token encryption is not configured.");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return crypto.subtle.importKey("raw", digest, "AES-GCM", false, ["encrypt", "decrypt"]);
}
async function encrypt(value: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await cryptoKey(), new TextEncoder().encode(value));
  return { ciphertext: btoa(String.fromCharCode(...new Uint8Array(encrypted))), iv: btoa(String.fromCharCode(...iv)) };
}
async function decrypt(ciphertext: string, ivText: string) {
  const bytes = (value: string) => Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: bytes(ivText) }, await cryptoKey(), bytes(ciphertext));
  return new TextDecoder().decode(plain);
}
function clients() {
  const url = Deno.env.get("SUPABASE_URL") || "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") || "";
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!url || !anon || !service) throw new Error("Supabase function configuration is incomplete.");
  return {
    admin: createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } }),
    anon: createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } }),
  };
}
async function authenticatedUser(req: Request) {
  const header = req.headers.get("authorization") || "";
  const token = header.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw new Response("Sign in to ConfigKit first.", { status: 401 });
  const { anon } = clients();
  const { data, error } = await anon.auth.getUser(token);
  if (error || !data.user) throw new Response("Your ConfigKit session is invalid or expired.", { status: 401 });
  return data.user;
}
async function slackRequest(method: string, token: string, body?: Record<string, string>) {
  const response = await fetch("https://slack.com/api/" + method, {
    method: body ? "POST" : "GET",
    headers: body
      ? { Authorization: "Bearer " + token, "Content-Type": "application/x-www-form-urlencoded" }
      : { Authorization: "Bearer " + token },
    body: body ? new URLSearchParams(body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  const payload = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok || payload.ok !== true) {
    const reason = typeof payload.error === "string" ? payload.error : "slack_api_error";
    throw new Error("Slack request failed (" + reason + ").");
  }
  return payload;
}
async function connection(admin: ReturnType<typeof clients>["admin"], userId: string, teamId?: string) {
  let query = admin.schema("private").from("configkit_slack_connections").select("*").eq("user_id", userId);
  if (teamId) query = query.eq("team_id", teamId);
  const { data, error } = await query.order("connected_at", { ascending: false }).limit(1).maybeSingle();
  if (error) throw new Error("Could not load the Slack connection.");
  if (!data) throw new Error("No Slack workspace is connected.");
  return data as Record<string, unknown>;
}
async function validAccessToken(admin: ReturnType<typeof clients>["admin"], row: Record<string, unknown>) {
  let access = await decrypt(String(row.access_token_ciphertext), String(row.access_token_iv));
  const expiresAt = row.expires_at ? new Date(String(row.expires_at)).getTime() : 0;
  if (expiresAt && expiresAt < Date.now() + 5 * 60 * 1000) {
    if (!row.refresh_token_ciphertext || !row.refresh_token_iv) throw new Error("Slack connection expired. Reconnect the workspace.");
    const refresh = await decrypt(String(row.refresh_token_ciphertext), String(row.refresh_token_iv));
    const form = new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refresh,
      client_id: Deno.env.get("SLACK_CLIENT_ID") || "",
      client_secret: Deno.env.get("SLACK_CLIENT_SECRET") || "",
    });
    const response = await fetch("https://slack.com/api/oauth.v2.access", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form,
      signal: AbortSignal.timeout(15000),
    });
    const payload = await response.json() as Record<string, unknown>;
    if (!response.ok || payload.ok !== true || typeof payload.access_token !== "string" || typeof payload.refresh_token !== "string") {
      throw new Error("Slack token refresh failed. Reconnect the workspace.");
    }
    const nextAccess = await encrypt(payload.access_token);
    const nextRefresh = await encrypt(payload.refresh_token);
    const expires = Number(payload.expires_in) || 43200;
    const { error } = await admin.schema("private").from("configkit_slack_connections").update({
      access_token_ciphertext: nextAccess.ciphertext, access_token_iv: nextAccess.iv,
      refresh_token_ciphertext: nextRefresh.ciphertext, refresh_token_iv: nextRefresh.iv,
      expires_at: new Date(Date.now() + expires * 1000).toISOString(), updated_at: new Date().toISOString(),
    }).eq("id", row.id);
    if (error) throw new Error("Could not save refreshed Slack credentials.");
    access = payload.access_token;
  }
  return access;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    if (req.headers.get("origin") !== ORIGIN) return new Response("Forbidden", { status: 403 });
    return new Response(null, { status: 204, headers: cors });
  }
  const incoming = new URL(req.url);
  const action = incoming.searchParams.get("action") || "";
  const isCallback = action === "callback" && req.method === "GET";
  if (!isCallback && req.headers.get("origin") !== ORIGIN) return reply({ error: "This endpoint is available through ConfigKit only." }, 403);

  try {
    const { admin } = clients();

    if (isCallback) {
      const code = incoming.searchParams.get("code") || "";
      const state = incoming.searchParams.get("state") || "";
      if (incoming.searchParams.get("error")) return redirect(ORIGIN + "/slack.html?status=denied");
      if (!code || !state || state.length > 180) return redirect(ORIGIN + "/slack.html?status=invalid");
      const stateHash = await sha256(state);
      const { data: stateRow, error: stateError } = await admin.schema("private").from("configkit_slack_oauth_states")
        .update({ used_at: new Date().toISOString() }).eq("state_hash", stateHash).is("used_at", null)
        .gt("expires_at", new Date().toISOString()).select("user_id").maybeSingle();
      if (stateError || !stateRow?.user_id) return redirect(ORIGIN + "/slack.html?status=expired");

      const clientId = Deno.env.get("SLACK_CLIENT_ID") || "";
      const clientSecret = Deno.env.get("SLACK_CLIENT_SECRET") || "";
      if (!clientId || !clientSecret) return redirect(ORIGIN + "/slack.html?status=not-configured");
      const form = new URLSearchParams({ code, client_id: clientId, client_secret: clientSecret, redirect_uri: REDIRECT_URI });
      const response = await fetch("https://slack.com/api/oauth.v2.access", {
        method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form,
        signal: AbortSignal.timeout(15000),
      });
      const payload = await response.json() as Record<string, unknown>;
      if (!response.ok || payload.ok !== true || typeof payload.access_token !== "string") return redirect(ORIGIN + "/slack.html?status=exchange-failed");
      const team = payload.team && typeof payload.team === "object" ? payload.team as Record<string, unknown> : {};
      const teamId = typeof team.id === "string" ? team.id : "";
      const teamName = typeof team.name === "string" ? team.name : "Slack workspace";
      if (!teamId) return redirect(ORIGIN + "/slack.html?status=missing-team");
      const access = await encrypt(payload.access_token);
      const refresh = typeof payload.refresh_token === "string" ? await encrypt(payload.refresh_token) : null;
      const expires = Number(payload.expires_in) || 0;
      const scopes = typeof payload.scope === "string" ? payload.scope.split(",").map((s) => s.trim()).filter(Boolean) : [];
      const { error: saveError } = await admin.schema("private").from("configkit_slack_connections").upsert({
        user_id: stateRow.user_id, team_id: teamId, team_name: teamName,
        bot_user_id: typeof payload.bot_user_id === "string" ? payload.bot_user_id : null,
        access_token_ciphertext: access.ciphertext, access_token_iv: access.iv,
        refresh_token_ciphertext: refresh?.ciphertext ?? null, refresh_token_iv: refresh?.iv ?? null,
        expires_at: expires ? new Date(Date.now() + expires * 1000).toISOString() : null,
        granted_scopes: scopes, updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,team_id" });
      if (saveError) return redirect(ORIGIN + "/slack.html?status=save-failed");
      return redirect(ORIGIN + "/slack.html?status=connected");
    }

    const user = await authenticatedUser(req);
    if (req.method !== "POST") return reply({ error: "Method not allowed." }, 405);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;

    if (body.action === "start") {
      const clientId = Deno.env.get("SLACK_CLIENT_ID") || "";
      if (!clientId || !Deno.env.get("SLACK_CLIENT_SECRET") || !Deno.env.get("SLACK_TOKEN_ENCRYPTION_KEY")) {
        return reply({ error: "Slack is not configured yet. Add the Slack app credentials and encryption key to Supabase Edge Function secrets." }, 503);
      }
      const state = randomState();
      const { error } = await admin.schema("private").from("configkit_slack_oauth_states").insert({
        user_id: user.id, state_hash: await sha256(state), expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });
      if (error) return reply({ error: "Could not start the Slack authorization flow." }, 500);
      const url = new URL("https://slack.com/oauth/v2/authorize");
      url.searchParams.set("client_id", clientId);
      url.searchParams.set("scope", SCOPES);
      url.searchParams.set("redirect_uri", REDIRECT_URI);
      url.searchParams.set("state", state);
      return reply({ url: url.toString() });
    }

    if (body.action === "status") {
      const { data, error } = await admin.schema("private").from("configkit_slack_connections")
        .select("id,team_id,team_name,granted_scopes,connected_at,expires_at")
        .eq("user_id", user.id).order("connected_at", { ascending: false });
      if (error) return reply({ error: "Could not load Slack connection status." }, 500);
      return reply({ connections: data || [] });
    }

    if (body.action === "channels") {
      const row = await connection(admin, user.id, typeof body.team_id === "string" ? body.team_id : undefined);
      const token = await validAccessToken(admin, row);
      const payload = await slackRequest("conversations.list?types=public_channel&exclude_archived=true&limit=200", token);
      const channels = Array.isArray(payload.channels) ? payload.channels.map((channel: Record<string, unknown>) => ({
        id: typeof channel.id === "string" ? channel.id : "",
        name: typeof channel.name === "string" ? channel.name : "channel",
        is_member: channel.is_member === true,
      })).filter((channel: { id: string }) => channel.id) : [];
      return reply({ channels });
    }

    if (body.action === "send") {
      const teamId = typeof body.team_id === "string" ? body.team_id : undefined;
      const channel = typeof body.channel === "string" ? body.channel.trim().slice(0, 80) : "";
      const text = typeof body.text === "string" ? body.text.trim().slice(0, 3500) : "";
      if (!channel || !text) return reply({ error: "Choose a channel and enter a message." }, 400);
      const row = await connection(admin, user.id, teamId);
      const token = await validAccessToken(admin, row);
      const payload = await slackRequest("chat.postMessage", token, { channel, text, unfurl_links: "false", unfurl_media: "false" });
      return reply({ ok: true, channel: payload.channel, ts: payload.ts });
    }

    if (body.action === "disconnect") {
      const teamId = typeof body.team_id === "string" ? body.team_id : "";
      if (!teamId) return reply({ error: "Choose a workspace to disconnect." }, 400);
      const row = await connection(admin, user.id, teamId);
      const token = await decrypt(String(row.access_token_ciphertext), String(row.access_token_iv));
      try { await slackRequest("auth.revoke", token, {}); } catch { /* Remove local credentials even if workspace-side revocation already occurred. */ }
      const { error } = await admin.schema("private").from("configkit_slack_connections").delete().eq("id", row.id).eq("user_id", user.id);
      if (error) return reply({ error: "Could not remove the saved Slack connection." }, 500);
      return reply({ ok: true });
    }

    return reply({ error: "Unknown Slack integration action." }, 400);
  } catch (error) {
    if (error instanceof Response) return error;
    const message = error instanceof Error ? error.message : "Unexpected Slack integration error.";
    return reply({ error: message }, 400);
  }
});
