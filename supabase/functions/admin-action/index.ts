import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    /* ── 1. تحقق من JWT المستخدم الطالب ── */
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer "))
      return json({ error: "Unauthorized" }, 401);

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    /* ── 2. تحقق أن المستخدم admin أو super_admin ── */
    const { data: profile } = await userClient
      .from("profiles")
      .select("role, school")
      .eq("id", user.id)
      .single();
    if (!profile || !["admin", "super_admin"].includes(profile.role))
      return json({ error: "Forbidden" }, 403);

    /* ── 3. عميل بصلاحية كاملة (service_role آمن على الخادم) ── */
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const { action, payload } = await req.json() as { action: string; payload: Record<string, unknown> };

    /* ════════ createOrGetUser ════════ */
    if (action === "createOrGetUser") {
      const { email, password } = payload as { email: string; password: string };

      let { data, error } = await admin.auth.admin.createUser({
        email, password, email_confirm: true,
      });

      if (error) {
        // إذا كان الحساب موجوداً — نسترجع معرّفه ونُحدِّث كلمة المرور
        if (error.message?.toLowerCase().includes("already")) {
          const { data: list } = await admin.auth.admin.listUsers({ perPage: 1000 });
          const existing = list?.users?.find((u) => u.email === email);
          if (!existing) return json({ error: error.message }, 400);
          await admin.auth.admin.updateUserById(existing.id, { password });
          return json({ id: existing.id });
        }
        return json({ error: error.message }, 400);
      }
      return json({ id: data.user!.id });
    }

    /* ════════ updateUserPassword ════════ */
    if (action === "updateUserPassword") {
      const { userId, password } = payload as { userId: string; password: string };
      // الأدمن يُغيِّر كلمات مرور مستخدمي مدرسته فقط
      if (profile.role === "admin") {
        const { data: t } = await admin.from("profiles").select("school").eq("id", userId).single();
        if (!t || t.school !== profile.school) return json({ error: "Forbidden" }, 403);
      }
      const { error } = await admin.auth.admin.updateUserById(userId, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    /* ════════ deleteUser ════════ */
    if (action === "deleteUser") {
      const { userId } = payload as { userId: string };
      if (profile.role === "admin") {
        const { data: t } = await admin.from("profiles").select("school").eq("id", userId).single();
        if (!t || t.school !== profile.school) return json({ error: "Forbidden" }, 403);
      }
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error && !error.message?.includes("not found"))
        return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    /* ════════ listAllAuthUsers (تنظيف الحسابات المعطوبة) ════════ */
    if (action === "listAllAuthUsers") {
      if (profile.role !== "super_admin") return json({ error: "Forbidden" }, 403);
      let allUsers: unknown[] = [];
      let page = 1;
      while (true) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error || !data) break;
        allUsers = allUsers.concat(data.users);
        if (!data.nextPage || data.users.length < 1000) break;
        page++;
      }
      return json({ users: allUsers });
    }

    return json({ error: "Unknown action" }, 400);

  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: msg }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
