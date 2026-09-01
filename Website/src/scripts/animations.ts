import { animate, inView, stagger } from "motion";

export function initAnimations() {
  inView(
    "[data-animate='fade-up']",
    (element) => {
      animate(
        element,
        { opacity: [0, 1], y: [28, 0] },
        { duration: 0.65, easing: [0.22, 1, 0.36, 1] },
      );
    },
    { amount: 0.25 },
  );

  inView(
    "[data-animate='stagger']",
    (element) => {
      const items = element.querySelectorAll("[data-stagger-item]");
      animate(
        items,
        { opacity: [0, 1], y: [20, 0] },
        { delay: stagger(0.08), duration: 0.55, easing: [0.22, 1, 0.36, 1] },
      );
    },
    { amount: 0.15 },
  );

  inView(
    "[data-animate='scale-in']",
    (element) => {
      animate(
        element,
        { opacity: [0, 1], scale: [0.96, 1] },
        { duration: 0.7, easing: [0.22, 1, 0.36, 1] },
      );
    },
    { amount: 0.3 },
  );

  const hero = document.querySelector("[data-hero]");
  if (hero) {
    animate(
      hero.querySelectorAll("[data-hero-item]"),
      { opacity: [0, 1], y: [32, 0] },
      { delay: stagger(0.12), duration: 0.8, easing: [0.22, 1, 0.36, 1] },
    );
  }
}

initAnimations();
document.addEventListener("astro:page-load", initAnimations);
