/* CERTIFIED.44i — shared UI behavior */
(function () {
  "use strict";

  // Mobile nav toggle
  var toggle = document.querySelector(".nav__toggle");
  var nav = document.querySelector(".nav");
  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
  }

  // Curriculum accordions
  document.querySelectorAll(".acc__head").forEach(function (head) {
    head.addEventListener("click", function () {
      var acc = head.closest(".acc");
      var isOpen = acc.classList.toggle("is-open");
      head.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });
  });

  // Video demo — reveal a message (self-hosted media not bundled)
  document.querySelectorAll(".player__play").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var label = btn.closest(".player").querySelector(".player__label");
      if (label) {
        label.textContent =
          "Demo player — in the live LMS this streams the section training video.";
      }
    });
  });

  // Current year in footer
  document.querySelectorAll("[data-year]").forEach(function (el) {
    el.textContent = new Date().getFullYear();
  });
})();
