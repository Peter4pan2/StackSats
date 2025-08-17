
# StackSats - BTC-Lending-Protocol

**Version:** 1.0.0
**Summary:** A decentralized lending protocol enabling users to borrow Stacks assets (e.g., STX) against Bitcoin (BTC) collateral.

## 📜 Description

The **BTC-Lending-Protocol** allows users to deposit Bitcoin (BTC) as collateral and borrow STX or other Stacks-based assets. The protocol enforces over-collateralization, interest accrual, and liquidation mechanisms to ensure solvency and protect lenders. BTC collateral handling is abstracted for demonstration purposes and assumes off-chain or Bitcoin-bridge integration in production.

---

## 📦 Features

* 📥 **Deposit BTC Collateral** (simulated)
* 💸 **Borrow STX** with a 150% minimum collateral ratio
* 🔁 **Repay Loans** and reclaim BTC
* ⚠️ **Liquidate** undercollateralized loans
* 📊 **Interest Accrual** at 5% APR (approx. per block)
* 🔍 **Loan Health Monitoring** and protocol stats

---

## ⚙️ Constants

| Constant               | Value    | Description                            |
| ---------------------- | -------- | -------------------------------------- |
| `min-collateral-ratio` | `15000`  | 150% collateralization in basis points |
| `liquidation-ratio`    | `12000`  | Liquidation threshold = 120%           |
| `basis-points`         | `10000`  | Standard for expressing percentages    |
| `annual-interest-rate` | `500`    | 5% annual interest in basis points     |
| `BTC price (assumed)`  | `50,000` | 1 BTC = 50,000 STX (hardcoded for now) |

---

## 🧱 Data Structures

### Variables

* `next-loan-id` → Tracks the next available loan ID.
* `total-btc-collateral` → Total BTC collateral in protocol.
* `total-stx-borrowed` → Total STX borrowed across all loans.

### Maps

* `loans` → Maps loan IDs to loan details.
* `user-loans` → Maps users to their list of loan IDs.
* `btc-deposits` → Simulated BTC collateral balances per user.

---

## 🔓 Public Functions

### `deposit-btc-collateral(amount)`

Simulates depositing BTC to the protocol.

```clojure
(deposit-btc-collateral u10000) ;; deposits 10,000 satoshis of BTC
```

---

### `borrow-stx(stx-amount, btc-collateral-amount)`

Borrows STX using BTC as collateral.

```clojure
(borrow-stx u5000 u1) ;; borrow 5,000 STX using 1 BTC
```

✅ Requirements:

* Sufficient BTC deposited
* Collateral ratio ≥ 150%

---

### `repay-loan(loan-id)`

Repays a loan including accrued interest, returns BTC collateral.

```clojure
(repay-loan u1)
```

✅ Requirements:

* Only borrower can repay
* Loan must be active

---

### `liquidate-loan(loan-id)`

Liquidates an undercollateralized loan.

```clojure
(liquidate-loan u1)
```

✅ Requirements:

* Loan must be active
* Collateral ratio < 120%
* Liquidator receives 10% of BTC collateral

---

## 👁 Read-Only Functions

### `get-loan(loan-id)`

Returns full loan details.

```clojure
(get-loan u1)
```

---

### `get-btc-balance(user)`

Returns a user's BTC collateral balance.

```clojure
(get-btc-balance 'SP...')
```

---

### `get-user-loans(user)`

Returns a list of a user's loan IDs.

---

### `calculate-interest(loan-id)`

Calculates interest since the last update (block-based).

---

### `get-loan-health(loan-id)`

Returns the current collateral ratio (in basis points).

---

### `get-protocol-stats`

Returns overall protocol metrics:

```clojure
{
  total-btc-collateral: u1000,
  total-stx-borrowed: u50000,
  next-loan-id: u5
}
```

---

## 🔒 Private Functions

### `update-loan-interest(loan-id)`

Updates accrued interest and `last-update` block height.

Used internally for interest compounding and repayments.

---

## 🛠 Example Workflow

1. **User deposits BTC** (simulated):

   ```clojure
   (deposit-btc-collateral u2) ;; e.g., 2 BTC
   ```

2. **User borrows STX**:

   ```clojure
   (borrow-stx u50000 u1) ;; borrow 50,000 STX with 1 BTC
   ```

3. **Interest accrues over time** (per block).

4. **User repays loan**:

   ```clojure
   (repay-loan u0)
   ```

5. **If undercollateralized, third party can liquidate**:

   ```clojure
   (liquidate-loan u0)
   ```

---

## ⚠️ Error Codes

| Code                          | Meaning                      |
| ----------------------------- | ---------------------------- |
| `err-owner-only`              | Only borrower can call       |
| `err-not-found`               | Not found (loan/user/etc.)   |
| `err-insufficient-collateral` | Not enough BTC to cover loan |
| `err-loan-not-found`          | Loan does not exist          |
| `err-already-liquidated`      | Loan already closed          |
| `err-invalid-amount`          | Invalid token/loan amounts   |
| `err-loan-not-expired`        | (Unused - placeholder)       |
| `err-insufficient-balance`    | Not enough deposited BTC     |

---

## 🚧 Limitations

* 🔗 **BTC integration is simulated** (no real Bitcoin transfers).
* 🧮 **Interest compounding is simplified** (no auto-updates).
* 📈 **BTC price is hardcoded** (static at 50,000 STX/BTC).
* 🛡 **No oracle integration yet** — future enhancement.

---
