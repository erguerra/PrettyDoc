// Pretty Doc canvas glue: Markdown -> HTML rendering, responsive typography,
// theming, mermaid/math, outline, follow mode, and link routing back to the
// native shell.
(function () {
	"use strict";

	var content = document.getElementById("content");
	var root = document.documentElement;

	// --- Markdown renderer -------------------------------------------------
	var md = window.markdownit({
		html: false,
		linkify: true,
		typographer: true,
		breaks: false,
		highlight: function (str, lang) {
			if (lang && lang.toLowerCase() === "mermaid") return "";
			if (window.hljs && lang && hljs.getLanguage(lang)) {
				try {
					return hljs.highlight(str, { language: lang, ignoreIllegals: true }).value;
				} catch (e) { /* fall through */ }
			}
			if (window.hljs) {
				try { return hljs.highlightAuto(str).value; } catch (e) { /* noop */ }
			}
			return "";
		}
	});

	function slugify(text) {
		return text.toLowerCase().trim()
			.replace(/[^\w\s-]/g, "")
			.replace(/\s+/g, "-")
			.replace(/-+/g, "-");
	}

	function addHeadingIds() {
		var used = {};
		content.querySelectorAll("h1,h2,h3,h4,h5,h6").forEach(function (h) {
			if (!h.id) {
				var base = slugify(h.textContent || "section") || "section";
				var id = base, n = 1;
				while (used[id]) { id = base + "-" + (n++); }
				used[id] = true;
				h.id = id;
			} else {
				used[h.id] = true;
			}
		});
	}

	function enhanceTaskLists() {
		content.querySelectorAll("li").forEach(function (li) {
			var m = li.innerHTML.match(/^\s*\[( |x|X)\]\s+([\s\S]*)$/);
			if (!m) return;
			li.classList.add("task-list-item");
			var checked = m[1].toLowerCase() === "x" ? "checked" : "";
			li.innerHTML = '<input type="checkbox" disabled ' + checked + "> " + m[2];
		});
	}

	// --- Mermaid -----------------------------------------------------------
	function mermaidThemeName() {
		var t = root.getAttribute("data-theme");
		if (!t && window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches) return "dark";
		if (t === "dark") return "dark";
		if (t === "sepia") return "neutral";
		return "default";
	}

	function renderMermaid() {
		if (!window.mermaid) return;
		try {
			mermaid.initialize({ startOnLoad: false, theme: mermaidThemeName(), securityLevel: "strict" });
		} catch (e) { return; }

		var blocks = content.querySelectorAll("pre > code.language-mermaid, pre > code.mermaid");
		var idx = 0;
		blocks.forEach(function (code) {
			var pre = code.parentElement;
			var src = code.textContent;
			var holder = document.createElement("div");
			holder.className = "mermaid-diagram";
			pre.replaceWith(holder);
			var id = "mmd-" + Date.now() + "-" + (idx++);
			try {
				var out = mermaid.render(id, src, function (svg) { holder.innerHTML = svg; });
				if (typeof out === "string") holder.innerHTML = out;
				else if (out && out.svg) holder.innerHTML = out.svg;
			} catch (e) {
				holder.textContent = src;
			}
		});
	}

	// --- Math (KaTeX) ------------------------------------------------------
	function renderMath() {
		if (!window.renderMathInElement) return;
		try {
			renderMathInElement(content, {
				delimiters: [
					{ left: "$$", right: "$$", display: true },
					{ left: "\\[", right: "\\]", display: true },
					{ left: "\\(", right: "\\)", display: false },
					{ left: "$", right: "$", display: false }
				],
				throwOnError: false
			});
		} catch (e) { /* noop */ }
	}

	// --- Copy buttons ------------------------------------------------------
	function copyText(text, btn) {
		function done() { btn.textContent = "Copied"; setTimeout(function () { btn.textContent = "Copy"; }, 1200); }
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text).then(done, function () { fallback(); });
		} else { fallback(); }
		function fallback() {
			var ta = document.createElement("textarea");
			ta.value = text; document.body.appendChild(ta); ta.select();
			try { document.execCommand("copy"); done(); } catch (e) { /* noop */ }
			document.body.removeChild(ta);
		}
	}

	function addCopyButtons() {
		content.querySelectorAll("pre > code").forEach(function (code) {
			var pre = code.parentElement;
			if (pre.querySelector(".pd-copy")) return;
			var btn = document.createElement("button");
			btn.className = "pd-copy";
			btn.type = "button";
			btn.textContent = "Copy";
			btn.addEventListener("click", function () { copyText(code.textContent, btn); });
			pre.appendChild(btn);
		});
	}

	// --- Outline bridge ----------------------------------------------------
	function postOutline() {
		var items = [];
		content.querySelectorAll("h1,h2,h3,h4,h5,h6").forEach(function (h) {
			items.push({ id: h.id, level: parseInt(h.tagName.substring(1), 10), text: h.textContent || "" });
		});
		post({ type: "outline", items: items });
	}

	// --- Public API used by the Swift shell --------------------------------
	var lastMarkdown = "";
	var pendingAnchor = null;
	var followMode = false;
	var lastTheme = "__init__";

	window.PD = {
		setContent: function (markdownText) {
			lastMarkdown = markdownText || "";
			render(lastMarkdown);
		},
		setSettings: function (s) {
			applySettings(s || {});
		},
		scrollToAnchor: function (slug) {
			pendingAnchor = slug;
			tryScrollAnchor();
		},
		setFollow: function (on) {
			followMode = !!on;
			if (followMode) scrollToBottom();
		}
	};

	function render(markdownText) {
		content.innerHTML = md.render(markdownText);
		addHeadingIds();
		enhanceTaskLists();
		renderMermaid();
		addCopyButtons();
		renderMath();
		postOutline();
		updateFluidFont();
		requestAnimationFrame(function () {
			tryScrollAnchor();
			if (followMode) scrollToBottom();
		});
	}

	function tryScrollAnchor() {
		if (!pendingAnchor) return;
		var el = document.getElementById(pendingAnchor);
		if (el) {
			el.scrollIntoView({ behavior: "smooth", block: "start" });
			pendingAnchor = null;
		}
	}

	function scrollToBottom() {
		window.scrollTo({ top: document.body.scrollHeight, behavior: "auto" });
	}

	// --- Settings / theming ------------------------------------------------
	var fluidEnabled = true;
	var userScale = 1;

	function applySettings(s) {
		var theme = s.theme || "system";
		if (theme !== "system") {
			root.setAttribute("data-theme", theme);
		} else {
			root.removeAttribute("data-theme");
		}
		root.setAttribute("data-width", s.readingWidth || "comfortable");
		root.setAttribute("data-font", s.fontFamily || "system");

		userScale = typeof s.fontScale === "number" ? s.fontScale : 1;
		fluidEnabled = s.fluidScaling !== false;

		if (typeof s.lineHeight === "number") root.style.setProperty("--line-height", String(s.lineHeight));
		if (typeof s.letterSpacing === "number") root.style.setProperty("--letter-spacing", s.letterSpacing + "em");
		if (typeof s.maxWidthCh === "number") root.style.setProperty("--measure", s.maxWidthCh + "ch");

		updateFluidFont();

		// Mermaid bakes theme colors into the SVG at render time, so re-render
		// the document when the theme actually changes.
		if (theme !== lastTheme && lastTheme !== "__init__" && lastMarkdown) {
			render(lastMarkdown);
		}
		lastTheme = theme;
	}

	// The differentiator: base font scales with the window width.
	function updateFluidFont() {
		var base;
		if (fluidEnabled) {
			var w = window.innerWidth;
			var minW = 480, maxW = 2200, minF = 15, maxF = 30;
			var t = Math.max(0, Math.min(1, (w - minW) / (maxW - minW)));
			base = minF + t * (maxF - minF);
		} else {
			base = 17;
		}
		root.style.setProperty("--base-font", (base * userScale).toFixed(2) + "px");
	}

	window.addEventListener("resize", function () {
		updateFluidFont();
		if (followMode) scrollToBottom();
	}, { passive: true });
	if (window.ResizeObserver) {
		new ResizeObserver(updateFluidFont).observe(document.body);
	}

	// --- Link routing ------------------------------------------------------
	function post(payload) {
		if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.bridge) {
			webkit.messageHandlers.bridge.postMessage(payload);
		}
	}

	content.addEventListener("click", function (e) {
		var a = e.target.closest ? e.target.closest("a") : null;
		if (!a) return;
		var href = a.getAttribute("href");
		if (!href) return;
		e.preventDefault();

		if (href.charAt(0) === "#") {
			var id = decodeURIComponent(href.slice(1));
			var el = document.getElementById(id);
			if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
			return;
		}
		if (/^(https?:|mailto:)/i.test(href)) {
			post({ type: "openExternal", href: href });
			return;
		}
		post({ type: "openRelative", href: href });
	});
})();
