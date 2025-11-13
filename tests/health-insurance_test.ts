import { Clarinet, Tx, Chain, Account, types } from "https://deno.land/x/clarinet/index.ts";

Clarinet.test({
  name: "Liquidity: first LP gets 1:1 shares; second LP gets proportional shares",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const w1 = accounts.get("wallet_1")!;
    const w2 = accounts.get("wallet_2")!;

    let block = chain.mineBlock([
      Tx.contractCall("health-insurance", "deposit-liquidity", [types.uint(1_000_000)], w1.address),
    ]);
    block.receipts[0].result.expectOk().expectUint(1_000_000);

    // totals
    let call = chain.callReadOnlyFn("health-insurance", "get-totals", [], deployer.address);
    call.result.expectOk().expectTuple()["total-liquidity"].expectUint(1_000_000);

    // second LP deposits; shares should equal amount because ts==tl initially
    block = chain.mineBlock([
      Tx.contractCall("health-insurance", "deposit-liquidity", [types.uint(500_000)], w2.address),
    ]);
    block.receipts[0].result.expectOk().expectUint(500_000);

    // w1 withdraws part of shares
    block = chain.mineBlock([
      Tx.contractCall("health-insurance", "withdraw-liquidity", [types.uint(250_000)], w1.address),
    ]);
    block.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Policies: create, pay premium activates, file claim, approve by owner",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const user = accounts.get("wallet_1")!;

    // set owner
    let b1 = chain.mineBlock([
      Tx.contractCall("health-insurance", "set-owner", [], deployer.address),
    ]);
    b1.receipts[0].result.expectOk().expectBool(true);

    // create user policy
    let b2 = chain.mineBlock([
      Tx.contractCall("health-insurance", "create-policy", [types.uint(100_000), types.uint(1_000_000)], user.address),
    ]);
    b2.receipts[0].result.expectOk().expectBool(true);

    // pay premium -> activates policy and increases total-liquidity
    let b3 = chain.mineBlock([
      Tx.contractCall("health-insurance", "pay-premium", [types.uint(100_000)], user.address),
    ]);
    b3.receipts[0].result.expectOk();

    // file a claim
    let b4 = chain.mineBlock([
      Tx.contractCall("health-insurance", "file-claim", [types.uint(50_000)], user.address),
    ]);
    b4.receipts[0].result.expectOk();

    // approve claim by owner (deployer)
    let b5 = chain.mineBlock([
      Tx.contractCall("health-insurance", "approve-claim", [types.uint(0), types.uint(50_000)], deployer.address),
    ]);
    b5.receipts[0].result.expectOk().expectBool(true);
  },
});
