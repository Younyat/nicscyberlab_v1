// static/js/services/scenario_service.js
import { API_BASE, ENDPOINTS } from "../config.js";

export async function createScenarioOnBackend(payload) {
  const res = await fetch(API_BASE + ENDPOINTS.CREATE_SCENARIO, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}

export async function getScenarioFromBackend(name = "file") {
  const res = await fetch(API_BASE + ENDPOINTS.GET_SCENARIO(name));
  const data = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, data };
}

export async function getDeploymentStatus() {
  const res = await fetch(API_BASE + ENDPOINTS.DEPLOY_STATUS);
  const data = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, data };
}

export async function destroyScenarioOnBackend() {
  const res = await fetch(API_BASE + ENDPOINTS.DESTROY_SCENARIO, {
    method: "POST"
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}
