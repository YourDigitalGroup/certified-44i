/* CERTIFIED.44i — certificate verification (front-end demo)
   NOTE: A real deployment validates codes against a backend/credential registry.
   These sample records demonstrate the lookup experience only. */
(function () {
  "use strict";

  var REGISTRY = {
    "44I-101-8A3F2K": {
      name: "Jordan Ellis",
      credential: "Certified:101 Online Visibility",
      issued: "March 4, 2026",
      status: "Valid"
    },
    "44I-201-7QW9ZP": {
      name: "Morgan Reyes",
      credential: "Certified:201 Content Marketing",
      issued: "January 22, 2026",
      status: "Valid"
    },
    "44I-301-3LM6XT": {
      name: "Sam Whitfield",
      credential: "Certified:301 Targeted Digital",
      issued: "November 18, 2025",
      status: "Valid"
    }
  };

  var form = document.getElementById("verify-form");
  var input = document.getElementById("verify-code");
  var out = document.getElementById("verify-result");
  if (!form || !input || !out) return;

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var code = (input.value || "").trim().toUpperCase();
    if (!code) {
      out.innerHTML = "";
      return;
    }
    var rec = REGISTRY[code];
    if (rec) {
      out.innerHTML =
        '<div class="result-card result-card--ok" role="status">' +
        '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M20 6 9 17l-5-5"/></svg>' +
        "<div><b>Certificate verified &middot; " + esc(rec.status) + "</b>" +
        "<small>" + esc(rec.name) + " earned <strong>" + esc(rec.credential) +
        "</strong>, issued " + esc(rec.issued) + ". Code " + esc(code) + ".</small></div></div>";
    } else {
      out.innerHTML =
        '<div class="result-card result-card--bad" role="status">' +
        '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/></svg>' +
        "<div><b>No match found</b>" +
        "<small>We couldn't verify code &ldquo;" + esc(code) +
        "&rdquo;. Try a sample code below, or contact 44&nbsp;Interactive.</small></div></div>";
    }
  });

  // Sample-code chips fill the field
  document.querySelectorAll("[data-sample]").forEach(function (chip) {
    chip.addEventListener("click", function () {
      input.value = chip.getAttribute("data-sample");
      form.requestSubmit ? form.requestSubmit() : form.dispatchEvent(new Event("submit"));
    });
  });
})();
