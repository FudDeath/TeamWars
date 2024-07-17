module game::dungeons {
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use game::character::{Self, Character};
    use game::ocw_token::OCW;

    const NOVICE_DUNGEON_COST: u64 = 0;
    const ADEPT_DUNGEON_COST: u64 = 100;
    const EXPERT_DUNGEON_COST: u64 = 200;
    const MASTER_DUNGEON_COST: u64 = 300;
    const LEGENDARY_DUNGEON_COST: u64 = 400;

    public entry fun enter_dungeon(
        character: &mut Character,
        dungeon_level: u8,
        payment: Coin<OCW>,
        ctx: &mut TxContext
    ) {
        assert!(!character::is_injured(character), 1);

        let cost = get_dungeon_cost(dungeon_level);
        assert!(coin::value(&payment) >= cost, 2);

        if (cost > 0) {
            let payment_split = coin::split(&mut payment, cost, ctx);
            coin::burn(payment_split);
            transfer::public_transfer(payment, tx_context::sender(ctx));
        } else {
            transfer::public_transfer(payment, tx_context::sender(ctx));
        };
    }

    public entry fun complete_dungeon(
        character: &mut Character,
        dungeon_level: u8,
        ctx: &mut TxContext
    ) {
        let success = is_dungeon_success(dungeon_level);

        if (success) {
            let exp_gain = get_exp_gain(dungeon_level);
            let ocw_reward = get_ocw_reward(dungeon_level);
            character::level_up(character, exp_gain);

            let ocw_coin = ocw_token::mint_to_sender(ocw_reward, ctx);
            transfer::public_transfer(ocw_coin, tx_context::sender(ctx));
        } else {
            let damage = get_dungeon_damage(dungeon_level, character);
            character::take_damage(character, damage);
        };
    }

    fun get_dungeon_cost(dungeon_level: u8): u64 {
        if (dungeon_level == 1) NOVICE_DUNGEON_COST
        else if (dungeon_level == 2) ADEPT_DUNGEON_COST
        else if (dungeon_level == 3) EXPERT_DUNGEON_COST
        else if (dungeon_level == 4) MASTER_DUNGEON_COST
        else LEGENDARY_DUNGEON_COST
    }

    fun is_dungeon_success(dungeon_level: u8): bool {
        let random_number = tx_context::epoch(ctx) % 100;
        if (dungeon_level == 1) true
        else if (dungeon_level == 2 && random_number <= 70) true
        else if (dungeon_level == 3 && random_number <= 50) true
        else if (dungeon_level == 4 && random_number <= 40) true
        else if (dungeon_level == 5 && random_number <= 20) true
        else false
    }

    fun get_exp_gain(dungeon_level: u8): u64 {
        if (dungeon_level == 1) 100
        else if (dungeon_level == 2) 250
        else if (dungeon_level == 3) 450
        else if (dungeon_level == 4) 1000
        else 3000
    }

    fun get_ocw_reward(dungeon_level: u8): u64 {
        if (dungeon_level == 1) 10
        else if (dungeon_level == 2) 20
        else if (dungeon_level == 3) 40
        else if (dungeon_level == 4) 60
        else 80
    }

    fun get_dungeon_damage(dungeon_level: u8, character: &mut Character): u64 {
        let max_hp = character::get_max_hp(character);
        if (dungeon_level == 2) max_hp * 30 / 100
        else if (dungeon_level == 3) max_hp * 50 / 100
        else if (dungeon_level == 4) max_hp * 60 / 100
        else max_hp * 80 / 100
    }
}
