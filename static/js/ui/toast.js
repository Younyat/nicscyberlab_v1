// static/js/ui/toast.js
export function showToast(message) {
  const toast = document.getElementById("toast");
  if (!toast) {
    console.log("TOAST:", message);
    return;
  }
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 3000);
}
