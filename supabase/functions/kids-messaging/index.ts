import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\\s+/i, "");
    if (!token) return json({ error: "Sign-in required" }, 401);
    const caller = createClient(url, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false } });
    const { data: userData, error: userError } = await caller.auth.getUser(token);
    if (userError || !userData.user) return json({ error: "Your session is not valid" }, 401);
    const user = userData.user;
    const body = await req.json();
    const action = String(body.action || "");

    if (action === "set_pin" || action === "verify_pin") {
      const childId = String(body.child_id || "");
      if (!/^[0-9a-f-]{36}$/i.test(childId)) return json({ error: "Invalid child profile" }, 400);
      const { data: child, error: childError } = await admin.from("family_children")
        .select("id,parent_id,child_user_id,child_name").eq("id", childId).eq("parent_id", user.id).maybeSingle();
      if (childError || !child) return json({ error: "Child profile not found" }, 404);
      if (action === "set_pin") {
        const pin = String(body.pin || "");
        if (!/^\\d{6}$/.test(pin)) return json({ error: "Choose a six-digit PIN" }, 400);
        let childUserId = child.child_user_id as string | null;
        if (!childUserId) {
          const password = `${crypto.randomUUID()}-${crypto.randomUUID()}-K9!`;
          const email = `kid-${child.id}@children.configkit.invalid`;
          const { data: created, error: createError } = await admin.auth.admin.createUser({
            email, password, email_confirm: true,
            user_metadata: { account_type: "child_profile", child_profile_id: child.id, display_name: child.child_name },
          });
          if (createError || !created.user) return json({ error: createError?.message || "Could not create child login" }, 500);
          childUserId = created.user.id;
          const { error: linkError } = await admin.from("family_children").update({ child_user_id: childUserId })
            .eq("id", child.id).eq("parent_id", user.id);
          if (linkError) { await admin.auth.admin.deleteUser(childUserId); return json({ error: "Could not link child login securely" }, 500); }
        }
        const { error: pinError } = await admin.rpc("kids_set_pin", {
          p_child_id: child.id, p_parent_id: user.id, p_child_user_id: childUserId, p_pin: pin,
        });
        if (pinError) return json({ error: pinError.message || "Could not save PIN" }, 400);
        return json({ ok: true });
      }
      const pin = String(body.pin || "");
      if (!/^\\d{6}$/.test(pin)) return json({ error: "Enter the six-digit PIN" }, 400);
      const { data: childUserId, error: verifyError } = await admin.rpc("kids_check_pin", {
        p_child_id: child.id, p_parent_id: user.id, p_pin: pin,
      });
      if (verifyError || !childUserId) return json({ error: verifyError?.message || "Incorrect PIN" }, 401);
      const { data: link, error: linkError } = await admin.auth.admin.generateLink({
        type: "magiclink", email: `kid-${child.id}@children.configkit.invalid`,
      });
      const tokenHash = link?.properties?.hashed_token;
      if (linkError || !tokenHash) return json({ error: "Could not start child session" }, 500);
      return json({ token_hash: tokenHash });
    }

    if (action === "child_status") {
      const { data: child, error } = await admin.from("family_children")
        .select("id,child_name,messaging_enabled,friend_code").eq("child_user_id", user.id).maybeSingle();
      if (error || !child) return json({ error: "This is not a child profile" }, 403);
      if (!child.messaging_enabled) return json({ error: "Messaging is turned off by your parent or guardian" }, 403);
      return json({ child_id: child.id, child_name: child.child_name, friend_code: child.friend_code });
    }

    if (action === "send_friend_request") {
      const { data: child } = await admin.from("family_children").select("id,messaging_enabled")
        .eq("child_user_id", user.id).maybeSingle();
      if (!child || !child.messaging_enabled) return json({ error: "Messaging is not enabled" }, 403);
      const code = String(body.friend_code || "").trim().toUpperCase();
      if (!/^[A-F0-9]{16}$/.test(code)) return json({ error: "Enter the 16-character friend code" }, 400);
      const { data: friendshipId, error } = await admin.rpc("kids_send_friend_request", {
        p_requester_child_id: child.id, p_recipient_code: code,
      });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true, friendship_id: friendshipId });
    }

    if (action === "approve_friendship") {
      const { data: status, error } = await admin.rpc("kids_parent_approve_friendship", {
        p_friendship_id: String(body.friendship_id || ""), p_parent_id: user.id, p_approve: body.approve === true,
      });
      if (error) return json({ error: error.message }, 403);
      return json({ ok: true, status });
    }

    if (action === "remove_friendship") {
      const friendshipId = String(body.friendship_id || "");
      const { data: f } = await admin.from("kids_friendships").select("id,child_a_id,child_b_id").eq("id", friendshipId).maybeSingle();
      if (!f) return json({ error: "Friendship not found" }, 404);
      const { data: child } = await admin.from("family_children").select("id")
        .eq("child_user_id", user.id).in("id", [f.child_a_id, f.child_b_id]).maybeSingle();
      if (!child) return json({ error: "Not allowed" }, 403);
      const { error } = await admin.from("kids_friendships")
        .update({ status: "blocked", updated_at: new Date().toISOString() }).eq("id", friendshipId);
      if (error) return json({ error: "Could not remove friend" }, 400);
      return json({ ok: true });
    }

    if (action === "parent_remove_friendship") {
      const friendshipId = String(body.friendship_id || "");
      const { data: f } = await admin.from("kids_friendships")
        .select("id,child_a_id,child_b_id").eq("id", friendshipId).maybeSingle();
      if (!f) return json({ error: "Friendship not found" }, 404);
      const { data: owned } = await admin.from("family_children").select("id")
        .eq("parent_id", user.id).in("id", [f.child_a_id, f.child_b_id]).limit(1);
      if (!owned?.length) return json({ error: "You cannot manage this friendship" }, 403);
      const { error } = await admin.from("kids_friendships")
        .update({ status: "blocked", updated_at: new Date().toISOString() }).eq("id", friendshipId);
      if (error) return json({ error: "Could not remove this friendship" }, 400);
      return json({ ok: true });
    }

    if (action === "delete_child_profile") {
      const childId = String(body.child_id || "");
      const { data: child } = await admin.from("family_children")
        .select("id,child_user_id").eq("id", childId).eq("parent_id", user.id).maybeSingle();
      if (!child) return json({ error: "Child profile not found" }, 404);
      if (child.child_user_id) {
        const { error: deleteUserError } = await admin.auth.admin.deleteUser(child.child_user_id);
        if (deleteUserError) return json({ error: "Could not close the child sign-in securely" }, 500);
      }
      const { error } = await admin.from("family_children").delete().eq("id", child.id).eq("parent_id", user.id);
      if (error) return json({ error: "Could not delete child profile" }, 500);
      return json({ ok: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (_) {
    return json({ error: "The request could not be completed. Please try again." }, 500);
  }
});
