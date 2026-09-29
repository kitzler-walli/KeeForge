// NextPass browser extension popup. Talks to the running NextPass app on
// 127.0.0.1 (the browser marks these requests with this extension's origin,
// which NextPass checks); the app holds the vault and decides what this
// extension may see. The extension stores only its own random pairing key.

const ENDPOINT = "http://127.0.0.1:19735/";
const content = document.getElementById("content");
const databaseLabel = document.getElementById("database");
const footer = document.getElementById("connection");

let clientKey;
let activeTab;
let entries = [];
/// Why the last fill could not reach the page, if the browser refused it.
let fillError;
/// What the fill found in each frame it ran in, shown when nothing was filled.
let frameReports = [];
let selectedIndex = 0;

async function send(message) {
  const response = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...message, clientKey }),
  });
  if (!response.ok) throw new Error(`NextPass answered ${response.status}.`);
  return response.json();
}

async function loadClientKey() {
  const stored = await chrome.storage.local.get("clientKey");
  if (stored.clientKey) return stored.clientKey;
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const key = btoa(String.fromCharCode(...bytes));
  await chrome.storage.local.set({ clientKey: key });
  return key;
}

/// What NextPass lists this browser as, e.g. "Brave (Chromium 140)" or
/// "Google Chrome 140".
function browserName() {
  const brands = navigator.userAgentData?.brands ?? [];
  const chromium = brands.find((entry) => entry.brand === "Chromium");
  const own = brands.find((entry) => entry.brand !== "Chromium" && !/not.?a.?brand/i.test(entry.brand));
  if (navigator.brave) return chromium ? `Brave (Chromium ${chromium.version})` : "Brave";
  if (own) return `${own.brand} ${own.version}`;
  return chromium ? `Chromium ${chromium.version}` : "Chromium";
}

/// The first four hex digits of the key's SHA-256, as NextPass shows them
/// beside this browser in Settings.
async function connectionID() {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(clientKey));
  return [...new Uint8Array(digest).slice(0, 2)].map((byte) => byte.toString(16).padStart(2, "0")).join("").toUpperCase();
}

function element(tag, props = {}, children = []) {
  const node = document.createElement(tag);
  Object.assign(node, props);
  for (const child of children) node.append(child);
  return node;
}

function showMessage(text, { warn = false, button, onClick } = {}) {
  content.replaceChildren(element("div", { className: warn ? "message warn" : "message", textContent: text }));
  if (button) {
    const action = element("button", { className: "primary", textContent: button });
    action.addEventListener("click", onClick);
    content.append(action);
  }
}

async function refresh() {
  let status;
  try {
    status = await send({ action: "status" });
  } catch {
    showMessage("Open NextPass on this Mac, then try again.", { warn: true, button: "Try Again", onClick: refresh });
    return;
  }
  if (!status.ok) {
    showMessage(`NextPass reported an error: ${status.error}`, { warn: true });
    return;
  }
  if (!status.paired) {
    showMessage("Allow this browser to use NextPass. NextPass will ask you to confirm.", {
      button: "Connect to NextPass",
      onClick: pair,
    });
    return;
  }
  if (status.database) databaseLabel.textContent = status.database;
  footer.textContent = `Connection ID ${await connectionID()} · ${browserName()}`;
  if (!status.unlocked) {
    showMessage("NextPass is locked.", { button: "Unlock in NextPass", onClick: unlock });
    return;
  }
  showSearch();
}

// NextPass shows this code in its approval dialog; a prompt raised by
// anything else has no matching code on the user's screen.
async function pair() {
  const digits = crypto.getRandomValues(new Uint32Array(1))[0] % 1000000;
  const code = String(digits).padStart(6, "0");
  showMessage("In NextPass, allow this browser only if it shows this code:");
  content.append(element("div", { className: "code", textContent: `${code.slice(0, 3)} ${code.slice(3)}` }));
  const response = await send({ action: "pair", clientName: browserName(), pairingCode: code }).catch(() => null);
  if (response?.ok) {
    refresh();
  } else if (response?.error === "busy") {
    showMessage("NextPass is already asking about a browser. Answer that first.", { warn: true, button: "Try Again", onClick: pair });
  } else if (response?.error === "tooManyAttempts") {
    showMessage("Too many connection attempts. Try again in a few minutes.", { warn: true });
  } else {
    showMessage("NextPass didn't allow this browser.", { warn: true, button: "Try Again", onClick: pair });
  }
}

async function unlock() {
  if (await unlockAndWait()) showSearch();
}

/// Asks NextPass to come forward and waits until the user has unlocked it.
async function unlockAndWait() {
  await send({ action: "unlock" }).catch(() => null);
  showMessage("Unlock NextPass with Touch ID or your password…");
  for (let attempt = 0; attempt < 120; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const status = await send({ action: "status" }).catch(() => null);
    if (status?.unlocked) return true;
  }
  showMessage("NextPass is still locked.", { button: "Unlock in NextPass", onClick: unlock });
  return false;
}

