// NextPass browser extension popup. Talks to the running NextPass app on
// 127.0.0.1 (the browser marks these requests with this extension's origin,
// which NextPass checks); the app holds the vault and decides what this
// extension may see. The extension stores only its own random pairing key.

const ENDPOINT = "http://127.0.0.1:19735/";
const content = document.getElementById("content");
const databaseLabel = document.getElementById("database");

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

function browserName() {
  return navigator.brave ? "Brave" : "Chrome";
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
  if (!status.unlocked) {
    showMessage("NextPass is locked.", { button: "Unlock in NextPass", onClick: unlock });
    return;
  }
  showSearch();
}

async function pair() {
  showMessage("Confirm in NextPass…");
  const response = await send({ action: "pair", clientName: browserName() }).catch(() => null);
  if (response?.ok) {
    refresh();
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
  const pageHost = new URL(activeTab.url).hostname;
  const allowedHosts = [pageHost, ...(await grantedHosts())];
  if (await fillFrames(response, allowedHosts)) {
    window.close();
    return;
  }

  // Some sites load the login form from another site in a frame (ID Austria
  // from service.a-trust.at). Filling there takes the user's explicit consent,
  // and the browser's own permission for exactly that site.
  const otherHosts = (await embeddedFrameHosts()).filter((host) => !allowedHosts.some((allowed) => sameSite(host, allowed)));
  if (otherHosts.length === 0) {
    showMessage(fillError ? `NextPass couldn't reach this page: ${fillError}` : `No login fields found on this page. ${describeFrames()}`, { warn: true });
    return;
  }
  const host = otherHosts[0];
  showMessage(`The login form on this page comes from ${host}. Fill it there?`, {
    button: `Allow ${host} and Fill`,
    onClick: async () => {
      const granted = await chrome.permissions.request({ origins: [`https://${host}/*`] });
      if (!granted) {
        showMessage(`NextPass didn't fill the form on ${host}.`, { warn: true });
      } else if (await fillFrames(response, [...allowedHosts, host])) {
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
async function fillFrames(credentials, allowedHosts) {
  frameReports = [];
  fillError = undefined;
  let lastError;
  for (const frame of await tabFrames()) {
    const host = hostOf(frame.url);
    // A frame without a host of its own (about:blank) is judged inside by the
    // origin it inherited.
    if (host && !allowedHosts.some((allowed) => sameSite(host, allowed))) {
      frameReports.push({ host, skipped: true });
      continue;
    }
    try {
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: activeTab.id, frameIds: [frame.frameId] },
        func: fillLogin,
        args: [credentials.username, credentials.password, allowedHosts],
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

/// Sites the user has allowed NextPass to fill in, beyond the page's own.
async function grantedHosts() {
  const { origins = [] } = await chrome.permissions.getAll();
  return origins
    .filter((origin) => origin.startsWith("https://") && !origin.includes("*."))
    .map((origin) => new URL(origin.replace(/\*$/, "")).hostname);
}

/// Sites whose frames the last fill had to skip: where a login form may be.
async function embeddedFrameHosts() {
  return [...new Set(frameReports.filter((report) => report.skipped).map((report) => report.host))];
}

function describeFrames() {
  if (frameReports.length === 0) return "(No frame answered.)";
  const parts = frameReports.map((report) => report.skipped
    ? `${report.host}: skipped`
    : `${report.host}: ${report.inputs} fields, ${report.passwords} password`);
  return `(${parts.join("; ")})`;
}

function sameSite(first, second) {
  const bare = (host) => host.replace(/^www\./, "");
  const a = bare(first);
  const b = bare(second);
  return a === b || a.endsWith(`.${b}`) || b.endsWith(`.${a}`);
}

// Runs inside the page (each frame). Fills only frames on an allowed host or a
// parent/subdomain of one — the page's own site, plus sites the user allowed —
// so a login box embedded from anywhere else never receives the password.
function fillLogin(username, password, allowedHosts) {
  const bare = (host) => host.replace(/^www\./, "");
  // The origin, not the URL: an about:blank or srcdoc frame a page writes its
  // login form into has no host of its own but inherits the page's origin.
  const originHost = location.origin === "null" ? "" : new URL(location.origin).hostname;
  const frameHost = bare(originHost);
  const report = { host: originHost || location.href.slice(0, 40), inputs: 0, passwords: 0, filled: 0 };
  const allowed = frameHost !== "" && allowedHosts.some((host) => {
    const pageHost = bare(host);
    return frameHost === pageHost || frameHost.endsWith(`.${pageHost}`) || pageHost.endsWith(`.${frameHost}`);
  });
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
