module ocw::ocw {
    use sui::coin;

    public struct OCW has drop {}

    fun init(witness: OCW, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            6, 
            b"OCW", 
            b"On-Chain Clan Wars Token", 
            b"", 
            option::none(), 
            ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }
}
