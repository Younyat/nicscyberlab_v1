// static/js/ui/modal.js
export function showConfirmationModal(title, message, onConfirm) {
  const modal     = document.getElementById("customModal");
  const titleEl   = document.getElementById("modalTitle");
  const messageEl = document.getElementById("modalMessage");
  const btnOk     = document.getElementById("modalConfirm");
  const btnCancel = document.getElementById("modalCancel");

  if (!modal || !titleEl || !messageEl || !btnOk || !btnCancel) {
    console.warn("⚠️ Modal de confirmación no encontrado, ejecutando callback directamente.");
    if (typeof onConfirm === "function") onConfirm();
    return;
  }

  titleEl.textContent   = title;
  messageEl.textContent = message;
  modal.classList.remove("hidden");

  const clean = () => {
    modal.classList.add("hidden");
    btnOk.removeEventListener("click", handleOk);
    btnCancel.removeEventListener("click", handleCancel);
  };

  const handleOk = () => {
    clean();
    if (typeof onConfirm === "function") onConfirm();
  };
  const handleCancel = () => clean();

  btnOk.addEventListener("click", handleOk);
  btnCancel.addEventListener("click", handleCancel);
}
