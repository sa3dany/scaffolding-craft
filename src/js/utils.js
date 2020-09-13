export function trackErrors() {
  const loadErrorEvents = (window.__e && window.__e.q) || [];
  const fieldsObj = { eventAction: "uncaught error" };

  const trackError = (error, fieldsObj = {}) => {
    window.ga
      ? ga(
          "send",
          "event",
          Object.assign(
            {
              eventCategory: "Script",
              eventAction: "error",
              eventLabel: (error && error.stack) || "(not set)",
              nonInteraction: true,
            },
            fieldsObj
          )
        )
      : {};
  };

  loadErrorEvents.forEach((event) => {
    trackError(event.error, fieldsObj);
  });

  window.addEventListener("error", (event) => {
    trackError(event.error, fieldsObj);
  });
}
