self.addEventListener('push', (event) => {
  if (!event.data) return;
  const data = event.data.json();
  // Map mobile-style { screen, params } to a URL the browser can open.
  // screen examples: "/(app)/transactions/", "/(app)/finances/goals/[id]"
  const url = data.url || (data.screen ? '/' + data.screen.replace(/^\/(app)\//, '') : '/');
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/vittio_new_without_background.png',
      badge: '/vittio_new_without_background.png',
      data: { url },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      const raw = event.notification.data?.url || '/';
      // Only navigate to same-origin paths; reject external URLs
      const target = raw.startsWith('/') ? raw : '/';
      for (const client of clientList) {
        if (client.url === target && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(target);
    })
  );
});
