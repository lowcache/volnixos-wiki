/* =====================================================================
   COVER SHEET — assembly behaviour.

   No dependencies. Every module no-ops cleanly when its markup is absent,
   so this file is safe in the shared bundle.

     1. ink       — the assembly draws itself on when it scrolls into view
     2. rebuild   — wipes the volatile half and re-derives it, on demand
     3. link      — parts list row <-> plate, both directions
     4. framing   — crops the viewBox on phones, where leaders are hidden
     5. parallax  — pointer depth on the assembly axis

   REDUCED-MOTION CONTRACT
   1 and 5 never run; the drawing is complete and legible from the first
   frame. 2 still works and still reports what happened, as an instant
   state swap with no transition. 4 is layout, not motion, and always runs.
   Nothing here carries meaning that only exists while it moves.
   ===================================================================== */

(function () {
  "use strict";

  var fig = document.querySelector("[data-assembly]");
  if (!fig) return;

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  var svg = fig.querySelector(".dw-svg");
  var stack = fig.querySelector(".dw-stack");
  var rows = fig.querySelectorAll(".dw-parts__item");
  var plates = fig.querySelectorAll(".dw-part");

  /* -- 1. ink ------------------------------------------------------- */

  function ink() {
    if (reduce.matches) return;
    fig.classList.add("is-drawing");
    window.setTimeout(function () {
      fig.classList.remove("is-drawing");
    }, 2000);
  }

  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting) return;
          io.disconnect();
          ink();
        });
      },
      { threshold: 0.2 }
    );
    io.observe(fig);
  } else {
    ink();
  }

  /* -- 2. rebuild ---------------------------------------------------- */

  var btn = fig.querySelector("[data-rebuild]");
  var busy = false;

  if (btn) {
    /* the control reports its result to assistive technology, because
       the wipe is the page's only piece of real information that is
       otherwise carried purely by motion */
    var live = document.createElement("p");
    live.className = "dw-visually-hidden";
    live.setAttribute("role", "status");
    live.setAttribute("aria-live", "polite");
    fig.appendChild(live);

    btn.addEventListener("click", function () {
      if (busy) return;
      busy = true;
      btn.disabled = true;

      if (reduce.matches) {
        live.textContent =
          "Rebuilt. The six components above the tmpfs datum were destroyed and re-derived; the four below it persisted.";
        busy = false;
        btn.disabled = false;
        return;
      }

      fig.classList.add("is-wiping");
      live.textContent = "Wiping the volatile root.";

      window.setTimeout(function () {
        fig.classList.remove("is-wiping");
        fig.classList.add("is-redrawing");
        live.textContent =
          "Re-derived. Six components rebuilt from the flake; the four below the datum persisted.";

        window.setTimeout(function () {
          fig.classList.remove("is-redrawing");
          busy = false;
          btn.disabled = false;
        }, 1500);
      }, 1000);
    });
  }

  /* -- 3. link: parts list row <-> plate ----------------------------- */

  function light(key, on) {
    fig.classList.toggle("is-lit", on);
    plates.forEach(function (p) {
      p.classList.toggle("is-lit", on && p.dataset.part === key);
    });
    rows.forEach(function (r) {
      r.classList.toggle("is-lit", on && r.dataset.part === key);
    });
  }

  rows.forEach(function (row) {
    var key = row.dataset.part;
    var a = row.querySelector("a");
    row.addEventListener("mouseenter", function () { light(key, true); });
    row.addEventListener("mouseleave", function () { light(key, false); });
    if (a) {
      a.addEventListener("focus", function () { light(key, true); });
      a.addEventListener("blur", function () { light(key, false); });
    }
  });

  plates.forEach(function (plate) {
    var key = plate.dataset.part;
    plate.addEventListener("mouseenter", function () { light(key, true); });
    plate.addEventListener("mouseleave", function () { light(key, false); });
  });

  /* -- 4. framing ---------------------------------------------------- */

  /* On a phone the leaders and balloons are hidden, so two thirds of the
     drawing's width is empty margin and the stack renders tiny. Crop the
     viewBox to just the parts that are still drawn. Without JS the full
     viewBox stands and the drawing is merely smaller, never broken. */
  if (svg) {
    var narrow = window.matchMedia("(max-width: 743px)");
    var FULL = "0 0 1000 780";
    var CROP = "20 0 620 780";

    var frameFit = function () {
      svg.setAttribute("viewBox", narrow.matches ? CROP : FULL);
    };

    frameFit();
    if (narrow.addEventListener) narrow.addEventListener("change", frameFit);
    else if (narrow.addListener) narrow.addListener(frameFit);
  }

  /* -- 5. parallax --------------------------------------------------- */

  if (stack && svg && !reduce.matches && window.matchMedia("(hover: hover)").matches) {
    var frame = 0;

    svg.addEventListener("pointermove", function (e) {
      if (frame) return;
      frame = window.requestAnimationFrame(function () {
        frame = 0;
        var r = svg.getBoundingClientRect();
        if (!r.width || !r.height) return;
        var x = (e.clientX - r.left) / r.width - 0.5;
        var y = (e.clientY - r.top) / r.height - 0.5;
        stack.style.setProperty("--px", (x * 16).toFixed(2));
        stack.style.setProperty("--py", (y * 9).toFixed(2));
      });
    });

    svg.addEventListener("pointerleave", function () {
      stack.style.setProperty("--px", "0");
      stack.style.setProperty("--py", "0");
    });
  }
})();
