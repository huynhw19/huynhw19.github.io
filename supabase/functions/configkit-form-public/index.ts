import { createClient } from "https://esm.sh/@supabase/supabase-js@2.112.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SITE_ORIGIN = "https://huynhw19.github.io";
const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const corsHeaders = {
  "Access-Control-Allow-Origin": SITE_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}
function isObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}
function validateAnswers(fields: any[], answers: unknown): string | null {
  if (!Array.isArray(fields) || fields.length < 1 || fields.length > 50 || !isObject(answers)) return "The response format is invalid.";
  const ids = new Set<string>();
  for (const field of fields) {
    if (!field || typeof field.id !== "string" || ids.has(field.id) || typeof field.label !== "string") return "This form contains an invalid question.";
    ids.add(field.id);
  }
  const keys = Object.keys(answers);
  if (keys.length > fields.length || keys.some((key) => !ids.has(key))) return "The response contains unexpected fields.";
  if (JSON.stringify(answers).length > 30000) return "Your response is too large.";
  for (const field of fields) {
    const value = answers[field.id];
    const type = field.type;
    const options = Array.isArray(field.options) ? field.options.filter((x: unknown) => typeof x === "string") : [];
    const missing = value === undefined || value === null || value === "" || (Array.isArray(value) && value.length === 0);
    if (field.required && (missing || (type === "checkbox" && value !== true))) return "Please complete all required questions.";
    if (missing) continue;
    if (type === "checkbox") {
      if (typeof value !== "boolean") return "A yes/no answer is invalid.";
    } else if (type === "multi") {
      if (!Array.isArray(value) || value.length > 20 || value.some((v) => typeof v !== "string" || !options.includes(v))) return "A checkbox answer is invalid.";
    } else if (["single", "dropdown"].includes(type)) {
      if (typeof value !== "string" || !options.includes(value)) return "A choice answer is invalid.";
    } else if (type === "rating") {
      if (!["1", "2", "3", "4", "5"].includes(String(value))) return "A rating answer is invalid.";
    } else if (type === "email") {
      if (typeof value !== "string" || value.length > 320 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return "Enter a valid email address.";
    } else if (type === "number") {
      if (typeof value !== "string" || value.length > 100 || !Number.isFinite(Number(value))) return "Enter a valid number.";
    } else if (type === "date") {
      if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(value))) return "Enter a valid date.";
    } else if (type === "short" || type === "paragraph") {
      const limit = type === "paragraph" ? 3000 : 500;
      if (typeof value !== "string" || value.length > limit) return "A text answer is too long.";
    } else {
      return "This form contains an unsupported question type.";
    }
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const origin = req.headers.get("origin");
  if (origin && origin !== SITE_ORIGIN) return reply({ error: "Origin not allowed." }, 403);
  if (req.method !== "POST") return reply({ error: "Method not allowed." }, 405);
  let body: any;
  try { body = await req.json(); } catch { return reply({ error: "Invalid JSON request." }, 400); }
  if (!body || typeof body !== "object" || typeof body.action !== "string") return reply({ error: "Invalid request." }, 400);
  const token = typeof body.token === "string" ? body.token : "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(token)) return reply({ error: "This form link is invalid." }, 400);
  const { data: form, error } = await admin.from("configkit_forms")
    .select("id,public_token,title,description,fields,settings,status,accepting_responses")
    .eq("public_token", token).eq("status", "published").maybeSingle();
  if (error) {
    console.error("ConfigKit form lookup failed:", error.message);
    return reply({ error: "The form could not be loaded. Please try again." }, 500);
  }
  if (!form) return reply({ error: "This form is unavailable." }, 404);
  if (body.action === "get") return reply({ form });
  if (body.action !== "submit") return reply({ error: "Unknown action." }, 400);
  // A quiet honeypot catches basic automated form fills without collecting respondent identifiers.
  if (typeof body.website === "string" && body.website.length > 0) return reply({ ok: true });
  if (!form.accepting_responses) return reply({ error: "This form is currently closed." }, 409);
  const validationError = validateAnswers(form.fields, body.answers);
  if (validationError) return reply({ error: validationError }, 400);
  const { error: insertError } = await admin.from("configkit_form_submissions").insert({
    form_id: form.id,
    answers: body.answers,
  });
  if (insertError) {
    console.error("ConfigKit form submission failed:", insertError.message);
    return reply({ error: "Your response could not be saved. Please try again." }, 500);
  }
  return reply({ ok: true });
});
