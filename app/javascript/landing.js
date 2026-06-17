/* ============================================================
   Vittio Landing — Interactions
   Ported from the Vittio Landing design. The Claude Design
   "tweaks panel" block was intentionally removed; the pricing
   billing toggle is folded in at the bottom (guards on elements).
   ============================================================ */

(() => {
  "use strict";

  /* ── Scroll reveal ───────────────────────────────────────── */
  const revealEls = document.querySelectorAll(".reveal");
  const revObs = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("visible");
          revObs.unobserve(e.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
  );
  revealEls.forEach((el) => revObs.observe(el));

  /* ── Hero: word stagger ──────────────────────────────────── */
  const heroTitle = document.getElementById("hero-title");
  if (heroTitle) {
    const wrapWords = (node) => {
      const result = [];
      node.childNodes.forEach((child) => {
        if (child.nodeType === Node.TEXT_NODE) {
          const parts = child.textContent.split(/(\s+)/);
          parts.forEach((p) => {
            if (/^\s+$/.test(p)) {
              result.push(document.createTextNode(p));
            } else if (p) {
              const s = document.createElement("span");
              s.className = "hero-word";
              s.textContent = p;
              result.push(s);
            }
          });
        } else if (child.nodeType === Node.ELEMENT_NODE) {
          if (child.tagName === "BR") {
            result.push(child.cloneNode(true));
          } else if (child.tagName === "EM") {
            // Keep <em> intact so background-clip:text gradient is preserved
            const s = document.createElement("span");
            s.className = "hero-word";
            s.appendChild(child.cloneNode(true));
            result.push(s);
          } else {
            const s = document.createElement("span");
            s.className = "hero-word";
            wrapWords(child).forEach((n) => s.appendChild(n));
            const wrapped = document.createElement(child.tagName.toLowerCase());
            for (const a of child.attributes) wrapped.setAttribute(a.name, a.value);
            while (s.firstChild) wrapped.appendChild(s.firstChild);
            s.appendChild(wrapped);
            result.push(s);
          }
        }
      });
      return result;
    };
    const nodes = wrapWords(heroTitle);
    heroTitle.innerHTML = "";
    nodes.forEach((n) => heroTitle.appendChild(n));
    const words = heroTitle.querySelectorAll(".hero-word");
    words.forEach((w, i) => setTimeout(() => w.classList.add("in"), 120 + i * 70));
  }

  /* ── Hero cursor glow ────────────────────────────────────── */
  const hero = document.querySelector(".hero");
  const cursorGlow = document.querySelector(".hero-cursor-glow");
  if (hero && cursorGlow) {
    hero.addEventListener("mouseenter", () => {
      cursorGlow.style.opacity = "1";
    });
    hero.addEventListener("mouseleave", () => {
      cursorGlow.style.opacity = "0";
    });
    hero.addEventListener("mousemove", (e) => {
      const r = hero.getBoundingClientRect();
      cursorGlow.style.left = e.clientX - r.left + "px";
      cursorGlow.style.top = e.clientY - r.top + "px";
    });
  }

  /* ── Feature cards: cursor glow position ────────────────── */
  document.querySelectorAll(".feat").forEach((card) => {
    card.addEventListener("mousemove", (e) => {
      const r = card.getBoundingClientRect();
      card.style.setProperty("--mx", e.clientX - r.left + "px");
      card.style.setProperty("--my", e.clientY - r.top + "px");
    });
  });

  /* ── Animated count-up ───────────────────────────────────── */
  const countUp = (el) => {
    const target = parseFloat(el.dataset.target);
    const decimals = parseInt(el.dataset.decimals || "0", 10);
    const prefix = el.dataset.prefix || "";
    const suffix = el.dataset.suffix || "";
    const duration = parseInt(el.dataset.duration || "1800", 10);
    const start = performance.now();
    const fmt = new Intl.NumberFormat("es-MX", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    });
    const tick = (now) => {
      const p = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      el.textContent = prefix + fmt.format(target * eased) + suffix;
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };
  const countObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting && !e.target.dataset.counted) {
          e.target.dataset.counted = "1";
          countUp(e.target);
          countObserver.unobserve(e.target);
        }
      });
    },
    { threshold: 0.4 }
  );
  document.querySelectorAll("[data-count]").forEach((el) => countObserver.observe(el));

  /* ── Animated category bars ──────────────────────────────── */
  const barObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.querySelectorAll(".spend-bar .fill").forEach((bar, i) => {
            setTimeout(() => {
              bar.style.width = bar.dataset.pct + "%";
            }, i * 130);
          });
          barObserver.unobserve(e.target);
        }
      });
    },
    { threshold: 0.3 }
  );
  document.querySelectorAll(".spend-card").forEach((c) => barObserver.observe(c));

  /* ── Hero balance ticker (subtle value shifting) ────────── */
  const balanceEl = document.getElementById("hero-balance-value");
  if (balanceEl) {
    const base = 192629.71;
    const fmt = new Intl.NumberFormat("es-MX", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    let current = 0;
    const animateToBase = () => {
      const start = performance.now();
      const tick = (now) => {
        const p = Math.min((now - start) / 2200, 1);
        const e = 1 - Math.pow(1 - p, 3);
        current = base * e;
        balanceEl.textContent = "$" + fmt.format(current);
        if (p < 1) requestAnimationFrame(tick);
        else scheduleBlip();
      };
      requestAnimationFrame(tick);
    };
    const scheduleBlip = () => {
      setTimeout(() => {
        const delta = Math.random() * 200 - 50;
        const target = current + delta;
        const start = performance.now();
        const startVal = current;
        const tick2 = (now) => {
          const p = Math.min((now - start) / 700, 1);
          const e = 1 - Math.pow(1 - p, 3);
          current = startVal + (target - startVal) * e;
          balanceEl.textContent = "$" + fmt.format(current);
          if (p < 1) requestAnimationFrame(tick2);
          else scheduleBlip();
        };
        requestAnimationFrame(tick2);
      }, 3500 + Math.random() * 2000);
    };
    const obs = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        animateToBase();
        obs.disconnect();
      }
    });
    obs.observe(balanceEl);
  }

  /* ── Nav scrolled state ─────────────────────────────────── */
  const scroll = () => {
    document.body.classList.toggle("scrolled", window.scrollY > 24);
  };
  scroll();
  window.addEventListener("scroll", scroll, { passive: true });

  /* ── Mobile drawer ──────────────────────────────────────── */
  (() => {
    const ham = document.getElementById("nav-hamburger");
    const drawer = document.getElementById("mobile-drawer");
    if (!ham || !drawer) return;
    const open = (v) => {
      drawer.classList.toggle("open", v);
      drawer.setAttribute("aria-hidden", v ? "false" : "true");
      ham.setAttribute("aria-expanded", v ? "true" : "false");
      document.body.style.overflow = v ? "hidden" : "";
    };
    ham.addEventListener("click", () => open(!drawer.classList.contains("open")));
    drawer.querySelectorAll("[data-mobile-close]").forEach((el) => {
      el.addEventListener("click", () => open(false));
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && drawer.classList.contains("open")) open(false);
    });
  })();

  /* ── How it works: scroll-driven ────────────────────────── */
  (() => {
    const wrap = document.getElementById("how-sticky-wrap");
    if (!wrap) return;
    const steps = wrap.querySelectorAll(".how-step");
    const fillEl = wrap.querySelector(".how-steps-fill");
    const phoneImg = document.getElementById("how-phone-img");
    const imgs = phoneImg ? (phoneImg.dataset.steps || "").split(",").filter(Boolean) : [];
    let current = -1;
    const setStep = (idx) => {
      if (idx === current) return;
      current = idx;
      steps.forEach((s, i) => s.classList.toggle("active", i === idx));
      if (phoneImg && imgs[idx]) {
        phoneImg.style.opacity = "0";
        setTimeout(() => {
          phoneImg.src = imgs[idx];
          phoneImg.style.opacity = "1";
        }, 200);
      }
      const dots = wrap.querySelectorAll(".how-step");
      if (fillEl && dots[0] && dots[idx]) {
        const wrapRect = dots[0].parentElement.getBoundingClientRect();
        const first = dots[0].getBoundingClientRect();
        const cur = dots[idx].getBoundingClientRect();
        const firstY = first.top - wrapRect.top + first.height / 2;
        const curY = cur.top - wrapRect.top + cur.height / 2;
        fillEl.style.height = Math.max(0, curY - firstY) + "px";
        fillEl.style.top = firstY + "px";
      }
    };
    setStep(0);
    window.addEventListener(
      "scroll",
      () => {
        const rect = wrap.getBoundingClientRect();
        const total = wrap.offsetHeight - window.innerHeight;
        if (total <= 0) return;
        const scrolled = -rect.top;
        const progress = Math.max(0, Math.min(1, scrolled / total));
        setStep(progress < 0.33 ? 0 : progress < 0.66 ? 1 : 2);
      },
      { passive: true }
    );
  })();

  /* ── Product tabs ───────────────────────────────────────── */
  (() => {
    const tabs = document.querySelectorAll(".product-tab");
    const slider = document.querySelector(".product-tab-slider");
    if (!tabs.length) return;

    const updateSlider = (btn) => {
      if (!slider) return;
      const wrap = btn.parentElement;
      const wr = wrap.getBoundingClientRect();
      const br = btn.getBoundingClientRect();
      slider.style.left = br.left - wr.left + "px";
      slider.style.width = br.width + "px";
    };
    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        tabs.forEach((t) => t.classList.remove("on"));
        tab.classList.add("on");
        document.querySelectorAll(".product-panel").forEach((p) => p.classList.remove("on"));
        const panel = document.getElementById(tab.dataset.panel);
        if (panel) panel.classList.add("on");
        updateSlider(tab);
      });
    });
    const onLoad = () => {
      const active = document.querySelector(".product-tab.on");
      if (active) updateSlider(active);
    };
    onLoad();
    window.addEventListener("resize", onLoad);
  })();

  /* ── Language toggle (client-side, syncs ?locale= in URL) ── */
  (() => {
    const buttons = document.querySelectorAll("[data-lang-set]");
    if (!buttons.length) return;
    const apply = (lang, pushUrl) => {
      document.documentElement.dataset.lang = lang;
      buttons.forEach((b) => b.classList.toggle("on", b.dataset.langSet === lang));
      try {
        localStorage.setItem("vittio.lang", lang);
      } catch (e) {}
      if (pushUrl) {
        try {
          const url = new URL(window.location.href);
          url.searchParams.set("locale", lang);
          window.history.replaceState({}, "", url);
        } catch (e) {}
      }
    };
    // Initial language is set server-side on <html data-lang>; respect it.
    const initial = document.documentElement.dataset.lang || "es";
    apply(initial, false);
    buttons.forEach((b) => b.addEventListener("click", () => apply(b.dataset.langSet, true)));
  })();

  /* ── Pricing: billing toggle (monthly / annual) ─────────── */
  (() => {
    const buttons = document.querySelectorAll("#billing-toggle button");
    if (!buttons.length) return;
    const amountEl = document.querySelector("[data-price-monthly]");
    const apply = (mode) => {
      buttons.forEach((b) => b.classList.toggle("on", b.dataset.billing === mode));
      if (amountEl) {
        const target = parseInt(
          mode === "annual" ? amountEl.dataset.priceAnnual : amountEl.dataset.priceMonthly,
          10
        );
        const start = parseInt(amountEl.textContent.replace(/[^0-9]/g, ""), 10) || 0;
        const t0 = performance.now();
        const tick = (now) => {
          const p = Math.min((now - t0) / 400, 1);
          const e = 1 - Math.pow(1 - p, 3);
          amountEl.textContent = Math.round(start + (target - start) * e);
          if (p < 1) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
      }
      document.querySelectorAll("[data-billing-show]").forEach((el) => {
        el.style.display = el.dataset.billingShow === mode ? "" : "none";
      });
    };
    buttons.forEach((b) => b.addEventListener("click", () => apply(b.dataset.billing)));
    apply("monthly");
  })();
})();
