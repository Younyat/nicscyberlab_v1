// static/js/services/console_service.js
import { API_BASE, ENDPOINTS } from "../config.js";

export async function requestConsoleUrl(instanceName) {
  const res = await fetch(API_BASE + ENDPOINTS.CONSOLE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ instance_name: instanceName })
  });

  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}
