type Json = Record<string, unknown>;

const json = (status: number, body: Json) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json" },
});

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json(405, { error: "POST required" });
  const authorization = request.headers.get("Authorization") ?? "";
  if (!/^Bearer \S+$/.test(authorization)) return json(401, { error: "Authentication required" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey || !openAiKey) {
    return json(503, { error: "AI scanner is not configured" });
  }
  const serviceHeaders = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
  };

  let scanId: string | undefined;
  try {
    const body = await request.json() as Json;
    const resumeId = body.resume_id;
    if (typeof resumeId !== "string" || !uuid.test(resumeId)) {
      return json(400, { error: "Valid resume_id required" });
    }

    const userHeaders = { apikey: anonKey, Authorization: authorization };
    const identity = await fetch(`${supabaseUrl}/auth/v1/user`, { headers: userHeaders });
    if (!identity.ok) return json(401, { error: "Authentication required" });
    const user = await identity.json() as { id?: string };

    const ownedResume = await fetch(
      `${supabaseUrl}/rest/v1/resumes?id=eq.${resumeId}&job_seeker_id=eq.${user.id}&upload_status=eq.ready&select=id,storage_path,title`,
      { headers: userHeaders },
    );
    if (!ownedResume.ok) return json(403, { error: "Resume unavailable" });
    const resumes = await ownedResume.json() as Array<{ id: string; storage_path: string; title: string }>;
    const resume = resumes[0];
    if (!resume) return json(403, { error: "Owned ready resume required" });

    const createScan = await fetch(`${supabaseUrl}/rest/v1/resume_ai_scans`, {
      method: "POST",
      headers: { ...serviceHeaders, Prefer: "return=representation" },
      body: JSON.stringify({ resume_id: resume.id, job_seeker_id: user.id, status: "processing" }),
    });
    if (!createScan.ok) return json(503, { error: "Scanner record could not be created" });
    const scanRows = await createScan.json() as Array<{ id: string }>;
    scanId = scanRows[0]?.id;
    if (!scanId) return json(503, { error: "Scanner record could not be created" });

    // The PDF remains private. The user token is used to read only the owner's object.
    const path = resume.storage_path.split("/").map(encodeURIComponent).join("/");
    const file = await fetch(`${supabaseUrl}/storage/v1/object/authenticated/resumes/${path}`, {
      headers: userHeaders,
    });
    if (!file.ok) throw new Error("Resume file unavailable");
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length > 5 * 1024 * 1024) throw new Error("Resume file too large");
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    const base64 = btoa(binary);

    const openAi = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_RESUME_MODEL") ?? "gpt-4.1-mini",
        input: [{
          role: "user",
          content: [
            { type: "input_file", filename: "resume.pdf", file_data: `data:application/pdf;base64,${base64}` },
            { type: "input_text", text: "Review this resume for completeness and accessibility. Return JSON with keys: strengths (array of strings), missing_sections (array of strings), skills (array of strings), readability_notes (array of strings), accessibility_notes (array of strings). Do not infer protected characteristics or make hiring decisions." },
          ],
        }],
        text: { format: { type: "json_object" } },
      }),
    });
    if (!openAi.ok) throw new Error("AI provider unavailable");
    const completion = await openAi.json() as { output_text?: string; model?: string };
    const result = JSON.parse(completion.output_text ?? "{}");
    await fetch(`${supabaseUrl}/rest/v1/resume_ai_scans?id=eq.${scanId}`, {
      method: "PATCH",
      headers: serviceHeaders,
      body: JSON.stringify({ status: "completed", result, model: completion.model ?? "unknown", completed_at: new Date().toISOString() }),
    });
    return json(200, { scan_id: scanId, status: "completed", result });
  } catch (_) {
    if (scanId) {
      await fetch(`${supabaseUrl}/rest/v1/resume_ai_scans?id=eq.${scanId}`, {
        method: "PATCH",
        headers: serviceHeaders,
        body: JSON.stringify({ status: "failed", error_message: "Resume scan could not be completed" }),
      }).catch(() => undefined);
    }
    return json(422, { error: "Resume scan could not be completed" });
  }
});
