module game::main {
    use sui::transfer;
    use sui::tx_context::TxContext;
    use game::character::{Self, Character};
    use game::dungeons;
    use game::ocw_token::{Self, OCW};

    struct GAME has drop {}

    fun init(witness: GAME, ctx: &mut TxContext) {
        ocw_token::init(OCW {}, ctx);
    }

    public entry fun create_character(ctx: &mut TxContext) {
        let character = character::new(ctx);
        transfer::transfer(character, tx_context::sender(ctx));
    }

    public entry fun enter_dungeon(character: &mut Character, dungeon_level: u8, payment: Coin<OCW>, ctx: &mut TxContext) {
        dungeons::enter_dungeon(character, dungeon_level, payment, ctx);
    }

    public entry fun complete_dungeon(character: &mut Character, dungeon_level: u8, ctx: &mut TxContext) {
        dungeons::complete_dungeon(character, dungeon_level, ctx);
    }

    public entry fun heal_character(character: &mut Character, payment: Coin<OCW>, ctx: &mut TxContext) {
        let cost = character::get_healing_cost(character);
        assert!(coin::value(&payment) >= cost, 1);

        let payment_split = coin::split(&mut payment, cost, ctx);
        coin::burn(payment_split);
        transfer::public_transfer(payment, tx_context::sender(ctx));

        character::heal(character, character::get_max_hp(character));
    }
}
