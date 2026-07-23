/* CERTIFIED.44i — front-end config.
   The anon key is PUBLIC by design (safe to ship in the browser); Row-Level
   Security in Supabase is what actually protects the data. The service_role
   key must NEVER appear here — it lives only in server-side .env. */
window.CERTIFIED_CONFIG = {
  SUPABASE_URL: "https://cjnikoqolmochvubzejv.supabase.co",
  SUPABASE_ANON_KEY:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqbmlrb3FvbG1vY2h2dWJ6ZWp2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4MzQ1NTksImV4cCI6MjEwMDQxMDU1OX0.d0RtbEMTiiaeIgdDvmG6ItqghPXl-zw9ZwycGG9H3K8",
  // Domain used to build each group's login email: <group-slug>@<domain>
  GROUP_EMAIL_DOMAIN: "groups.certified.44i",
};
