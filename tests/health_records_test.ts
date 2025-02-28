import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Patient and provider registration test",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const patient = accounts.get('wallet_1')!;
    const provider = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      Tx.contractCall('health-records', 'register-patient', [], patient.address),
      Tx.contractCall('health-records', 'register-provider', [], provider.address)
    ]);

    block.receipts.forEach(receipt => {
      receipt.result.expectOk().expectBool(true);
    });
  },
});

Clarinet.test({
  name: "Access grant and record creation with categories test",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const patient = accounts.get('wallet_1')!;
    const provider = accounts.get('wallet_2')!;
    
    // Register accounts
    let setup = chain.mineBlock([
      Tx.contractCall('health-records', 'register-patient', [], patient.address),
      Tx.contractCall('health-records', 'register-provider', [], provider.address)
    ]);

    // Grant access
    let accessBlock = chain.mineBlock([
      Tx.contractCall('health-records', 'grant-access', [
        types.principal(provider.address),
        types.uint(100),
        types.bool(false)
      ], patient.address)
    ]);
    accessBlock.receipts[0].result.expectOk().expectBool(true);

    // Add record with category
    let recordBlock = chain.mineBlock([
      Tx.contractCall('health-records', 'add-record', [
        types.principal(patient.address),
        types.ascii("0x1234567890abcdef"),
        types.ascii("UPDATE"),
        types.ascii("GENERAL")
      ], provider.address)
    ]);
    recordBlock.receipts[0].result.expectOk().expectUint(1);

    // Verify access and history
    let accessCheck = chain.mineBlock([
      Tx.contractCall('health-records', 'check-access', [
        types.principal(provider.address),
        types.principal(patient.address)
      ], patient.address),
      Tx.contractCall('health-records', 'get-access-history', [
        types.uint(1)
      ], provider.address)
    ]);
    accessCheck.receipts[0].result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Emergency access test",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const patient = accounts.get('wallet_1')!;
    const provider = accounts.get('wallet_2')!;

    // Setup with emergency access
    let setup = chain.mineBlock([
      Tx.contractCall('health-records', 'register-patient', [], patient.address),
      Tx.contractCall('health-records', 'register-provider', [], provider.address),
      Tx.contractCall('health-records', 'grant-access', [
        types.principal(provider.address),
        types.uint(100),
        types.bool(true)
      ], patient.address)
    ]);

    // Add emergency record
    let emergencyRecord = chain.mineBlock([
      Tx.contractCall('health-records', 'add-record', [
        types.principal(patient.address),
        types.ascii("0x1234567890abcdef"),
        types.ascii("EMERGENCY"),
        types.ascii("EMERGENCY")
      ], provider.address)
    ]);
    emergencyRecord.receipts[0].result.expectOk().expectUint(1);
  },
});
