// Non-AI file validation. No credentials are embedded; use Supabase runtime variables.
const response = (status: number, message: string) => new Response(
  JSON.stringify({ message }), { status, headers: { "Content-Type": "application/json" } },
);

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return response(405, "POST required");
  const authorization = request.headers.get("Authorization") ?? "";
  if (!/^Bearer \S+$/.test(authorization)) return response(401, "Authentication required");
  const url = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publicKey || !serverKey) return response(503, "Service unavailable");
  try {
    const body = await request.json();
    if (typeof body.resume_id !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.resume_id)) {
      return response(400, "Valid resume_id required");
    }
    const headers = { apikey: publicKey, Authorization: authorization };
    const identity = await fetch(`${url}/auth/v1/user`, { headers });
    if (!identity.ok) return response(401, "Authentication required");
    const user = await identity.json();
    const records = await fetch(`${url}/rest/v1/resumes?id=eq.${body.resume_id}&select=id,job_seeker_id,storage_path,upload_status`, { headers });
    if (!records.ok) return response(403, "Resume unavailable");
    const rows = await records.json();
    const row = rows[0];
    if (!row || row.job_seeker_id !== user.id || row.upload_status !== "pending") {
      return response(403, "Owned pending resume required");
    }
    const path = row.storage_path.split("/").map(encodeURIComponent).join("/");
    const file = await fetch(`${url}/storage/v1/object/authenticated/resumes/${path}`, { headers });
    if (!file.ok) return response(422, "Uploaded PDF required");
    // Bucket caps uploads; bound streamed reads as defense in depth.
    const reader = file.body?.getReader();
    if (!reader) return response(422, "Empty file");
    const prefix: number[] = [];
    let size = 0;
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 5 * 1024 * 1024) { await reader.cancel(); return response(422, "File too large"); }
      for (const byte of value) { if (prefix.length === 5) break; prefix.push(byte); }
    }
    if (new TextDecoder().decode(new Uint8Array(prefix)) !== "%PDF-" || size < 5) {
      return response(422, "PDF signature required");
    }
    const result = await fetch(`${url}/rest/v1/rpc/finalize_resume_upload`, {
      method: "POST",
      headers: { apikey: serverKey, Authorization: `Bearer ${serverKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_resume_id: row.id }),
    });
    return result.ok ? response(200, "Resume ready") : response(409, "Resume could not be finalized");
  } catch {
    return response(400, "Unable to process resume");
  }
});
