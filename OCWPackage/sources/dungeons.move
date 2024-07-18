module ocw::dungeons {
    use sui::{
        random::Random,
        coin::{Self, Coin}
    };

    use ocw::{
        ocw::OCW,
        character::{Self, Character}
    };

    const NOVICE_DUNGEON_COST: u64 = 0;
    const ADEPT_DUNGEON_COST: u64 = 100;
    const EXPERT_DUNGEON_COST: u64 = 200;
    const MASTER_DUNGEON_COST: u64 = 300;
    const LEGENDARY_DUNGEON_COST: u64 = 400;

    public fun enter_dungeon(
        character: &mut Character,
        dungeon_level: u8,
        mut payment: Coin<OCW>,
        ctx: &mut TxContext
    ): Coin<OCW> {
        assert!(!character::is_injured(character), 1);

        let cost = get_dungeon_cost(dungeon_level);
        assert!(payment.value() >= cost, 2);

        if (cost > 0) 
            transfer::public_transfer(coin::split(&mut payment, cost, ctx), @0x0);

        payment
    }

    entry fun complete_dungeon(
        random: &Random,
        character: &mut Character,
        dungeon_level: u8,
        ctx: &mut TxContext
    ) {

        let mut gen = random.new_generator(ctx);
        
        let value = gen.generate_u64_in_range(0, 100);

        let success = is_dungeon_success(dungeon_level, value);

        //! important Check safety checks to ensure people cnanot replay successfully
        if (success) {
            let exp_gain = get_exp_gain(dungeon_level);
            let ocw_reward = get_ocw_reward(dungeon_level);
            character.level_up(exp_gain);

            character.add_ocw_rewards(ocw_reward);
        } else {
            let damage = get_dungeon_damage(dungeon_level, character);
            character.take_damage(damage);
        };
    }

    fun get_dungeon_cost(dungeon_level: u8): u64 {
        if (dungeon_level == 1) NOVICE_DUNGEON_COST
        else if (dungeon_level == 2) ADEPT_DUNGEON_COST
        else if (dungeon_level == 3) EXPERT_DUNGEON_COST
        else if (dungeon_level == 4) MASTER_DUNGEON_COST
        else LEGENDARY_DUNGEON_COST
    }

    fun is_dungeon_success(dungeon_level: u8, random_number: u64): bool {
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

    fun get_dungeon_damage(dungeon_level: u8, character: &Character): u64 {
        let max_hp = character.max_hp();
        if (dungeon_level == 2) max_hp * 30 / 100
        else if (dungeon_level == 3) max_hp * 50 / 100
        else if (dungeon_level == 4) max_hp * 60 / 100
        else max_hp * 80 / 100
    }
}
