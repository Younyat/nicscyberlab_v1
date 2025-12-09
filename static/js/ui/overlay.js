// static/js/ui/overlay.js
export function showOverlay(show = true, overlayId = "overlay") {
  const overlay = document.getElementById(overlayId);
  if (!overlay) {
    console.warn(`⚠️ Overlay #${overlayId} no encontrado.`);
    return;
  }
  overlay.classList.toggle("hidden", !show);
}

export function lockButtons(lock = true) {
  const buttons = document.querySelectorAll("button");
  buttons.forEach((btn) => {
    btn.disabled = lock;
    btn.classList.toggle("opacity-50", lock);
    btn.classList.toggle("cursor-not-allowed", lock);
  });
}