/// Explains a refused request; a lock gets an unlock button that resumes `retry`.
function showRequestFailure(response, retry) {
  if (response?.error === "locked") {
    showMessage("NextPass locked itself.", {
      button: "Unlock and Continue",
      onClick: async () => {
        if (await unlockAndWait()) retry();
      },
    });
  } else if (response?.error === "notFound") {
    showMessage("This entry is no longer in your NextPass database.", { warn: true });
  } else if (response?.error === "unpaired") {
    refresh();
  } else if (!response) {
    showMessage("Open NextPass on this Mac, then try again.", { warn: true, button: "Try Again", onClick: retry });
  } else {
    showMessage(`NextPass couldn't provide this entry (${response.error}).`, { warn: true });
  }
}

function showSearch() {
  const field = element("input", { type: "search", placeholder: "Search NextPass", autofocus: true });
  const heading = element("div", { className: "section" });
  const list = element("ul");
  content.replaceChildren(field, heading, list);
  field.focus();

  let debounce;
  const run = async () => {
    const query = field.value.trim();
    const response = await send({ action: "search", query, url: activeTab?.url ?? "" }).catch(() => null);
    if (!response?.ok) {
      if (response?.error === "locked") refresh();
      return;
    }
    entries = response.entries;
    selectedIndex = 0;
    heading.textContent = query ? "Results" : "For this site";
    renderEntries(list, query);
  };
  field.addEventListener("input", () => {
    clearTimeout(debounce);
    debounce = setTimeout(run, 150);
  });
  field.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const step = event.key === "ArrowDown" ? 1 : -1;
      selectedIndex = Math.max(0, Math.min(entries.length - 1, selectedIndex + step));
      renderEntries(list, field.value.trim());
    } else if (event.key === "Enter" && entries[selectedIndex]) {
      fill(entries[selectedIndex]);
    }
  });
  run();
}

function renderEntries(list, query) {
  if (entries.length === 0) {
    list.replaceChildren(
      element("li", {
        className: "empty",
        textContent: query ? "No matching entries." : "No entries for this site. Type to search.",
      })
    );
    return;
  }
  list.replaceChildren(
    ...entries.map((entry, index) => {
      const copyUser = element("button", { textContent: "User", title: "Copy username" });
      copyUser.addEventListener("click", async (event) => {
        event.stopPropagation();
        await navigator.clipboard.writeText(entry.username);
        copyUser.textContent = "Copied";
      });
      // NextPass copies the password itself: concealed from clipboard managers
      // and cleared again, and it never passes through the browser.
      const copyPassword = element("button", { textContent: "Password", title: "Copy password" });
      const copy = async () => {
        const response = await send({ action: "copyPassword", entryId: entry.id }).catch(() => null);
        if (response?.ok) {
          copyPassword.textContent = "Copied";
        } else {
          showRequestFailure(response, () => showSearch());
        }
      };
      copyPassword.addEventListener("click", (event) => {
        event.stopPropagation();
        copy();
      });
      const row = element("li", { className: index === selectedIndex ? "selected" : "" }, [
        element("div", { className: "entry" }, [
          element("div", { className: "title", textContent: entry.title || "Untitled" }),
          element("div", { className: "user", textContent: entry.username }),
        ]),
        ...(entry.username ? [copyUser] : []),
        copyPassword,
      ]);
      row.addEventListener("click", () => fill(entry));
      return row;
    })
  );
}

async function fill(entry) {
  const response = await send({ action: "credentials", entryId: entry.id }).catch(() => null);
  if (!response?.ok) {
    showRequestFailure(response, () => fill(entry));
    return;
  }
  if (!activeTab?.id) return;
  const pageSite = siteOf(new URL(activeTab.url).hostname);
  const allowedSites = [pageSite, ...(await grantedSites(pageSite))];
  if (await fillFrames(response, allowedSites)) {
    window.close();
    return;
  }

  // Some sites load the login form from another site in a frame (ID Austria
  // from service.a-trust.at). Filling there takes the user's explicit consent.
  const otherSites = skippedSites();
  if (otherSites.length === 0) {
    showMessage(fillError ? `NextPass couldn't reach this page: ${fillError}` : `No login fields found on this page. ${describeFrames()}`, { warn: true });
    return;
  }
  const site = otherSites[0];
  showMessage(`The login form on this page comes from ${site}. Fill it there?`, {
    button: `Fill on ${site}`,
    onClick: async () => {
      await rememberGrant(pageSite, site);
      if (await fillFrames(response, [...allowedSites, site])) {
        window.close();
      } else {
        showMessage(`No login fields found on this page. ${describeFrames()}`, { warn: true });
      }
    },
  });
}

