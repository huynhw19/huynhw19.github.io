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
  } catch {
    return null;
  }
}
function randomBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
}
function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
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
    const match = authorization.match(/^Bearer\s+(.+)$/i);
    if (!match) return json({ error: "Sign in before using email two-factor authentication." }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const publishableKey = resolveNamedKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
    const serviceKey = resolveNamedKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS")
      ?? Deno.env.get("SUPABASE_SECRET_KEY");
    if (!supabaseUrl || !publishableKey || !serviceKey) {
      throw new Error("Email two-factor authentication is not configured on the server.");
    }

    const authClient = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      global: { headers: { Authorization: `Bearer ${match[1]}` } },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser(match[1]);
    const user = userData.user;
    if (userError || !user?.id) {
      return json({ error: "Your sign-in session is invalid or expired. Please sign in again." }, 401);
    }

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
    const { data: settings, error: settingsError } = await admin
      .from("email_2fa_settings").select("enabled").eq("user_id", user.id).maybeSingle();
    if (settingsError) throw settingsError;
    const enabled = settings?.enabled === true;

    const isVerified = async () => {
      const { data, error } = await admin.from("email_2fa_verified_sessions")
        .select("session_id").eq("session_id", sessionId).eq("user_id", user.id)
        .gt("expires_at", new Date().toISOString()).maybeSingle();
      if (error) throw error;
      return !!data;
    };

    if (action === "status") {
      return json({ enabled, verified: enabled ? await isVerified() : false, email: user.email ?? null });
    }
    if (!user.email || !user.email_confirmed_at) {
      return json({ error: "Confirm your email address before using email two-factor authentication." }, 403);
    }

    if (action === "disable") {
      if (!enabled) return json({ enabled: false, verified: false });
      if (!(await isVerified())) return json({ error: "Verify your email challenge before disabling this factor." }, 403);
      const { error } = await admin.from("email_2fa_settings")
        .update({ enabled: false, updated_at: new Date().toISOString() }).eq("user_id", user.id);
      if (error) throw error;
      await admin.from("email_2fa_verified_sessions").delete().eq("user_id", user.id);
      return json({ enabled: false, verified: false });
    }

    if (action === "enable" && enabled) {
      return json({ enabled: true, verified: await isVerified() });
    }

    if (action === "send" && !enabled) {
      return json({ error: "Email two-factor authentication is not enabled for this account." }, 409);
    }
    if (!["enable", "send", "verify"].includes(action)) {
      return json({ error: "Unsupported action." }, 400);
    }

    if (action === "verify") {
      const token = typeof body.token === "string" ? body.token : "";
      const code = typeof body.code === "string" ? body.code.replace(/\s/g, "") : "";
      if (token.length > 128 || (!token && !/^\d{8}$/.test(code))) return json({ error: "Enter the eight-digit code from your email." }, 400);

      const suppliedHash = await sha256(token || code);
      const baseChallengeQuery = admin.from("email_2fa_challenges")
        .select("id,purpose,code_hash,link_hash,attempts,expires_at")
        .eq("user_id", user.id).is("consumed_at", null)
        .gt("expires_at", new Date().toISOString());
      let challengeQuery = token
        ? baseChallengeQuery.eq("link_hash", suppliedHash)
        : baseChallengeQuery.eq("session_id", sessionId);
      let { data: challenge, error: challengeError } = await challengeQuery
        .order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (challengeError) throw challengeError;

      if (!challenge || challenge.attempts >= 5) return json({ error: "That verification request has expired. Send a new code." }, 400);

      const expectedHash = token ? challenge.link_hash : challenge.code_hash;
      if (!safeEqual(suppliedHash, expectedHash)) {
        await admin.from("email_2fa_challenges").update({ attempts: challenge.attempts + 1 })
          .eq("id", challenge.id).eq("attempts", challenge.attempts).is("consumed_at", null);
        return json({ error: "That code or link is invalid. Check your email and try again." }, 400);
      }

      const now = new Date();
      const { data: consumed, error: consumeError } = await admin.from("email_2fa_challenges")
        .update({ consumed_at: now.toISOString() }).eq("id", challenge.id)
        .is("consumed_at", null).gt("expires_at", now.toISOString())
        .select("id").maybeSingle();
      if (consumeError) throw consumeError;
      if (!consumed) return json({ error: "That verification request has already been used. Send a new code." }, 409);

      if (challenge.purpose === "enroll") {
        const { error } = await admin.from("email_2fa_settings").upsert({
          user_id: user.id, enabled: true, updated_at: now.toISOString(),
        }, { onConflict: "user_id" });
        if (error) throw error;
      } else if (!enabled) {
        return json({ error: "Email two-factor authentication is no longer enabled." }, 409);
      }

      const { error: sessionError } = await admin.from("email_2fa_verified_sessions").upsert({
        session_id: sessionId, user_id: user.id, verified_at: now.toISOString(),
        expires_at: new Date(now.getTime() + 8 * 60 * 60 * 1000).toISOString(),
      }, { onConflict: "session_id" });
      if (sessionError) throw sessionError;
      return json({ success: true, enabled: true, verified: true, expiresInSeconds: 28800 });
    }

    // Issue a new single-use challenge. Only one active challenge is kept per session.
    const purpose = action === "enable" ? "enroll" : "login";
    if (purpose === "enroll" && enabled) return json({ error: "Email two-factor authentication is already enabled." }, 409);
    const { data: recent, error: recentError } = await admin.from("email_2fa_challenges")
      .select("created_at").eq("user_id", user.id).eq("session_id", sessionId)
      .gt("created_at", new Date(Date.now() - 30_000).toISOString())
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (recentError) throw recentError;
    if (recent) return json({ error: "Please wait 30 seconds before requesting another email." }, 429);

    await admin.from("email_2fa_challenges").update({ consumed_at: new Date().toISOString() })
      .eq("user_id", user.id).eq("session_id", sessionId).is("consumed_at", null);

    const code = String(new DataView(randomBytes(4).buffer).getUint32(0) % 100_000_000).padStart(8, "0");
    const linkToken = base64url(randomBytes(32));
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    const { error: insertError } = await admin.from("email_2fa_challenges").insert({
      user_id: user.id, session_id: sessionId, purpose,
      code_hash: await sha256(code), link_hash: await sha256(linkToken),
      expires_at: expiresAt.toISOString(),
    });
    if (insertError) throw insertError;

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const emailFrom = Deno.env.get("EMAIL_FROM");
    if (!resendKey || !emailFrom) {
      throw new Error("Email delivery is not configured. Add RESEND_API_KEY and EMAIL_FROM to Supabase Edge Function secrets.");
    }
    const link = `https://huynhw19.github.io/login.html?email_2fa_token=${encodeURIComponent(linkToken)}`;
    const subject = purpose === "enroll" ? "Enable ConfigKit email two-factor authentication" : "Your ConfigKit sign-in verification";
    const html = `<div style="font-family:Arial,sans-serif;line-height:1.6;color:#17231f;max-width:560px;margin:auto"><h2>ConfigKit verification</h2><p>Use this one-time code to ${purpose === "enroll" ? "enable email two-factor authentication" : "finish signing in"}:</p><p style="font-size:30px;letter-spacing:7px;font-weight:700">${code}</p><p>This code expires in 5 minutes and can be used once.</p><p>Or use this one-time verification link:</p><p><a href="${link}">Verify this sign-in</a></p><p>If you did not request this, you can ignore this email.</p></div>`;
    const mail = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: emailFrom, to: [user.email], subject, html, text: `Your ConfigKit verification code is ${code}. It expires in 5 minutes. Or open: ${link}` }),
    });
    if (!mail.ok) {
      const detail = await mail.text();
      throw new Error(`The verification email could not be sent. Email provider response: ${detail.slice(0, 300)}`);
    }
    return json({ sent: true, expiresInSeconds: 300, destination: user.email });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected server error.";
    console.error("email-2fa error:", message);
    return json({ error: message }, 500);
  }
});
