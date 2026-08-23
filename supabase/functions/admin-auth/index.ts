import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey     = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 1. تحقق من هوية المستخدم الطالب
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: cors });
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await callerClient.auth.getUser();
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: cors });
    }

    // 2. تحقق أن دور المستخدم admin أو super_admin
    const adminClient = createClient(supabaseUrl, serviceKey);
    const { data: profile } = await adminClient
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profile || !["admin", "super_admin"].includes(profile.role)) {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403, headers: cors });
    }

    const body   = await req.json();
    const action = body.action as string;
    let result: unknown;

    switch (action) {
      case "create": {
        const { data, error } = await adminClient.auth.admin.createUser({
          email: body.email,
          password: body.password,
          email_confirm: true,
        });
        result = { data, error: error ? { message: error.message } : null };
        break;
      }
      case "update": {
        const { data, error } = await adminClient.auth.admin.updateUserById(body.id, {
          password: body.password,
        });
        result = { data, error: error ? { message: error.message } : null };
        break;
      }
      case "delete": {
        const { error } = await adminClient.auth.admin.deleteUser(body.id);
        result = { error: error ? { message: error.message } : null };
        break;
      }
      case "delete-bulk": {
        const ids: string[] = body.ids ?? [];
        await Promise.allSettled(ids.map((id) => adminClient.auth.admin.deleteUser(id)));
        result = { error: null };
        break;
      }
      case "list": {
        const { data, error } = await adminClient.auth.admin.listUsers({
          page: body.page ?? 1,
          perPage: body.perPage ?? 1000,
        });
        result = { data, error: error ? { message: error.message } : null };
        break;
      }
      case "find-by-email": {
        const { data, error } = await adminClient.auth.admin.listUsers({ perPage: 1000 });
        const users = data?.users?.filter((u) => u.email === body.email) ?? [];
        result = { data: { users }, error: error ? { message: error.message } : null };
        break;
      }
      default:
        return new Response(JSON.stringify({ error: "Unknown action: " + action }), {
          status: 400, headers: cors,
        });
    }

    return new Response(JSON.stringify(result), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: cors,
    });
  }
});
