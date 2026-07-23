/* CERTIFIED.44i — front-end app logic (Supabase-backed).
   Requires config.js and the supabase-js UMD bundle to be loaded first. */
(function () {
  "use strict";

  var cfg = window.CERTIFIED_CONFIG || {};
  if (!window.supabase) {
    console.error("supabase-js not loaded");
    return;
  }

  // Base client (anon). Persists the group session in localStorage.
  var sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true },
  });

  // A client variant that also sends the selected AE id as a header, so the
  // submit_quiz() RPC knows which learner is acting. Rebuilt when the AE changes.
  var sbForAE = null;
  function clientForActiveAE() {
    var ae = getActiveAE();
    if (!ae) return sb;
    if (!sbForAE || sbForAE.__aeId !== ae.id) {
      sbForAE = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
        auth: { persistSession: true, autoRefreshToken: true },
        global: { headers: { "x-ae-id": ae.id } },
      });
      sbForAE.__aeId = ae.id;
    }
    return sbForAE;
  }

  // ---- Session / active AE state ----
  var AE_KEY = "certified44i.activeAE";
  function setActiveAE(ae) { sessionStorage.setItem(AE_KEY, JSON.stringify(ae)); sbForAE = null; }
  function getActiveAE() {
    try { return JSON.parse(sessionStorage.getItem(AE_KEY) || "null"); }
    catch (e) { return null; }
  }
  function clearActiveAE() { sessionStorage.removeItem(AE_KEY); sbForAE = null; }

  async function getSession() {
    var r = await sb.auth.getSession();
    return r.data.session;
  }

  // ---- Group login: <slug>@domain + shared password ----
  async function groupLogin(groupCode, password) {
    var slug = (groupCode || "").trim().toLowerCase();
    var email = slug + "@" + cfg.GROUP_EMAIL_DOMAIN;
    var r = await sb.auth.signInWithPassword({ email: email, password: password });
    if (r.error) throw r.error;
    clearActiveAE();
    return r.data;
  }

  async function signOut() {
    clearActiveAE();
    await sb.auth.signOut();
  }

  // ---- Reads (all constrained to the logged-in group by RLS) ----
  async function getMyGroup() {
    var r = await sb.from("groups").select("id,name,slug").limit(1).maybeSingle();
    if (r.error) throw r.error;
    return r.data;
  }

  async function listMyAEs() {
    var r = await sb.from("account_executives")
      .select("id,full_name")
      .eq("is_active", true)
      .order("full_name");
    if (r.error) throw r.error;
    return r.data || [];
  }

  // Process course + its blocks, with the active AE's completion state merged in.
  async function getCourseWithProgress(courseSlug) {
    var course = await sb.from("courses").select("id,slug,title,description,passing_grade")
      .eq("slug", courseSlug).maybeSingle();
    if (course.error) throw course.error;
    if (!course.data) return null;

    var blocks = await sb.from("blocks")
      .select("id,slug,title,duration_minutes,sort_order")
      .eq("course_id", course.data.id).eq("is_active", true)
      .order("sort_order");
    if (blocks.error) throw blocks.error;

    var ae = getActiveAE();
    var done = {};
    if (ae) {
      var prog = await sb.from("block_progress")
        .select("block_id,status,completed_at")
        .eq("ae_id", ae.id);
      if (prog.error) throw prog.error;
      (prog.data || []).forEach(function (p) {
        if (p.status === "completed") done[p.block_id] = p.completed_at;
      });
    }

    // Derive lock state: a block is available if it's first or the previous is done.
    var list = (blocks.data || []).map(function (b) {
      return { id: b.id, slug: b.slug, title: b.title,
               duration: b.duration_minutes, completed: !!done[b.id],
               completed_at: done[b.id] || null };
    });
    var unlockedIndex = list.findIndex(function (b) { return !b.completed; });
    list.forEach(function (b, i) {
      b.available = b.completed || i === (unlockedIndex === -1 ? list.length : unlockedIndex);
    });
    return { course: course.data, blocks: list };
  }

  window.Certified = {
    raw: sb,
    clientForActiveAE: clientForActiveAE,
    getSession: getSession,
    groupLogin: groupLogin,
    signOut: signOut,
    getMyGroup: getMyGroup,
    listMyAEs: listMyAEs,
    setActiveAE: setActiveAE,
    getActiveAE: getActiveAE,
    getCourseWithProgress: getCourseWithProgress,
  };
})();
