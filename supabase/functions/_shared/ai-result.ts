export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
};

export function reviewFormat(name: string, lists: string[], summary = false) {
  const properties: Record<string, unknown> = {};
  if (summary) properties.fit_summary = { type: "string" };
  for (const key of lists) properties[key] = { type: "array", items: { type: "string" } };
  return { type: "json_schema", name, strict: true, schema: {
    type: "object", properties, required: Object.keys(properties), additionalProperties: false,
  } };
}

export async function providerFailure(response: Response) {
  const body = await response.json().catch(() => null);
  const known = ["insufficient_quota", "invalid_api_key", "model_not_found", "rate_limit_exceeded"];
  const code = body?.error?.code;
  return known.includes(code) ? code as string : "HTTP " + response.status;
}

export function readResult(response: { status?: string; output?: Array<{
  type: string; content?: Array<{ type: string; text?: string }>;
}> }, lists: string[], summary = false) {
  if (response.status !== "completed") throw new Error("Incomplete AI response");
  const text = (response.output ?? []).filter(item => item.type === "message")
    .flatMap(item => item.content ?? []).filter(part => part.type === "output_text")
    .map(part => part.text).join("");
  const result = JSON.parse(text);
  if (!result || lists.some(key => !Array.isArray(result[key]) ||
    !result[key].every((value: unknown) => typeof value === "string")) ||
    (summary && (typeof result.fit_summary !== "string" || !result.fit_summary.trim()))) {
    throw new Error("Invalid AI review");
  }
  return result;
}
