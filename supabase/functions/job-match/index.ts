import { cors, providerFailure, readResult, reviewFormat } from "../_shared/ai-result.ts";
type Json = Record<string, unknown>;
const json = (status: number, body: Json) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, "Content-Type": "application/json" },
});
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return json(405, { error: "POST required" });
  const authorization = request.headers.get("Authorization") ?? "";
  if (!/^Bearer \S+$/.test(authorization)) return json(401, { error: "Authentication required" });
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  if (!url || !anonKey || !serviceKey || !openAiKey) return json(503, { error: "Job matching is not configured" });
  const userHeaders = { apikey: anonKey, Authorization: authorization };
  const serviceHeaders = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" };
  let matchId: string | undefined;
  let failure = "Unable to prepare review";
  try {
    const body = await request.json() as Json;
    const jobId = body.job_id;
    if (typeof jobId !== "string" || !uuid.test(jobId)) return json(400, { error: "Valid job_id required" });
    const identity = await fetch(`${url}/auth/v1/user`, { headers: userHeaders });
    if (!identity.ok) return json(401, { error: "Authentication required" });
    const user = await identity.json() as { id?: string };
    const profileResponse = await fetch(`${url}/rest/v1/profiles?id=eq.${user.id}&select=full_name`, { headers: userHeaders });
    const detailsResponse = await fetch(`${url}/rest/v1/job_seeker_profiles?user_id=eq.${user.id}&select=headline,summary,skills,preferred_job_types,preferred_work_arrangements,accommodation_needs`, { headers: userHeaders });
    const jobResponse = await fetch(`${url}/rest/v1/jobs?id=eq.${jobId}&status=eq.published&select=title,description,qualifications,required_skills,employment_type,work_arrangement,accessibility_details,employers!inner(company_name,is_active)`, { headers: userHeaders });
    if (!profileResponse.ok || !detailsResponse.ok || !jobResponse.ok) return json(403, { error: "Matching data unavailable" });
    const profileRows = await profileResponse.json() as Json[];
    const detailRows = await detailsResponse.json() as Json[];
    const jobRows = await jobResponse.json() as Json[];
    const job = jobRows[0];
    if (!job || (job.employers as Json)?.is_active !== true || !detailRows[0]) return json(404, { error: "Published job unavailable" });
    const created = await fetch(`${url}/rest/v1/job_ai_matches`, { method: "POST", headers: { ...serviceHeaders, Prefer: "return=representation" }, body: JSON.stringify({ job_id: jobId, job_seeker_id: user.id, status: "processing" }) });
    if (!created.ok) return json(503, { error: "Match record could not be created" });
    const createdRows = await created.json() as Array<{ id: string }>;
    matchId = createdRows[0]?.id;
    if (!matchId) return json(503, { error: "Match record could not be created" });
    failure = "AI request could not be sent";
    const openAi = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${openAiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MATCH_MODEL") ?? "gpt-4.1-mini",
        input: `Compare this job seeker profile with this published job. Return JSON keys: fit_summary (string), matched_skills (array), skill_gaps (array), accessibility_considerations (array). Do not infer protected characteristics, rank people, or make a hiring decision. Profile: ${JSON.stringify({ profile: profileRows[0], details: detailRows[0] })}. Job: ${JSON.stringify(job)}`,
        text: { format: reviewFormat("job_match", ["matched_skills", "skill_gaps", "accessibility_considerations"], true) },
      }),
    });
    if (!openAi.ok) {
      failure = "AI provider: " + await providerFailure(openAi);
      throw new Error(failure);
    }
    failure = "AI response could not be read";
    const completion = await openAi.json();
    const result = readResult(completion, ["matched_skills", "skill_gaps", "accessibility_considerations"], true);
    failure = "Could not save AI review";
    const saved = await fetch(`${url}/rest/v1/job_ai_matches?id=eq.${matchId}`, { method: "PATCH", headers: serviceHeaders, body: JSON.stringify({ status: "completed", result, model: completion.model ?? "unknown", completed_at: new Date().toISOString() }) });
    if (!saved.ok) throw new Error("Could not save AI review");
    return json(200, { match_id: matchId, status: "completed", result });
  } catch (_) {
    if (matchId) await fetch(`${url}/rest/v1/job_ai_matches?id=eq.${matchId}`, { method: "PATCH", headers: serviceHeaders, body: JSON.stringify({ status: "failed", error_message: failure }) }).catch(() => undefined);
    return json(422, { error: "Job match could not be completed" });
  }
});
