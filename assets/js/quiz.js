/* CERTIFIED.44i — section quiz (front-end demo)
   Mirrors the LearnPress model: every question must be correct to advance
   (Process track requires 100%). Grading here is client-side for demo only. */
(function () {
  "use strict";

  var QUESTIONS = [
    {
      q: "What must you score on each section quiz to advance in the Process Certification track?",
      opts: ["70%", "80%", "90%", "100%"],
      answer: 3
    },
    {
      q: "In what order are the section training videos meant to be watched?",
      opts: ["Any order you like", "In sequence, start to finish", "Newest first", "Only the quizzes matter"],
      answer: 1
    },
    {
      q: "What do you earn after completing all required sections of a certification track?",
      opts: ["A refund", "A printable digital certificate", "Nothing", "A discount code"],
      answer: 1
    }
  ];

  var root = document.getElementById("quiz-widget");
  if (!root) return;

  var qEl = root.querySelector("#quiz-question");
  var optsEl = root.querySelector("#quiz-options");
  var progEl = root.querySelector("#quiz-progress");
  var nextBtn = root.querySelector("#quiz-next");
  var scoreEl = root.querySelector("#quiz-score");

  var idx = 0, correct = 0, answered = false;

  function render() {
    var item = QUESTIONS[idx];
    answered = false;
    progEl.textContent = "Question " + (idx + 1) + " of " + QUESTIONS.length;
    qEl.textContent = item.q;
    optsEl.innerHTML = "";
    item.opts.forEach(function (text, i) {
      var label = document.createElement("label");
      label.className = "opt";
      label.innerHTML =
        '<input type="radio" name="q" value="' + i + '"><span>' + text + "</span>";
      label.querySelector("input").addEventListener("change", function () {
        if (answered) return;
        answered = true;
        var chosen = i;
        if (chosen === item.answer) correct++;
        Array.prototype.forEach.call(optsEl.children, function (child, ci) {
          var inp = child.querySelector("input");
          inp.disabled = true;
          if (ci === item.answer) child.classList.add("correct");
          else if (ci === chosen) child.classList.add("wrong");
        });
        nextBtn.disabled = false;
      });
      optsEl.appendChild(label);
    });
    nextBtn.disabled = true;
    nextBtn.textContent = idx === QUESTIONS.length - 1 ? "See result" : "Next question";
    scoreEl.textContent = "";
  }

  nextBtn.addEventListener("click", function () {
    if (idx < QUESTIONS.length - 1) {
      idx++;
      render();
    } else {
      var pct = Math.round((correct / QUESTIONS.length) * 100);
      qEl.textContent = pct === 100 ? "Section passed ✓" : "Not quite — review and retake";
      optsEl.innerHTML =
        "<p style='margin:0;color:var(--muted)'>You scored <b>" + pct + "%</b> (" +
        correct + "/" + QUESTIONS.length + "). " +
        (pct === 100
          ? "In the live LMS this unlocks the next section."
          : "This track requires 100% — rewatch the video and try again.") +
        "</p>";
      progEl.textContent = "Result";
      nextBtn.textContent = "Retake quiz";
      nextBtn.disabled = false;
      scoreEl.textContent = pct + "%";
      idx = 0; correct = 0;
      nextBtn.onclick = null;
      nextBtn.addEventListener("click", function reset() {
        nextBtn.removeEventListener("click", reset);
        render();
      }, { once: true });
    }
  });

  render();
})();
