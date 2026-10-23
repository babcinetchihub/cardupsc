// Funcții comune pentru aplicația studentului și panoul administratorului
(function () {
  const cfg = window.CARDUP_CONFIG || {};
  const configured = cfg.supabaseUrl && !cfg.supabaseUrl.includes("PROIECTUL-TAU") && cfg.supabaseAnonKey && !cfg.supabaseAnonKey.includes("CHEIA");

  const LEVELS = [{ name: "Start", min: 0 }, { name: "Activ", min: 50 }, { name: "Implicat", min: 150 }, { name: "Ambasador", min: 300 }];
  const CATS = ["Mobilități", "Voluntariat", "Carieră", "Cultură", "Sport", "Cercetare", "Antreprenoriat"];
  const THEMES = [
    { id: "navy", c1: "#0B1A4C", c2: "#2C43A8", fg: "#FFFFFF", label: "Albastru UPSC" },
    { id: "sun", c1: "#C98A00", c2: "#F2B705", fg: "#2A1F00", label: "Galben" },
    { id: "forest", c1: "#0F5A45", c2: "#1E8C6A", fg: "#FFFFFF", label: "Verde" },
    { id: "plum", c1: "#5B1F5E", c2: "#9A3C8F", fg: "#FFFFFF", label: "Prună" }
  ];

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
  function puncte(n) { const m = Math.abs(n) % 100; return n + (Math.abs(n) === 1 ? " punct" : (n === 0 || (m >= 1 && m <= 19)) ? " puncte" : " de puncte"); }
  function levelOf(earned) { let i = 0; LEVELS.forEach((l, k) => { if (earned >= l.min) i = k; }); return i; }
  function fmt(ts) { return ts ? new Date(ts).toLocaleString("ro-RO", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" }) : ""; }
  function fmtDate(d) { if (!d) return ""; const x = new Date(d + "T12:00:00"); return isNaN(x) ? d : x.toLocaleDateString("ro-RO", { day: "numeric", month: "long", year: "numeric" }); }
  function fullName(p) { return ((p.last_name || "") + " " + (p.first_name || "")).trim() || "Fără nume"; }
  function initials(p) { return (((p.first_name || "?")[0] || "") + ((p.last_name || "")[0] || "")).toUpperCase(); }

  let toastTimer;
  function toast(msg) {
    let t = document.getElementById("toast");
    if (!t) { t = document.createElement("div"); t.id = "toast"; t.className = "toast"; t.setAttribute("role", "status"); document.body.appendChild(t); }
    t.textContent = msg; t.classList.add("show"); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove("show"), 2800);
  }
  function errMsg(e) {
    if (!e) return "A apărut o eroare.";
    const m = e.message || String(e);
    if (/Invalid login credentials/i.test(m)) return "Emailul sau parola nu sunt corecte.";
    if (/Email not confirmed/i.test(m)) return "Confirmă mai întâi adresa de email (verifică inboxul).";
    if (/User already registered/i.test(m)) return "Există deja un cont cu acest email.";
    if (/Password should be/i.test(m)) return "Parola trebuie să aibă cel puțin 6 caractere.";
    if (/Failed to fetch|NetworkError/i.test(m)) return "Nu există conexiune la server. Verifică internetul.";
    return m;
  }

  function qrSvg(text) {
    const q = window.qrcode(0, "M"); q.addData(text); q.make();
    return q.createSvgTag(4, 2).replace(/width="\d+px"/, 'width="100%"').replace(/height="\d+px"/, 'height="100%"');
  }

  function resizeImage(file, max = 1200) {
    return new Promise((resolve, reject) => {
      if (!file.type.startsWith("image/")) return reject(new Error("Fișierul ales nu este o imagine."));
      const url = URL.createObjectURL(file), img = new Image();
      img.onload = () => {
        const k = Math.min(1, max / Math.max(img.width, img.height));
        const c = document.createElement("canvas"); c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
        c.getContext("2d").drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(url);
        c.toBlob(b => b ? resolve(b) : reject(new Error("Imaginea nu a putut fi procesată.")), "image/jpeg", 0.82);
      };
      img.onerror = () => reject(new Error("Imaginea nu a putut fi citită."));
      img.src = url;
    });
  }

  if (!configured) {
    document.addEventListener("DOMContentLoaded", () => {
      document.body.innerHTML = '<div class="setup panel"><h2>Configurare necesară</h2><p>Deschide fișierul <b>config.js</b> și completează adresa proiectului Supabase și cheia anon publică. Pașii sunt descriși în <b>README.md</b>.</p></div>';
    });
    window.CU = null; return;
  }

  const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
  function imgUrl(path) { return path ? sb.storage.from("media").getPublicUrl(path).data.publicUrl : ""; }

  window.CU = { sb, LEVELS, CATS, THEMES, esc, puncte, levelOf, fmt, fmtDate, fullName, initials, toast, errMsg, qrSvg, resizeImage, imgUrl };
})();