/// Fills frame by frame, from the browser's own list of the tab's frames and
/// their current addresses: an iframe's `src` goes stale after a redirect (ID
/// Austria's login frame lands on service.a-trust.at), and one off-limits frame
/// would make an all-frames injection fail outright.
async function fillFrames(credentials, allowedSites) {
  frameReports = [];
  fillError = undefined;
  let lastError;
  for (const frame of await tabFrames()) {
    const host = hostOf(frame.url);
    // A frame without a host of its own (about:blank) is judged inside by the
    // origin it inherited.
    if (host && !isOnSite(host, allowedSites)) {
      frameReports.push({ host, site: siteOf(host), skipped: true });
      continue;
    }
    try {
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: activeTab.id, frameIds: [frame.frameId] },
        func: fillLogin,
        args: [credentials.username, credentials.password, allowedSites],
      });
      if (result?.result) frameReports.push(result.result);
    } catch (error) {
      lastError = error;
    }
  }
  if (frameReports.some((report) => report.filled > 0)) return true;
  if (!frameReports.some((report) => !report.skipped)) fillError = lastError?.message;
  return false;
}

async function tabFrames() {
  return (await chrome.webNavigation.getAllFrames({ tabId: activeTab.id }).catch(() => null))
    ?? [{ frameId: 0, url: activeTab.url }];
}

function hostOf(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" || parsed.protocol === "http:" ? parsed.hostname : "";
  } catch {
    return "";
  }
}

/// A host's registrable domain (apple.com for idmsa.apple.com), from the
/// Public Suffix List; an IP address or single-label host stands for itself.
function siteOf(host) {
  return tldts.getDomain(host, { allowPrivateDomains: true }) ?? host;
}

function isOnSite(host, sites) {
  return sites.some((site) => host === site || host.endsWith(`.${site}`));
}

/// Other sites the user allowed NextPass to fill in on this page's site. An
/// allowance stays with the site it was given on: allowing A-Trust on ID
/// Austria does not let an A-Trust frame on another site get filled.
async function grantedSites(pageSite) {
  const { siteGrants = {} } = await chrome.storage.local.get("siteGrants");
  return siteGrants[pageSite] ?? [];
}

async function rememberGrant(pageSite, frameSite) {
  const { siteGrants = {} } = await chrome.storage.local.get("siteGrants");
  siteGrants[pageSite] = [...new Set([...(siteGrants[pageSite] ?? []), frameSite])];
  await chrome.storage.local.set({ siteGrants });
}

/// Sites whose frames the last fill had to skip: where a login form may be.
function skippedSites() {
  return [...new Set(frameReports.filter((report) => report.skipped).map((report) => report.site))];
}

function describeFrames() {
  if (frameReports.length === 0) return "(No frame answered.)";
  const parts = frameReports.map((report) => report.skipped
    ? `${report.host}: skipped`
    : `${report.host}: ${report.inputs} fields, ${report.passwords} password`);
  return `(${parts.join("; ")})`;
}

// Runs inside the page (each frame). Fills only frames on an allowed site —
// the page's own, plus sites the user allowed — so a login box embedded from
// anywhere else never receives the password.
function fillLogin(username, password, allowedSites) {
  // The origin, not the URL: an about:blank or srcdoc frame a page writes its
  // login form into has no host of its own but inherits the page's origin.
  const frameHost = location.origin === "null" ? "" : new URL(location.origin).hostname;
  const report = { host: frameHost || location.href.slice(0, 40), inputs: 0, passwords: 0, filled: 0 };
  const allowed = frameHost !== "" && allowedSites.some((site) => frameHost === site || frameHost.endsWith(`.${site}`));
  if (!allowed) return { ...report, skipped: true };

  const isUsable = (input) => {
    const rect = input.getBoundingClientRect();
    const style = getComputedStyle(input);
    return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden"
      && style.display !== "none" && !input.disabled && !input.readOnly;
  };
  const setValue = (input, value) => {
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
    input.focus();
    setter.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
  };

  const inputs = [...document.querySelectorAll("input")].filter(isUsable);
  report.inputs = inputs.length;
  report.passwords = inputs.filter((input) => input.type === "password").length;
  const isUserField = (input) => ["text", "email", "tel", ""].includes(input.type) || input.autocomplete === "username";
  const passwordField = inputs.find((input) => input.type === "password");
  let userField;
  if (passwordField) {
    const before = inputs.slice(0, inputs.indexOf(passwordField)).reverse();
    userField = before.find(isUserField);
  } else {
    // A two-step login asks for the user name alone first.
    const candidates = inputs.filter(isUserField);
    userField = candidates.find((input) => /user|mail|login|name/i.test(`${input.name} ${input.id} ${input.autocomplete}`)) ?? candidates[0];
  }

  if (passwordField && password) {
    setValue(passwordField, password);
    report.filled++;
  }
  if (userField && username) {
    setValue(userField, username);
    report.filled++;
  }
  return report;
}

(async () => {
  clientKey = await loadClientKey();
  [activeTab] = await chrome.tabs.query({ active: true, currentWindow: true });
  refresh();
})();
