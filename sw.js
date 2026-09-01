/* Service Worker — إشعارات الدفع */
self.addEventListener('install', function(e){ self.skipWaiting(); });
self.addEventListener('activate', function(e){ e.waitUntil(clients.claim()); });

self.addEventListener('push', function(event) {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch(e) {}
  const title = data.title || 'إشعار جديد';
  const options = {
    body: data.body || '',
    icon: './icon-192.png',
    badge: './icon-192.png',
    dir: 'rtl',
    lang: 'ar',
    data: { url: data.url || './' },
    requireInteraction: false
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) ? event.notification.data.url : './';
  event.waitUntil(
    clients.matchAll({ type:'window', includeUncontrolled:true }).then(function(list) {
      for (let i = 0; i < list.length; i++) {
        const c = list[i];
        if ('focus' in c) { c.focus(); return; }
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
