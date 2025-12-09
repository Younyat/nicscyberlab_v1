// static/js/ui/sidebar.js
export function initSidebar() {
  const mainIframe   = document.getElementById("mainIframe");
  const sidebarLinks = document.querySelectorAll(".sidebar-link");

  if (!mainIframe || sidebarLinks.length === 0) return;

  sidebarLinks.forEach((link) => {
    link.addEventListener("click", (ev) => {
      ev.preventDefault();
      const url = link.getAttribute("data-url");
      if (!url) return;

      mainIframe.src = url;

      sidebarLinks.forEach((l) => {
        l.classList.remove("bg-indigo-600");
        l.classList.add("hover:bg-indigo-700");
      });

      link.classList.add("bg-indigo-600");
      link.classList.remove("hover:bg-indigo-700");
    });
  });

  // estado inicial
  const initialSrc = mainIframe.src;
  sidebarLinks.forEach((link) => {
    if (initialSrc.includes(link.getAttribute("data-url"))) {
      link.classList.add("bg-indigo-600");
      link.classList.remove("hover:bg-indigo-700");
    }
  });
}
