# Agent Streak

**Agent Streak** is a daily check-in game for Agent ID holders, built for the
Binance Agent ID Hackathon.

Check in once a day, keep the streak alive. One check-in per address per UTC
day. No fees, no rewards, nothing promised in return — just a public,
on-chain streak.

## How Agent ID is used

- **Access control** — only addresses that hold an Agent ID can call
  `checkIn()`. The contract reads `balanceOf(msg.sender)` on the Agent ID
  registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, SPACE ID Agent ID on
  BNB Chain) and reverts otherwise.
- **Identity** — streaks are keyed to the holder's address. The registry is
  non-transferable, so a streak belongs to the Agent ID holder behind it.
- **Leaderboard** — anyone can read the on-chain streaks; the frontend ranks
  players by current streak.

## How to use it

1. Open the app (GitHub Pages link below, or `index.html` directly).
2. Connect your own wallet (MetaMask, Binance Wallet, or any injected wallet).
   The app never asks for seeds, private keys, or pairing codes.
3. If your address holds an Agent ID, press **Check in today** and confirm the
   transaction in your own wallet. Check-ins cost gas only.
4. Come back tomorrow — checking in on consecutive UTC days grows your streak;
   missing a day resets it to 1.

## Contracts

| Contract | Address |
| --- | --- |
| AgentStreak | **TBD — not deployed yet** |
| Agent ID registry | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |

The AgentStreak contract is fully immutable after deployment: **no owner, no
admin functions, no pause, no fees, no payments, no minting**. The only thing
it does is record check-ins. Source: [`src/AgentStreak.sol`](src/AgentStreak.sol).

### Key functions

- `checkIn()` — check in for today (Agent ID holders only, once per UTC day).
  Emits `Checkin(user, day, streak)`.
- `streakOf(address)` / `statsOf(address)` — current streak, longest streak,
  total check-ins, last check-in day.
- `totalUsers()` / `userAt(uint256)` — iterate all players for the leaderboard.
- `hasCheckedInToday(address)` / `currentDay()` — today's status.

## Hackathon compliance notes

Agent Streak is built to stay inside the hackathon's safety red lines:

- **No QR-code / pairing-code login.** Users connect their own injected wallet
  (`window.ethereum`). There is no web login flow of any kind.
- **No confirmation bypass.** Every check-in is a transaction the user sends
  and confirms in their own wallet. Nothing is ever sent on a user's behalf.
- **No unauthorized transfers.** The contract holds no funds, takes no payments,
  and cannot move anyone's assets.
- **Open source, no owner permissions.** The contract source is in this repo
  (MIT). It has no owner and no privileged functions at all — there are no
  owner permissions to disclose.
- **No brand impersonation.** The project is called "Agent Streak". It does not
  use "Binance" or "BNB" in its name, token, or domain.
- **No credential collection.** The app never asks for seed phrases, private
  keys, API secrets, or pairing codes.
- **No promised returns.** There are no rewards, yields, or "passive income".
  A streak is a public record, not an earning.
- **No wallet lookup by name.** The app only ever looks up the connected
  wallet's own Agent ID status. It never resolves other people's Agent IDs to
  addresses.

## Development

Requires [Foundry](https://book.getfoundry.sh/) 1.9+.

```sh
forge build   # compile contracts/
forge test    # run the test suite (11 tests, no external dependencies)
```

The contract is dependency-free: the only interface it uses is a minimal
`balanceOf` view on the Agent ID registry, defined in
`src/AgentStreak.sol` itself. The test suite uses a mock registry and an
inline cheatcode interface — no forge-std, no OpenZeppelin.

The frontend is static (`index.html` + `app.js`, ethers v6 via CDN). There is
no build step. Set `CONTRACT_ADDRESS` in `app.js` after deployment.

## License

MIT — see [LICENSE](LICENSE).
