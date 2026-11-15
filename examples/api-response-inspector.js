/**
 * ConfigKit example: API Response Inspector
 * A small browser/Node-compatible helper for inspecting HTTP API responses.
 *
 * Usage:
 *   const result = await inspectApiResponse("/api/health");
 *   console.log(result);
 *
 * This helper does not log request headers or response bodies automatically.
 */
export async function inspectApiResponse(url, options = {}) {
  const startedAt = performance.now();

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        Accept: "application/json",
        ...(options.headers || {}),
      },
    });

    const durationMs = Math.round(performance.now() - startedAt);
    const contentType = response.headers.get("content-type") || "";
    const rawBody = await response.text();

    let data = null;
    let parseError = null;

    if (rawBody.length > 0) {
      if (contentType.includes("json")) {
        try {
          data = JSON.parse(rawBody);
        } catch (error) {
          parseError = error instanceof Error ? error.message : "Invalid JSON";
        }
      } else {
        data = rawBody;
      }
    }

    return {
      ok: response.ok,
      status: response.status,
      statusText: response.statusText,
      durationMs,
      contentType,
      data,
      parseError,
      error: response.ok
        ? null
        : `HTTP ${response.status} ${response.statusText}`.trim(),
    };
  } catch (error) {
    return {
      ok: false,
      status: null,
      statusText: "",
      durationMs: Math.round(performance.now() - startedAt),
      contentType: "",
      data: null,
      parseError: null,
      error: error instanceof Error ? error.message : "Network request failed",
    };
  }
}

// Example:
// const result = await inspectApiResponse("https://api.example.com/health");
// if (!result.ok) console.error(result.error);
// else console.table({ status: result.status, durationMs: result.durationMs });
