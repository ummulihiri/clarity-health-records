// [Previous test content remains, adding new tests...]

Clarinet.test({
  name: "Batch record operations test",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const patient = accounts.get('wallet_1')!;
    const provider = accounts.get('wallet_2')!;
    
    // Setup and registration
    let setup = chain.mineBlock([
      Tx.contractCall('health-records', 'register-patient', [], patient.address),
      Tx.contractCall('health-records', 'register-provider-with-details', [
        types.ascii("GENERAL"),
        types.uint(2)
      ], provider.address)
    ]);
    
    // Grant access
    let accessGrant = chain.mineBlock([
      Tx.contractCall('health-records', 'grant-access', [
        types.principal(provider.address),
        types.uint(100),
        types.bool(false)
      ], patient.address)
    ]);
    
    // Test batch record addition
    let batchAdd = chain.mineBlock([
      Tx.contractCall('health-records', 'add-batch-records', [
        types.principal(patient.address),
        types.list([
          types.ascii("hash1"),
          types.ascii("hash2"),
          types.ascii("hash3")
        ]),
        types.ascii("UPDATE"),
        types.ascii("GENERAL")
      ], provider.address)
    ]);
    
    batchAdd.receipts[0].result.expectOk();
  },
});
