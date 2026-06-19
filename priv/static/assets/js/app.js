let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  params: {_csrf_token: csrfToken}
});

// Only connect the LiveSocket when there are LiveView elements on the page.
// Connecting unconditionally on every page (e.g. /login) creates a WebSocket
// whose connect_info session is captured at connect-time. When the browser
// later navigates to a page with a LiveView, the same socket is reused with
// the stale session, causing on_mount to see the wrong auth state.
if (document.querySelector("[data-phx-main]")) {
  liveSocket.connect();
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", function() {
    navigator.serviceWorker.register("/sw.js").then(function(reg) {
      setInterval(function() { reg.update(); }, 60000);
    });
  });

  let refreshing = false;
  navigator.serviceWorker.addEventListener("controllerchange", function() {
    if (refreshing) return;
    refreshing = true;
    window.location.reload();
  });
}
