function onPush(event) {
  event.waitUntil(
    self.registration.showNotification("JCRadio", {
      body: event.data.text(),
      icon: "/assets/path/to/icon.png",
      tag:  "push-simple-demo-notification-tag"
    })
  )
}

self.addEventListener("push", onPush);
