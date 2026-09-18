import { animate, inView, stagger } from "motion";

/** Soft entrance animations only — never leave content stuck at opacity 0. */
export function initAnimations() {
  inView(
    "[data-animate='fade-up']",
    (element) => {
      animate(
        element,
        { opacity: [0.4, 1], y: [16, 0] },
        { duration: 0.5, easing: [0.22, 1, 0.36, 1] },
      );
    },
    { amount: 0.15 },
  );

  inView(
    "[data-animate='stagger']",
    (element) => {
      const items = element.querySelectorAll("[data-stagger-item]");
      animate(
        items,
        { opacity: [0.4, 1], y: [12, 0] },
        { delay: stagger(0.06), duration: 0.45, easing: [0.22, 1, 0.36, 1] },
      );
    },
    { amount: 0.1 },
  );

  inView(
    "[data-animate='scale-in']",
    (element) => {
      animate(
        element,
        { opacity: [0.5, 1], scale: [0.98, 1] },
        { duration: 0.55, easing: [0.22, 1, 0.36, 1] },
      );
    },
    { amount: 0.15 },
  );

  const hero = document.querySelector("[data-hero]");
  if (hero) {
    animate(
      hero.querySelectorAll("[data-hero-item]"),
      { opacity: [0.3, 1], y: [20, 0] },
      { delay: stagger(0.1), duration: 0.6, easing: [0.22, 1, 0.36, 1] },
    );
  }
}

initAnimations();
document.addEventListener("astro:page-load", initAnimations);
