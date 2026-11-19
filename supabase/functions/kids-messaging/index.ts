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
    const authHeader = (req.headers.get("Authorization") || "").trim();
    const token = authHeader.toLowerCase().startsWith("bearer ") ? authHeader.slice(7).trim() : authHeader;
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
        if (pin.length !== 6 || [...pin].some((char) => char < "0" || char > "9")) return json({ error: "Choose a six-digit PIN" }, 400);
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
      if (!child.child_user_id) return json({ error: "This profile has no PIN yet. Ask your parent or guardian to set one in Family Dashboard." }, 409);
      const pin = String(body.pin || "");
      if (pin.length !== 6 || [...pin].some((char) => char < "0" || char > "9")) return json({ error: "Enter the six-digit PIN" }, 400);
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
        .select("id,child_name,messaging_enabled,call_enabled,friend_code").eq("child_user_id", user.id).maybeSingle();
      if (error || !child) return json({ error: "This is not a child profile" }, 403);
      if (!child.messaging_enabled) return json({ error: "Messaging is turned off by your parent or guardian" }, 403);
      return json({ child_id: child.id, child_name: child.child_name, friend_code: child.friend_code, call_enabled: child.call_enabled });
    }

    if (action === "call_permission") {
      const friendshipId = String(body.friendship_id || "");
      const { data: child } = await admin.from("family_children").select("id,call_enabled,messaging_enabled")
        .eq("child_user_id", user.id).maybeSingle();
      if (!child || !child.messaging_enabled || !child.call_enabled) return json({ allowed: false });
      const { data: friendship } = await admin.from("kids_friendships")
        .select("id,child_a_id,child_b_id,parent_a_approved,parent_b_approved,teacher_approved_at,status")
        .eq("id", friendshipId).maybeSingle();
      if (!friendship || friendship.status !== "approved" || !friendship.parent_a_approved || !friendship.parent_b_approved || !friendship.teacher_approved_at ||
          ![friendship.child_a_id, friendship.child_b_id].includes(child.id)) return json({ allowed: false });
      const otherId = friendship.child_a_id === child.id ? friendship.child_b_id : friendship.child_a_id;
      const { data: other } = await admin.from("family_children").select("call_enabled,messaging_enabled")
        .eq("id", otherId).maybeSingle();
      return json({ allowed: !!other?.call_enabled && !!other?.messaging_enabled });
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


    if (action === "lookup_education_student") {
      const childId = String(body.child_id || "");
      const { data: child } = await admin.from("family_children").select("id").eq("id", childId).eq("parent_id", user.id).maybeSingle();
      if (!child) return json({ error: "Child profile not found" }, 404);
      const studentCode = String(body.student_id || "").trim();
      if (!studentCode) {
        const { data: link } = await admin.from("kids_education_links").select("education_student_id").eq("child_id", childId).maybeSingle();
        if (!link) return json({ linked: false });
        const { data: record } = await admin.from("education_students").select("student_name,school,grade").eq("id", link.education_student_id).maybeSingle();
        return json({ linked: !!record, student_name: record?.student_name || "", school: record?.school || "", grade: record?.grade || "" });
      }
      if (studentCode.length > 100) return json({ error: "Student ID is not valid" }, 400);
      const { data: record } = await admin.from("education_students").select("id,student_name,school,grade").eq("student_id", studentCode).maybeSingle();
      if (!record) return json({ found: false });
      return json({ found: true, student_name: record.student_name, school: record.school || "", grade: record.grade || "" });
    }

    if (action === "link_education_student") {
      const childId = String(body.child_id || "");
      const studentCode = String(body.student_id || "").trim();
      if (body.confirm !== true || !studentCode || studentCode.length > 100) return json({ error: "Confirm the student record before linking" }, 400);
      const { data: child } = await admin.from("family_children").select("id").eq("id", childId).eq("parent_id", user.id).maybeSingle();
      if (!child) return json({ error: "Child profile not found" }, 404);
      const { data: record } = await admin.from("education_students").select("id,student_name").eq("student_id", studentCode).maybeSingle();
      if (!record) return json({ error: "Student ID was not found. Check it with the teacher." }, 404);
      const { data: existing } = await admin.from("kids_education_links").select("child_id").eq("education_student_id", record.id).maybeSingle();
      if (existing && existing.child_id !== childId) return json({ error: "This student record is already linked to another family profile" }, 409);
      const { error } = await admin.from("kids_education_links").upsert({ child_id: childId, education_student_id: record.id, linked_by: user.id }, { onConflict: "child_id" });
      if (error) return json({ error: "Could not link the student record" }, 400);
      return json({ ok: true, student_name: record.student_name });
    }

    if (action === "unlink_education_student") {
      const childId = String(body.child_id || "");
      const { data: child } = await admin.from("family_children").select("id").eq("id", childId).eq("parent_id", user.id).maybeSingle();
      if (!child) return json({ error: "Child profile not found" }, 404);
      const { error } = await admin.from("kids_education_links").delete().eq("child_id", childId);
      if (error) return json({ error: "Could not unlink the student record" }, 400);
      await admin.from("kids_teacher_contacts").delete().eq("child_id", childId);
      return json({ ok: true });
    }

    if (action === "teacher_students") {
      const { data: records, error } = await admin.from("education_students")
        .select("id,student_name,grade,school").eq("user_id", user.id);
      if (error) return json({ error: "Could not load linked student records" }, 400);
      const recordIds = (records || []).map((row) => row.id);
      if (!recordIds.length) return json({ students: [] });
      const { data: links, error: linkError } = await admin.from("kids_education_links")
        .select("child_id,education_student_id").in("education_student_id", recordIds);
      if (linkError) return json({ error: "Could not load parent-approved student links" }, 400);
      const byRecord = new Map((records || []).map((row) => [row.id, row]));
      const students = [];
      for (const link of (links || [])) {
        const record = byRecord.get(link.education_student_id);
        const { data: child } = await admin.from("family_children")
          .select("id,child_name,child_user_id,messaging_enabled").eq("id", link.child_id).maybeSingle();
        if (!child || !child.child_user_id || !child.messaging_enabled || !record) continue;
        const { data: contact } = await admin.from("kids_teacher_contacts")
          .select("requested_at,approved_at").eq("child_id", child.id)
          .eq("teacher_user_id", user.id).maybeSingle();
        students.push({ child_id: child.id, child_name: child.child_name || record.student_name || "Linked student",
          grade: record.grade || "", school: record.school || "",
          requested_at: contact?.requested_at || null, approved: !!contact?.approved_at });
      }
      return json({ students });
    }

    if (action === "request_teacher_contact") {
      const childId = String(body.child_id || "");
      const { data: child } = await admin.from("family_children")
        .select("id,child_user_id,messaging_enabled").eq("id", childId).maybeSingle();
      if (!child?.child_user_id || !child.messaging_enabled) return json({ error: "Student profile is not available for messaging" }, 404);
      const { data: teacherRecords } = await admin.from("education_students").select("id").eq("user_id", user.id);
      const recordIds = (teacherRecords || []).map((row) => row.id);
      const { data: linked } = recordIds.length ? await admin.from("kids_education_links").select("id")
        .eq("child_id", child.id).in("education_student_id", recordIds).maybeSingle() : { data: null };
      if (!linked) return json({ error: "This student has not been linked to your class by their parent or guardian" }, 403);
      const { error } = await admin.from("kids_teacher_contacts").upsert({
        child_id: child.id, teacher_user_id: user.id, requested_at: new Date().toISOString(),
        approved_at: null, approved_by: null,
      }, { onConflict: "child_id,teacher_user_id" });
      if (error) return json({ error: "Could not send parent permission request" }, 400);
      return json({ ok: true, status: "pending" });
    }

    if (action === "review_teacher_contact") {
      const childId = String(body.child_id || "");
      const teacherId = String(body.teacher_user_id || "");
      const approve = body.approve === true;
      const { data: child } = await admin.from("family_children")
        .select("id,child_user_id").eq("id", childId).eq("parent_id", user.id).maybeSingle();
      if (!child) return json({ error: "Child profile not found" }, 404);
      if (approve) {
        const { data: teacherRecords } = await admin.from("education_students").select("id").eq("user_id", teacherId);
        const recordIds = (teacherRecords || []).map((row) => row.id);
        const { data: linked } = recordIds.length ? await admin.from("kids_education_links").select("id")
          .eq("child_id", child.id).in("education_student_id", recordIds).maybeSingle() : { data: null };
        if (!linked) return json({ error: "This teacher is no longer linked to the student" }, 403);
      }
      const { data: request } = await admin.from("kids_teacher_contacts").select("id")
        .eq("child_id", child.id).eq("teacher_user_id", teacherId).maybeSingle();
      if (!request) return json({ error: "Teacher permission request not found" }, 404);
      const { error } = approve
        ? await admin.from("kids_teacher_contacts").update({
            approved_at: new Date().toISOString(), approved_by: user.id,
          }).eq("id", request.id)
        : await admin.from("kids_teacher_contacts").delete().eq("id", request.id);
      if (error) return json({ error: "Could not update teacher permission" }, 400);
      return json({ ok: true, approved: approve });
    }

    if (action === "child_contacts") {
      const { data: child } = await admin.from("family_children")
        .select("id,parent_id,child_name,messaging_enabled").eq("child_user_id", user.id).maybeSingle();
      if (!child || !child.messaging_enabled) return json({ error: "Messaging is not enabled for this child" }, 403);
      const contacts = [];
      const { data: parentData } = await admin.auth.admin.getUserById(child.parent_id);
      contacts.push({
        adult_user_id: child.parent_id, role: "Parent or guardian",
        display_name: parentData?.user?.user_metadata?.display_name || "Parent or guardian",
      });
      const { data: teacherRows } = await admin.from("kids_teacher_contacts")
        .select("teacher_user_id").eq("child_id", child.id).not("approved_at", "is", null);
      for (const row of (teacherRows || [])) {
        const { data: teacherData } = await admin.auth.admin.getUserById(row.teacher_user_id);
        contacts.push({
          adult_user_id: row.teacher_user_id, role: "Teacher",
          display_name: teacherData?.user?.user_metadata?.display_name || teacherData?.user?.user_metadata?.full_name || "Approved teacher",
        });
      }
      return json({ contacts });
    }

    if (action === "teacher_friend_requests") {
      const { data: records } = await admin.from("education_students").select("id").eq("user_id", user.id);
      const recordIds = (records || []).map((row) => row.id);
      if (!recordIds.length) return json({ requests: [] });
      const { data: links } = await admin.from("kids_education_links").select("child_id,education_student_id").in("education_student_id", recordIds);
      const childIds = (links || []).map((row) => row.child_id);
      if (childIds.length < 2) return json({ requests: [] });
      const { data: childRows } = await admin.from("family_children").select("id,child_name").in("id", childIds);
      const children = childRows || [];
      const approvedChildIds = children.map((row) => row.id);
      if (approvedChildIds.length < 2) return json({ requests: [] });
      const { data: rows, error } = await admin.from("kids_friendships")
        .select("id,child_a_id,child_b_id,parent_a_approved,parent_b_approved,status")
        .in("child_a_id", approvedChildIds).in("child_b_id", approvedChildIds)
        .eq("status", "pending").eq("parent_a_approved", true).eq("parent_b_approved", true);
      if (error) return json({ error: "Could not load classmate approval requests" }, 400);
      const byId = new Map(children.map((row) => [row.id, row.child_name]));
      return json({ requests: (rows || []).map((row) => ({
        friendship_id: row.id, child_a_name: byId.get(row.child_a_id) || "Student",
        child_b_name: byId.get(row.child_b_id) || "Student",
      })) });
    }

    if (action === "teacher_approve_friendship") {
      const friendshipId = String(body.friendship_id || "");
      const { data: f } = await admin.from("kids_friendships")
        .select("id,child_a_id,child_b_id,parent_a_approved,parent_b_approved,status")
        .eq("id", friendshipId).maybeSingle();
      if (!f || f.status !== "pending" || !f.parent_a_approved || !f.parent_b_approved) {
        return json({ error: "Both families must approve before teacher review" }, 409);
      }
      const { data: teacherRecords } = await admin.from("education_students").select("id").eq("user_id", user.id);
      const recordIds = (teacherRecords || []).map((row) => row.id);
      const { data: links } = recordIds.length ? await admin.from("kids_education_links").select("child_id")
        .in("child_id", [f.child_a_id, f.child_b_id]).in("education_student_id", recordIds) : { data: [] };
      if ((links || []).length < 2) return json({ error: "Only a teacher linked to both students can approve this connection" }, 403);
      const { error } = await admin.from("kids_friendships").update({
        teacher_approved_by: user.id, teacher_approved_at: new Date().toISOString(),
        status: "approved", updated_at: new Date().toISOString(),
      }).eq("id", friendshipId);
      if (error) return json({ error: "Could not approve this classmate connection" }, 400);
      return json({ ok: true, status: "approved" });
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
