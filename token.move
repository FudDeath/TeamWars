module FW::ocw {
    use sui::coin::{Self, Coin, TreasuryCap};

    /// The type for the coin. This is used in the TreasuryCap
    public struct OCW has drop {}

    fun init(witness: OCW, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, // Decimals
            b"OCW", // Symbol
            b"OnChain Warriors Token", // Name
            b"Token for OnChain Warriors game", // Description
            option::none(), // Icon URL
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    /// Manager can mint new coins
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<OCW>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Manager can burn coins
    public entry fun burn(treasury_cap: &mut TreasuryCap<OCW>, coin: Coin<OCW>) {
        coin::burn(treasury_cap, coin);
    }
}
