import { createClient } from "npm:@supabase/supabase-js@2";
const allowedOrigin = "https://huynhw19.github.io";
const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
function resolveNamedKey(variableName: string, mappingName: string): string | null {
  const direct = Deno.env.get(variableName);
  if (direct) return direct;
  const rawMapping = Deno.env.get(mappingName);
  if (!rawMapping) return null;
  try {
    const mapping = JSON.parse(rawMapping);
    const configured = mapping.default;
    if (typeof configured !== "string") return null;
    return configured.startsWith("sb_") ? configured : Deno.env.get(configured) ?? null;
  } catch { return null; }
}
function randomBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
}
function hex(bytes: Uint8Array): string {
  return Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
}
function formatCode(value: string): string {
  return value.match(/.{1,8}/g)?.join("-") ?? value;
}
function normalizeCode(value: string): string {
  return value.toUpperCase().replace(/[^0-9A-F]/g, "");
}
async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return hex(new Uint8Array(digest));
}
function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  if (origin && origin !== allowedOrigin) return json({ error: "Origin not allowed." }, 403);
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);
  try {
    const authorization = req.headers.get("authorization") ?? "";
    const match = authorization.match(/^Bearer\\s+(.+)$/i);
    if (!match) return json({ error: "Sign in before using recovery codes." }, 401);
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const publishableKey = resolveNamedKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
    const serviceKey = resolveNamedKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS") ?? Deno.env.get("SUPABASE_SECRET_KEY");
    if (!supabaseUrl || !publishableKey || !serviceKey) throw new Error("Recovery codes are not configured on the server.");

    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      global: { headers: { Authorization: `Bearer ${match[1]}` } },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser(match[1]);
    const user = userData.user;
    if (userError || !user?.id) return json({ error: "Your sign-in session is invalid or expired. Please sign in again." }, 401);

    let claims: Record<string, unknown>;
    try {
      const payload = match[1].split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      claims = JSON.parse(atob(payload + "=".repeat((4 - payload.length % 4) % 4)));
    } catch {
      return json({ error: "The sign-in session is invalid. Please sign in again." }, 401);
    }
    const sessionId = typeof claims.session_id === "string" ? claims.session_id : "";
    if (!sessionId) return json({ error: "The sign-in session could not be identified. Please sign in again." }, 401);

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });
    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const statusResult = await admin.rpc("get_recovery_code_status", { p_user_id: user.id, p_session_id: sessionId });
    if (statusResult.error) throw statusResult.error;
    const statusRow = Array.isArray(statusResult.data) ? statusResult.data[0] : statusResult.data;
    const recoveryStatus = statusRow ?? { enabled: false, remaining: 0, verified: false };

    const isTrustedSession = async (): Promise<boolean> => {
      if (claims.aal === "aal2" || recoveryStatus.verified === true) return true;
      const { data, error } = await admin.from("email_2fa_verified_sessions")
        .select("session_id").eq("session_id", sessionId).eq("user_id", user.id)
        .gt("expires_at", new Date().toISOString()).maybeSingle();
      if (error) throw error;
      return !!data;
    };
    const hasVerifiedTotp = async (): Promise<boolean> => {
      const { data, error } = await authClient.auth.mfa.listFactors();
      if (error) throw error;
      return (data.totp || []).some((factor: { status: string }) => factor.status === "verified");
    };

    if (action === "status") {
      return json({
        enabled: recoveryStatus.enabled === true,
        remaining: Number(recoveryStatus.remaining ?? 0),
        verified: recoveryStatus.verified === true,
      });
    }
    if (action === "generate") {
      if (!(await isTrustedSession())) return json({ error: "Complete your authenticator or email second-factor check before generating recovery codes." }, 403);
      if (!(await hasVerifiedTotp())) return json({ error: "Enroll and verify an authenticator app before generating TOTP recovery codes." }, 409);
      const rawCodes = Array.from({ length: 10 }, () => hex(randomBytes(16)).toUpperCase());
      const hashes = await Promise.all(rawCodes.map(code => sha256(code)));
      const { error } = await admin.rpc("replace_recovery_codes", { p_user_id: user.id, p_code_hashes: hashes });
      if (error) throw error;
      return json({
        generated: true,
        count: rawCodes.length,
        remaining: rawCodes.length,
        codes: rawCodes.map(formatCode),
        message: "Save these codes now. They will not be shown again; generating a new set invalidates every previous code.",
      });
    }
    if (action === "revoke") {
      if (!(await isTrustedSession())) return json({ error: "Complete a second-factor check before removing recovery codes." }, 403);
      const { error } = await admin.rpc("clear_recovery_codes", { p_user_id: user.id });
      if (error) throw error;
      return json({ enabled: false, remaining: 0, revoked: true });
    }
    if (action === "verify") {
      // Recovery codes remain usable if the user has lost or removed the authenticator.
      // Issuance still requires a verified TOTP factor; redemption only requires the
      // authenticated primary session plus an unused one-time code.
      const supplied = typeof body.code === "string" ? normalizeCode(body.code) : "";
      if (!/^[0-9A-F]{32}$/.test(supplied)) return json({ error: "Enter one of your 32-character recovery codes." }, 400);
      const result = await admin.rpc("consume_recovery_code", {
        p_user_id: user.id, p_session_id: sessionId, p_code_hash: await sha256(supplied),
      });
      if (result.error) throw result.error;
      if (result.data === "rate_limited") return json({ error: "Too many recovery-code attempts. Wait 15 minutes before trying again." }, 429);
      if (result.data !== "success") return json({ error: "That recovery code is invalid or has already been used." }, 400);
      return json({ success: true, verified: true, expiresInSeconds: 28800 });
    }
    return json({ error: "Unsupported action." }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected server error.";
    console.error("recovery-codes error:", message);
    return json({ error: "Recovery-code service is temporarily unavailable. Please try again." }, 500);
  }
});
