// Agent Streak frontend — no build step, ethers v6 via CDN.
//
// Wallets: the user's own injected wallet only (window.ethereum, e.g. MetaMask
// or any injected wallet). There is NO QR-code or pairing-code login flow here,
// and the app never asks for or handles seeds, private keys, or pairing codes.
// Every transaction is sent by the user and confirmed in their own wallet.

const RPC_URL = "https://bsc-dataseed.binance.org/";
const CHAIN_ID = 56; // BSC mainnet
const AGENT_ID_REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F";

// Set by the deploy step. Until then the page shows read-only info and a
// "not deployed yet" banner; check-ins stay disabled.
const CONTRACT_ADDRESS = "0xb3662fEb6F4cbDF2ca4FC561C618D8Ffdd0Afb24"; // AgentStreak deployed on BNB Chain (BSC mainnet), 18 Nov 2026

const REGISTRY_ABI = ["function balanceOf(address owner) view returns (uint256)"];
const STREAK_ABI = [
  "function checkIn()",
  "function currentDay() view returns (uint256)",
  "function streakOf(address user) view returns (uint256)",
  "function statsOf(address user) view returns (uint256 currentStreak, uint256 longestStreak, uint256 totalCheckins, uint256 lastCheckinDay)",
  "function totalUsers() view returns (uint256)",
  "function userAt(uint256 index) view returns (address)",
  "function totalCheckins() view returns (uint256)",
  "function hasCheckedInToday(address user) view returns (bool)",
  "event Checkin(address indexed user, uint256 indexed day, uint256 streak)",
];

const $ = (id) => document.getElementById(id);
const short = (addr) => (addr ? addr.slice(0, 6) + "…" + addr.slice(-4) : "—");

let readProvider = null;
let registry = null;
let streak = null;
let userAddress = null;

function setStatus(msg, kind) {
  const el = $("status");
  el.textContent = msg;
  el.className = kind === "ok" ? "ok" : kind === "warn" ? "warn" : "muted";
}

async function refreshGlobal() {
  if (!streak) {
    $("statUsers").textContent = "—";
    $("statGlobal").textContent = "—";
    $("leaderboard").textContent = "The leaderboard opens after deployment.";
    return;
  }
  try {
    const [users, total] = await Promise.all([streak.totalUsers(), streak.totalCheckins()]);
    $("statUsers").textContent = users.toString();
    $("statGlobal").textContent = total.toString();
    await refreshLeaderboard(Number(users));
  } catch (e) {
    console.error(e);
    $("leaderboard").textContent = "Could not load on-chain data. Please try again later.";
  }
}

async function refreshLeaderboard(userCount) {
  const board = $("leaderboard");
  const fetchCount = Math.min(userCount, 500); // keep the page responsive
  if (fetchCount === 0) {
    board.textContent = "No check-ins yet. Be the first!";
    return;
  }
  board.textContent = "Loading…";
  const rows = [];
  const batch = 20;
  for (let i = 0; i < fetchCount; i += batch) {
    const idxs = [];
    for (let j = i; j < Math.min(i + batch, fetchCount); j++) idxs.push(j);
    const addrs = await Promise.all(idxs.map((k) => streak.userAt(k)));
    const stats = await Promise.all(addrs.map((a) => streak.statsOf(a)));
    for (let k = 0; k < addrs.length; k++) {
      rows.push({
        user: addrs[k],
        current: Number(stats[k][0]),
        longest: Number(stats[k][1]),
        total: Number(stats[k][2]),
      });
    }
  }
  rows.sort((a, b) => b.current - a.current || b.total - a.total);
  const top = rows.slice(0, 50);
  let html = "<table><tr><th>#</th><th>Player</th><th class='num'>Streak</th><th class='num'>Longest</th><th class='num'>Total</th></tr>";
  top.forEach((r, i) => {
    const mark = r.user === userAddress ? " ★" : "";
    html += `<tr><td>${i + 1}</td><td class="mono">${short(r.user)}${mark}</td><td class="num">${r.current}</td><td class="num">${r.longest}</td><td class="num">${r.total}</td></tr>`;
  });
  html += "</table>";
  if (userCount > 500) html += `<p class="muted">Showing the top 50 of ${userCount} players (first 500 scanned).</p>`;
  board.innerHTML = html;
}

