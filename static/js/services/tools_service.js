// static/js/services/tools_service.js
import { API_BASE, ENDPOINTS } from "../config.js";

export async function getOpenstackInstances() {
  const res = await fetch(API_BASE + ENDPOINTS.OPENSTACK_INSTANCES);
  const data = await res.json().catch(() => ({ instances: [] }));
  return { ok: res.ok, status: res.status, data };
}

export async function addToolConfig(payload) {
  const res = await fetch(API_BASE + ENDPOINTS.ADD_TOOL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}

export async function readToolsConfigs() {
  const res = await fetch(API_BASE + ENDPOINTS.READ_TOOLS_CFG);
  const data = await res.json().catch(() => ({ files: [] }));
  return { ok: res.ok, status: res.status, data };
}

export async function installToolsStreaming(onLine) {
  const res = await fetch(API_BASE + ENDPOINTS.INSTALL_TOOLS, { method: "POST" });

  if (!res.ok || !res.body) {
    throw new Error(`HTTP ${res.status}`);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder("utf-8");

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    const text = decoder.decode(value, { stream: true });
    text.split("\n").forEach((line) => {
      if (line.startsWith("data:")) {
        onLine(line.replace("data: ", ""));
      }
    });
  }
}

export async function getToolsForInstance(instanceName) {
  const res = await fetch(
    API_BASE + `${ENDPOINTS.GET_TOOLS_FOR_INSTANCE}?instance=${encodeURIComponent(instanceName)}`
  );
  const data = await res.json().catch(() => ({ tools: [] }));
  return { ok: res.ok, status: res.status, data };
}

export async function uninstallToolFromInstance(payload) {
  const res = await fetch(API_BASE + ENDPOINTS.UNINSTALL_TOOL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}
