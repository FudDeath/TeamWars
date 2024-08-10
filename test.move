module FW::character {
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::random::{Self, Random};
    use sui::coin::{Self, Coin, TreasuryCap};
    use FW::ocw::OCW;

    // CONSTANTS
    const NOVICE_DUNGEON_DURATION: u64 = 10000; // 10 seconds for testing (originally 1 hour)
    const ADEPT_DUNGEON_DURATION: u64 = 20000; // 20 seconds for testing (originally 2 hours)
    const EXPERT_DUNGEON_DURATION: u64 = 30000; // 30 seconds for testing (originally 3 hours)
    const MASTER_DUNGEON_DURATION: u64 = 40000; // 40 seconds for testing (originally 4 hours)
    const LEGENDARY_DUNGEON_DURATION: u64 = 60000; // 60 seconds for testing (originally 6 hours)

    const ERR_CHARACTER_LOCKED: u64 = 0;
    const ERR_DUNGEON_TIME_NOT_ELAPSED: u64 = 1;
    const ERR_INVALID_DUNGEON_LEVEL: u64 = 2;
    const ERR_NOT_IN_DUNGEON: u64 = 3;
    const ERR_ALREADY_RAIDED_TODAY: u64 = 6;
    const ERR_ALREADY_RAIDED_SOMEONE_TODAY: u64 = 7;
    const ERR_CANNOT_RAID_SELF: u64 = 8;
    const ERR_CHARACTER_INJURED: u64 = 4;
    const ERR_INSUFFICIENT_OCW: u64 = 5;

    const BURN_ADDRESS: address = @0x0;

    // STRUCTS
    public struct Character has key, store {
        id: UID,
        level: u64,
        exp: u64,
        locked: bool,
        last_dungeon_entry: u64,
        current_dungeon: u8,
        max_hp: u64,
        current_hp: u64,
        is_injured: bool,
        ocw_balance: u64,
        damage: u64,  // New field for character damage
        unclaimed_ocw: u64,
        last_raid_epoch: u64,
        last_raided_epoch: u64,
        last_reward_epoch: u64,
    }

    public struct CharacterInfo has copy, drop {
        level: u64,
        exp: u64,
        locked: bool,
        last_dungeon_entry: u64,
        current_dungeon: u8,
        max_hp: u64,
        current_hp: u64,
        is_injured: bool,
        ocw_balance: u64,
        damage: u64,
        unclaimed_ocw: u64,
        last_raid_epoch: u64,
        last_raided_epoch: u64,
        last_reward_epoch: u64,
    }

    public struct RaidResult has copy, drop {
        attacker: address,
        defender: address,
        success: bool,
        ocw_stolen: u64,
        attacker_damage: u64,
        attack_roll: u64,
    }

    public struct DungeonResult has copy, drop {
        success: bool,
        exp_gained: u64,
        ocw_earned: u64,
        hp_lost: u64,
    }

    // FUNCTIONS
    public entry fun create_and_share(ctx: &mut TxContext) {
        let character = Character {
            id: object::new(ctx),
            level: 1,
            exp: 0,
            locked: false,
            last_dungeon_entry: 0,
            current_dungeon: 0,
            max_hp: 100,
            current_hp: 100,
            is_injured: false,
            ocw_balance: 0,
            damage: 100,  // Initial damage
            unclaimed_ocw: 0,
            last_raid_epoch: 0,
            last_raided_epoch: 0,
            last_reward_epoch: 0,  // Initialize the new field
        };
        transfer::share_object(character);
    }

    public entry fun enter_dungeon(
        character: &mut Character,
        dungeon_level: u8,
        clock: &Clock,
        payment: &mut Coin<OCW>,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(!character.locked, ERR_CHARACTER_LOCKED);
        assert!(dungeon_level >= 1 && dungeon_level <= 5, ERR_INVALID_DUNGEON_LEVEL);
        assert!(current_time >= character.last_dungeon_entry + get_dungeon_duration(character.current_dungeon), ERR_DUNGEON_TIME_NOT_ELAPSED);
        assert!(!character.is_injured, ERR_CHARACTER_INJURED);  // This line ensures the character is not injured
        assert!(character.current_hp == character.max_hp, ERR_CHARACTER_INJURED);  // This additional check ensures full HP

        let entry_cost = get_dungeon_entry_cost(dungeon_level);
        assert!(coin::value(payment) >= entry_cost, ERR_INSUFFICIENT_OCW);

        if (entry_cost > 0) {
            let paid = coin::split(payment, entry_cost, ctx);
            transfer::public_transfer(paid, BURN_ADDRESS);
        };

        character.locked = true;
        character.last_dungeon_entry = current_time;
        character.current_dungeon = dungeon_level;

        emit_character_info(character);
    }

    entry fun complete_dungeon(
        random: &Random,
        character: &mut Character,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(character.locked, ERR_NOT_IN_DUNGEON);
        assert!(current_time >= character.last_dungeon_entry + get_dungeon_duration(character.current_dungeon), ERR_DUNGEON_TIME_NOT_ELAPSED);
        
        let mut gen = random::new_generator(random, ctx);
        
        let value = random::generate_u64_in_range(&mut gen, 0, 100);
        let success = is_dungeon_success(character.current_dungeon, value);
        let exp_gained = if (success) { get_exp_gain(character.current_dungeon) } else { 0 };
        let ocw_earned = if (success) { get_ocw_reward(character.current_dungeon) } else { 0 };
        let hp_lost = if (!success) { calculate_injury(character.current_dungeon, character.max_hp) } else { 0 };

        if (success) {
            level_up(character, exp_gained);
            character.unclaimed_ocw = character.unclaimed_ocw + ocw_earned;
        } else {
            take_damage(character, hp_lost);
        };
        
        character.locked = false;
        character.current_dungeon = 0;
        
        // Set is_injured flag if character's HP is not full
        character.is_injured = character.current_hp < character.max_hp;
        
        event::emit(DungeonResult {
            success,
            exp_gained,
            ocw_earned,
            hp_lost,
        });
        
        emit_character_info(character);
    }

    public entry fun heal_character(character: &mut Character, payment: &mut Coin<OCW>, ctx: &mut TxContext) {
        let missing_hp = character.max_hp - character.current_hp;
        let healing_cost = missing_hp * 1; // 1 OCW per 1% of missing HP
        assert!(coin::value(payment) >= healing_cost, ERR_INSUFFICIENT_OCW);

        if (healing_cost > 0) {
            let paid = coin::split(payment, healing_cost, ctx);
            transfer::public_transfer(paid, BURN_ADDRESS);
        };

        heal(character, missing_hp);
    }

    fun heal(character: &mut Character, amount: u64) {
        character.current_hp = character.current_hp + amount;
        if (character.current_hp > character.max_hp) {
            character.current_hp = character.max_hp;
        };
        let is_injured = character.current_hp < character.max_hp;
        character.is_injured = is_injured;
    }
   
    public entry fun claim_ocw_rewards(character: &mut Character, ctx: &mut TxContext) {
        let current_epoch = tx_context::epoch(ctx);
        
        // Check if we're in a new epoch compared to when rewards were last earned
        if (current_epoch > character.last_reward_epoch) {
            // Transfer unclaimed rewards to the claimable balance
            character.ocw_balance = character.ocw_balance + character.unclaimed_ocw;
            character.unclaimed_ocw = 0;
            
            // Update the last claimed epoch
            character.last_reward_epoch = current_epoch;
        };

        emit_character_info(character);
    }

    entry fun raid(
        attacker: &mut Character,
        defender: &mut Character,
        random: &Random,
        ctx: &mut TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        
        // Check if attacker has already raided in this epoch
        assert!(current_epoch > attacker.last_raid_epoch, ERR_ALREADY_RAIDED_SOMEONE_TODAY);
        
        // Check if defender has already been raided in this epoch
        assert!(current_epoch > defender.last_raided_epoch, ERR_ALREADY_RAIDED_TODAY);
        
        // Ensure attacker is not raiding themselves
        assert!(object::id(attacker) != object::id(defender), ERR_CANNOT_RAID_SELF);

        let mut gen = random::new_generator(random, ctx);
        let attack_roll = random::generate_u64_in_range(&mut gen, 1, 100);
        let success = attack_roll <= 50; // 50% chance of success

        let mut ocw_stolen = 0;
        let mut attacker_damage = 0;

        if (success) {
            ocw_stolen = defender.unclaimed_ocw * 30 / 100; // 30% of defender's unclaimed OCW
            defender.unclaimed_ocw = defender.unclaimed_ocw - ocw_stolen;
            attacker.unclaimed_ocw = attacker.unclaimed_ocw + ocw_stolen;
        } else {
            attacker_damage = attacker.max_hp * 50 / 100; // 50% of attacker's max HP
            take_damage(attacker, attacker_damage);
        };

        attacker.last_raid_epoch = current_epoch;
        defender.last_raided_epoch = current_epoch;

        event::emit(RaidResult {
            attacker: tx_context::sender(ctx),
            defender: object::id_address(defender),
            success,
            ocw_stolen,
            attacker_damage,
            attack_roll,
        });

        emit_character_info(attacker);
        emit_character_info(defender);
    }

    public entry fun withdraw_ocw(
        treasury_cap: &mut TreasuryCap<OCW>,
        character: &mut Character,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(character.ocw_balance >= amount, ERR_INSUFFICIENT_OCW);
        character.ocw_balance = character.ocw_balance - amount;

        // Mint new OCW coins from the treasury and transfer to the recipient
        FW::ocw::mint(treasury_cap, amount, tx_context::sender(ctx), ctx);
    }

    // HELPER FUNCTIONS
    fun get_dungeon_duration(dungeon_level: u8): u64 {
        if (dungeon_level == 1) { NOVICE_DUNGEON_DURATION }
        else if (dungeon_level == 2) { ADEPT_DUNGEON_DURATION }
        else if (dungeon_level == 3) { EXPERT_DUNGEON_DURATION }
        else if (dungeon_level == 4) { MASTER_DUNGEON_DURATION }
        else if (dungeon_level == 5) { LEGENDARY_DUNGEON_DURATION }
        else { 0 }
    }

    fun is_dungeon_success(dungeon_level: u8, random_value: u64): bool {
        let base_rate = if (dungeon_level == 1) { 100 }
        else if (dungeon_level == 2) { 70 }
        else if (dungeon_level == 3) { 50 }
        else if (dungeon_level == 4) { 30 }
        else if (dungeon_level == 5) { 20 }
        else { 0 };

        random_value < base_rate
    }

    fun get_exp_gain(dungeon_level: u8): u64 {
        if (dungeon_level == 1) { 150 }
        else if (dungeon_level == 2) { 250 }
        else if (dungeon_level == 3) { 500 }
        else if (dungeon_level == 4) { 1000 }
        else if (dungeon_level == 5) { 3000 }
        else { 0 }
    }

    fun get_ocw_reward(dungeon_level: u8): u64 {
        if (dungeon_level == 1) { 50 }
        else if (dungeon_level == 2) { 200 }
        else if (dungeon_level == 3) { 400 }
        else if (dungeon_level == 4) { 600 }
        else if (dungeon_level == 5) { 800 }
        else { 0 }
    }

    fun calculate_injury(dungeon_level: u8, max_hp: u64): u64 {
        if (dungeon_level == 2) { max_hp * 30 / 100 }
        else if (dungeon_level == 3) { max_hp * 50 / 100 }
        else if (dungeon_level == 4) { max_hp * 60 / 100 }
        else if (dungeon_level == 5) { max_hp * 80 / 100 }
        else { 0 }
    }

    fun take_damage(character: &mut Character, damage: u64) {
        if (damage >= character.current_hp) {
            character.current_hp = 0;
        } else {
            character.current_hp = character.current_hp - damage;
        };
        character.is_injured = character.current_hp < character.max_hp;
    }

    fun get_dungeon_entry_cost(dungeon_level: u8): u64 {
        if (dungeon_level == 1) { 0 }
        else if (dungeon_level == 2) { 100 }
        else if (dungeon_level == 3) { 200 }
        else if (dungeon_level == 4) { 300 }
        else if (dungeon_level == 5) { 400 }
        else { 0 }
    }

    fun level_up(character: &mut Character, exp_gain: u64) {
        character.exp = character.exp + exp_gain;
        while (character.exp >= 1000 * character.level) {
            character.level = character.level + 1;
            character.max_hp = character.max_hp + 20;
            character.current_hp = character.max_hp;
            character.damage = character.damage + 10;
        }
    }

    // GETTER FUNCTIONS
    public fun get_character_info(character: &Character) {
        emit_character_info(character);
    }

    public fun ocw_balance(character: &Character): u64 {
        character.ocw_balance
    }

    fun emit_character_info(character: &Character) {
        event::emit(CharacterInfo {
            level: character.level,
            exp: character.exp,
            locked: character.locked,
            last_dungeon_entry: character.last_dungeon_entry,
            current_dungeon: character.current_dungeon,
            max_hp: character.max_hp,
            current_hp: character.current_hp,
            is_injured: character.is_injured,
            ocw_balance: character.ocw_balance,
            damage: character.damage,
            unclaimed_ocw: character.unclaimed_ocw,
            last_raid_epoch: character.last_raid_epoch,
            last_raided_epoch: character.last_raided_epoch,
            last_reward_epoch: character.last_reward_epoch,
        });
    }
}
