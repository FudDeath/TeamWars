module game::ocw_token {
    use sui::coin;
    use sui::tx_context::TxContext;

    struct OCW has drop {}

    fun init(witness: OCW, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"OCW", b"On-Chain Clan Wars Token", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    public entry fun mint(treasury: &mut Treasury, amount: u64, recipient: address, ctx: &mut TxContext) {
        coin::mint_and_transfer(treasury, amount, recipient, ctx)
    }

    public fun mint_to_sender(amount: u64, ctx: &mut TxContext): Coin<OCW> {
        coin::mint_for_testing<OCW>(amount, ctx)
    }
}