async function refreshUser() {
  if (!userAddress) return;
  if (!streak) {
    $("statCurrent").textContent = "—";
    $("statLongest").textContent = "—";
    $("statTotal").textContent = "—";
    $("statToday").textContent = "—";
    return;
  }
  try {
    const [stats, today] = await Promise.all([
      streak.statsOf(userAddress),
      streak.hasCheckedInToday(userAddress),
    ]);
    $("statCurrent").textContent = stats[0].toString();
    $("statLongest").textContent = stats[1].toString();
    $("statTotal").textContent = stats[2].toString();
    $("statToday").textContent = today ? "✓ done" : "not yet";
    $("checkinBtn").disabled = today;
    $("checkinBtn").textContent = today ? "Already checked in" : "Check in today";
  } catch (e) {
    console.error(e);
    setStatus("Could not load your streak. Please try again.", "warn");
  }
}

async function connect() {
  if (!window.ethereum) {
    setStatus("No injected wallet found. Please install a wallet extension and reload.", "warn");
    return;
  }
  try {
    const browserProvider = new ethers.BrowserProvider(window.ethereum);
    const network = await browserProvider.getNetwork();
    if (Number(network.chainId) !== CHAIN_ID) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x38" }],
        });
      } catch (e) {
        setStatus("Please switch your wallet to BSC mainnet (chain 56) and try again.", "warn");
        return;
      }
    }
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    userAddress = accounts[0];
    $("connectBtn").textContent = "Connected: " + short(userAddress);

    const balance = await registry.balanceOf(userAddress);
    const holdsId = balance > 0n;
    $("walletInfo").innerHTML =
      `Address: <span class="mono">${short(userAddress)}</span><br>` +
      `Agent ID: <span class="${holdsId ? "ok" : "warn"}">${holdsId ? "held ✓" : "not held — check-ins need an Agent ID"}</span>`;
    $("checkinBtn").disabled = !holdsId || !streak;
    if (!holdsId) setStatus("This address does not hold an Agent ID, so it cannot check in.", "warn");
    else setStatus("Connected.", "ok");

    await refreshUser();
    await refreshLeaderboard(Number($("statUsers").textContent) || 0);
  } catch (e) {
    console.error(e);
    setStatus("Connection failed: " + (e && e.message ? e.message : e), "warn");
  }
}

async function checkIn() {
  if (!userAddress || !streak) return;
  setStatus("Sending your check-in… confirm it in your wallet.", "");
  try {
    const browserProvider = new ethers.BrowserProvider(window.ethereum);
    const signer = await browserProvider.getSigner();
    const writable = new ethers.Contract(CONTRACT_ADDRESS, STREAK_ABI, signer);
    const tx = await writable.checkIn();
    setStatus("Check-in sent, waiting for confirmation… " + short(tx.hash), "");
    await tx.wait();
    setStatus("Checked in! Your streak is live. ✓", "ok");
    await refreshUser();
    await refreshGlobal();
  } catch (e) {
    console.error(e);
    const msg = e && e.message ? e.message : String(e);
    if (msg.includes("AlreadyCheckedInToday") || msg.includes("user rejected")) {
      setStatus("Check-in did not go through: " + (msg.includes("AlreadyCheckedInToday") ? "already checked in today." : "you rejected it in your wallet."), "warn");
    } else {
      setStatus("Check-in failed: " + msg.slice(0, 200), "warn");
    }
  }
}

// --- init ---
// If the ethers CDN is unreachable the page must fail visibly, not silently.
if (typeof ethers === "undefined") {
  if (!CONTRACT_ADDRESS) $("deployBanner").hidden = false;
  $("leaderboard").textContent = "Could not load the ethers library. Check your connection and reload the page.";
  setStatus("Could not load the ethers library (CDN). Check your connection and reload.", "warn");
} else {
  readProvider = new ethers.JsonRpcProvider(RPC_URL);
  registry = new ethers.Contract(AGENT_ID_REGISTRY, REGISTRY_ABI, readProvider);
  streak = CONTRACT_ADDRESS
    ? new ethers.Contract(CONTRACT_ADDRESS, STREAK_ABI, readProvider)
    : null;

  $("connectBtn").addEventListener("click", connect);
  $("checkinBtn").addEventListener("click", checkIn);

  if (!CONTRACT_ADDRESS) {
    $("deployBanner").hidden = false;
    $("checkinBtn").disabled = true;
  } else {
    $("contractAddr").textContent = CONTRACT_ADDRESS;
  }

  refreshGlobal();
}
