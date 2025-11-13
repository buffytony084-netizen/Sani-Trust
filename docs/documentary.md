# Sani-Trust: A Health Insurance Protocol on Stacks

This documentary walks through a from-scratch build of a minimal health insurance protocol, focusing on:

- Liquidity pool mechanics (LP shares mint/burn)
- Policy lifecycle (create, premium payments, claims)
- Tests validating behavior
- A basic UI and a redesigned UI

The intent is educational: show an end-to-end flow without leaning on auto-generated code.

## 1. Motivation and Requirements

- Allow liquidity providers to deposit capital and receive proportional shares.
- Allow users to create a policy, pay premiums, and file claims.
- Admins (contract owner) can approve claims which reduces pool liquidity.
- Provide tests and two UI iterations.

Would count (addressed here):
- New set of Clarity functions for depositing liquidity into a protocol
- Set of Clarinet tests to test that functionality
- UI to connect to those Clarity functions
- Redesign of that UI to improve user experience

Would not count (excluded):
- Only adding a read-only function
- Only a README
- Only a single button UI
- Pure reformatting/styling changes
- Auto-generated scaffolds without substance

## 2. Architecture Overview

- Contract: `contracts/health-insurance.clar`
  - Tracks `total-liquidity` and `total-shares`
  - `deposit-liquidity(amount)` mints shares; `withdraw-liquidity(shares)` burns shares
  - Policies and claims with simple lifecycle
  - Owner gate for claim approval
- Tests: `tests/health-insurance_test.ts` (Deno + Clarinet)
- UI v1: Minimal functional forms (`ui-v1/`)
- UI v2: Redesign with improved UX (`ui-v2-redesign/`)

Note: For simplicity, deposits and payouts are accounted internally (no STX transfer). In production, integrate SIP-010 (FT) or STX flows.

```
Users ──(create policy/pay premium/file claim)──▶ Contract ◀──(deposit/withdraw)── LPs
                                  │
                                  └── Admin approves claim ──▶ reduces pool
```

## 3. Smart Contract Walkthrough

Key data:
- `lps: principal → {shares, deposited}`
- `total-liquidity`, `total-shares`
- `policies: principal → {premium, coverage, active, paid}`
- `claims: id → {holder, amount, approved}`

Shares formula:
- If first LP: `new-shares = amount`
- Else: `new-shares = amount * total-shares / total-liquidity`

Withdraw formula:
- `amount = shares * total-liquidity / total-shares`

Admin:
- `set-owner()` and `approve-claim(id, amount)`

Read-only helpers: `get-totals`, `get-lp`, `get-policy`, `get-claim`.

## 4. Tests

Scenarios covered:
- First and second LP deposits, partial withdraw
- Policy creation, premium payment activates, claim file + approve

Run:
- Install Clarinet, then `clarinet test` from repo root.

## 5. UI and Redesign

- v1: Simple forms to call contract functions via Stacks Connect UMD bundles.
- v2: Redesigned with layout, status feedback, withdraw flow, and helpers.

To use with devnet:
1. Deploy the contract with Clarinet (e.g., `clarinet console` then `::deploy . health-insurance` or via `Clarinet.toml` workflows).
2. Copy the deployed contract address into UI input.
3. Open `index.html` in a web server (e.g., `python3 -m http.server` inside the UI folder).
4. Connect your wallet and interact.

## 6. Future Work

- Integrate SIP-010 token for real deposits and payouts
- Underwriting/claim risk checks and price premium dynamically
- Oracle integrations for off-chain claim evidence
- Event indexing and richer UI dashboards

## 7. Security Notes

- Add access control beyond single owner if needed (role-based)
- Guard against rounding edge cases on shares accounting
- Use audited token contracts for capital flows

---
Built for educational purposes. Use at your own risk.
