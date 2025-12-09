// static/js/core/event_bus.js
const listeners = new Map();

export function on(event, handler) {
  if (!listeners.has(event)) listeners.set(event, []);
  listeners.get(event).push(handler);
}

export function off(event, handler) {
  if (!listeners.has(event)) return;
  listeners.set(
    event,
    listeners.get(event).filter((h) => h !== handler)
  );
}

export function emit(event, payload) {
  if (!listeners.has(event)) return;
  for (const handler of listeners.get(event)) {
    try {
      handler(payload);
    } catch (e) {
      console.error(`Error en handler de evento "${event}":`, e);
    }
  }
}
