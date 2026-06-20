let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

let Hooks = {};
Hooks.FlashAutoHide = {
  mounted() {
    let duration = parseInt(this.el.dataset.flashDuration) || 4000;
    this._hide = () => {
      this.el.style.transition = "opacity 300ms ease-out";
      this.el.style.opacity = "0";
      setTimeout(() => { this.el.remove(); }, 300);
    };
    this._timer = setTimeout(this._hide, duration);
  },
  updated() {
    clearTimeout(this._timer);
    this.el.style.opacity = "1";
    let duration = parseInt(this.el.dataset.flashDuration) || 4000;
    this._timer = setTimeout(this._hide, duration);
  },
  destroyed() {
    clearTimeout(this._timer);
  }
};

Hooks.ChatScroll = {
  mounted() {
    document.documentElement.style.overflow = "hidden";
    document.body.style.overflow = "hidden";
    this.scrollToBottom();
    this.handleEvent("scroll_bottom", () => this.scrollToBottom());
  },
  updated() {
    this.scrollToBottom();
  },
  destroyed() {
    document.documentElement.style.overflow = "";
    document.body.style.overflow = "";
  },
  scrollToBottom() {
    const el = this.el;
    requestAnimationFrame(() => {
      el.scrollTop = el.scrollHeight;
    });
  }
};

Hooks.Refocus = {
  mounted() {
    this.handleEvent("refocus", () => {
      requestAnimationFrame(() => this.el.focus());
    });
  }
};

let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
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
