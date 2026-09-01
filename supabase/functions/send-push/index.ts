import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const VAPID_PUBLIC  = Deno.env.get('VAPID_PUBLIC_KEY')!;
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY')!;

webpush.setVapidDetails('mailto:admin@nasmo.app', VAPID_PUBLIC, VAPID_PRIVATE);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin':'*', 'Access-Control-Allow-Headers':'authorization,content-type' } });

  try {
    const { userId, title, body, url } = await req.json();
    if (!userId || !title) return new Response('missing fields', { status: 400 });

    const { data: subs } = await supabase
      .from('push_subscriptions')
      .select('id, subscription')
      .eq('user_id', userId);

    const results = await Promise.allSettled(
      (subs || []).map(async (row: { id: string; subscription: unknown }) => {
        try {
          await webpush.sendNotification(
            row.subscription as webpush.PushSubscription,
            JSON.stringify({ title, body: body || '', url: url || './' })
          );
        } catch (err: unknown) {
          const status = (err as { statusCode?: number }).statusCode;
          if (status === 410 || status === 404) {
            await supabase.from('push_subscriptions').delete().eq('id', row.id);
          }
        }
      })
    );

    return new Response(JSON.stringify({ sent: results.length }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
