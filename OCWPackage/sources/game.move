module ocw::main {

    use sui::coin::Coin;

    use ocw::{
        ocw::OCW,
        character::Character,
    };
    
    // @dev We need to wrap a TreasuryCap to freely mint.
    public fun init_state() {}

    public entry fun heal_character(character: &mut Character, mut payment: Coin<OCW>, ctx: &mut TxContext) {
        let cost = character.healing_cost();
        assert!(payment.value() >= cost, 1);

        let payment_split = payment.split(cost, ctx);
        
        transfer::public_transfer(payment_split, @0x0);

        transfer::public_transfer(payment, tx_context::sender(ctx));

        let max_hp = character.max_hp();

        character.heal(max_hp);
    }
}
