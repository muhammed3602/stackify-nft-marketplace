import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures marketplace fee can only be set by owner",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('stackify_marketplace', 'set-marketplace-fee', [types.uint(300)], deployer.address),
      Tx.contractCall('stackify_marketplace', 'set-marketplace-fee', [types.uint(300)], user1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
  },
});

Clarinet.test({
  name: "Can list NFT for sale",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const nftContract = deployer.address + ".test-nft";
    
    let block = chain.mineBlock([
      Tx.contractCall('stackify_marketplace', 'list-nft', [
        types.principal(nftContract),
        types.uint(1),
        types.uint(1000000)
      ], user1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify listing exists
    let getListingBlock = chain.mineBlock([
      Tx.contractCall('stackify_marketplace', 'get-listing', [
        types.principal(nftContract),
        types.uint(1)
      ], user1.address)
    ]);
    
    const listing = getListingBlock.receipts[0].result.expectSome();
    assertEquals(listing['seller'], user1.address);
    assertEquals(listing['price'], types.uint(1000000));
  },
});

Clarinet.test({
  name: "Can make and accept offers",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const seller = accounts.get('wallet_1')!;
    const buyer = accounts.get('wallet_2')!;
    const nftContract = deployer.address + ".test-nft";
    
    let block = chain.mineBlock([
      // List NFT
      Tx.contractCall('stackify_marketplace', 'list-nft', [
        types.principal(nftContract),
        types.uint(1),
        types.uint(1000000)
      ], seller.address),
      
      // Make offer
      Tx.contractCall('stackify_marketplace', 'make-offer', [
        types.principal(nftContract),
        types.uint(1)
      ], buyer.address),
      
      // Accept offer
      Tx.contractCall('stackify_marketplace', 'accept-offer', [
        types.principal(nftContract),
        types.uint(1),
        types.principal(buyer.address)
      ], seller.address)
    ]);
    
    block.receipts.map(receipt => receipt.result.expectOk());
  },
});