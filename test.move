module clan_wars::game {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option};
    use std::vector;
    use 0x0::ocw_token::{Self, OCW_TOKEN};

    // Error codes
    const EInsufficientFunds: u64 = 0;
    const ECharacterInjured: u64 = 1;
    const ECharacterBusy: u64 = 2;

    // Game constants
    const XP_PER_LEVEL: u64 = 500;

    // Character struct
    public struct Character has key, store {
        id: UID,
        level: u64,
        xp: u64,
        max_hp: u64,
        current_hp: u64,
        base_damage: u64,
        is_injured: bool,
        ocw_balance: Balance<OCW_TOKEN>,
        equipped_skills: vector<Option<Skill>>,
        busy_until: u64,
    }

    // Skill struct
    public struct Skill has key, store {
        id: UID,
        rarity: u8,
        uses_left: u64,
        damage_boost: u64,
    }

    // Dungeon struct
    public struct Dungeon has key {
        id: UID,
        level: u64,
        completion_time: u64,
        success_rate: u64,
        xp_gain: u64,
        skill_drop_rate: u64,
        ocw_reward: u64,
        entry_cost: u64,
    }

    fun init(ctx: &mut TxContext) {
        create_dungeon(1, 3600000, 100, 150, 10, 50, 0, ctx);
        create_dungeon(2, 7200000, 70, 250, 30, 200, 100, ctx);
        create_dungeon(3, 10800000, 50, 500, 50, 400, 200, ctx);
        create_dungeon(4, 14400000, 30, 1000, 70, 600, 300, ctx);
        create_dungeon(5, 21600000, 20, 3000, 90, 800, 400, ctx);
    }

    fun create_dungeon(
        level: u64,
        completion_time: u64,
        success_rate: u64,
        xp_gain: u64,
        skill_drop_rate: u64,
        ocw_reward: u64,
        entry_cost: u64,
        ctx: &mut TxContext
    ) {
        let dungeon = Dungeon {
            id: object::new(ctx),
            level,
            completion_time,
            success_rate,
            xp_gain,
            skill_drop_rate,
            ocw_reward,
            entry_cost,
        };
        transfer::share_object(dungeon);
    }

    public entry fun create_character(ctx: &mut TxContext) {
        let character = Character {
            id: object::new(ctx),
            level: 1,
            xp: 0,
            max_hp: 100,
            current_hp: 100,
            base_damage: 10,
            is_injured: false,
            ocw_balance: balance::zero(),
            equipped_skills: vector::empty(),
            busy_until: 0,
        };
        transfer::transfer(character, tx_context::sender(ctx));
    }

	public entry fun enter_dungeon(
	    character: &mut Character,
	    dungeon: &Dungeon,
	    payment: &mut Coin<OCW_TOKEN>,
	    treasury_cap: &mut TreasuryCap<OCW_TOKEN>,
	    clock: &Clock,
	    ctx: &mut TxContext
	) {
	    assert!(!character.is_injured, ECharacterInjured);
	    assert!(character.busy_until <= clock::timestamp_ms(clock), ECharacterBusy);
	    assert!(coin::value(payment) >= dungeon.entry_cost, EInsufficientFunds);

	    // Pay entry fee
	    let entry_fee = coin::split(payment, dungeon.entry_cost, ctx);
	    coin::burn(treasury_cap, entry_fee);

	    // Set character as busy
	    character.busy_until = clock::timestamp_ms(clock) + dungeon.completion_time;

	    // Determine dungeon outcome
	    if (pseudo_random(ctx) <= dungeon.success_rate) {
		// Success
		character.xp = character.xp + dungeon.xp_gain;
		
		// Add OCW reward
		let reward_coin = coin::mint(treasury_cap, dungeon.ocw_reward, ctx);
		balance::join(&mut character.ocw_balance, coin::into_balance(reward_coin));
		
		// Possibly drop a skill
		if (pseudo_random(ctx) <= dungeon.skill_drop_rate) {
		    let skill = create_random_skill(ctx);
		    if (vector::length(&character.equipped_skills) < 4) {
		        vector::push_back(&mut character.equipped_skills, option::some(skill));
		    } else {
		        transfer::public_transfer(skill, tx_context::sender(ctx));
		    }
		};

		// Level up if enough XP
		let levels_gained = character.xp / XP_PER_LEVEL;
		if (levels_gained > 0) {
		    character.xp = character.xp % XP_PER_LEVEL;
		    character.level = character.level + levels_gained;
		    character.max_hp = character.max_hp + (10 * levels_gained);
		    character.base_damage = character.base_damage + (10 * levels_gained);
		};
	    } else {
		// Failure
		character.is_injured = true;
		character.current_hp = character.current_hp - ((character.max_hp as u64) * dungeon.level / 10);
	    };
	}

    public entry fun heal_character(
        character: &mut Character,
        payment: &mut Coin<OCW_TOKEN>,
        treasury_cap: &mut TreasuryCap<OCW_TOKEN>,
        ctx: &mut TxContext
    ) {
        let healing_cost = (character.max_hp - character.current_hp) as u64;
        assert!(coin::value(payment) >= healing_cost, EInsufficientFunds);

        let healing_payment = coin::split(payment, healing_cost, ctx);
        coin::burn(treasury_cap, healing_payment);

        character.current_hp = character.max_hp;
        character.is_injured = false;
    }

    fun create_random_skill(ctx: &mut TxContext): Skill {
        let rarity = (pseudo_random(ctx) % 100) + 1;
        let (rarity, uses, damage) = if (rarity <= 60) {
            (1, 25, 20)
        } else if (rarity <= 85) {
            (2, 20, 30)
        } else if (rarity <= 95) {
            (3, 15, 50)
        } else if (rarity <= 99) {
            (4, 10, 75)
        } else {
            (5, 5, 100)
        };

        Skill {
            id: object::new(ctx),
            rarity,
            uses_left: uses,
            damage_boost: damage,
        }
    }

    fun pseudo_random(_ctx: &mut TxContext): u64 {
        // This is a placeholder. In a real implementation, use a proper source of randomness
        123
    }

    // Public view functions

    public fun get_character_level(character: &Character): u64 {
        character.level
    }

    public fun get_character_xp(character: &Character): u64 {
        character.xp
    }

    public fun get_character_hp(character: &Character): (u64, u64) {
        (character.current_hp, character.max_hp)
    }

    public fun get_character_damage(character: &Character): u64 {
        character.base_damage
    }

    public fun is_character_injured(character: &Character): bool {
        character.is_injured
    }

    public fun get_character_ocw_balance(character: &Character): u64 {
        balance::value(&character.ocw_balance)
    }

    public entry fun claim_character_rewards(
        character: &mut Character,
        treasury_cap: &mut TreasuryCap<OCW_TOKEN>,
        ctx: &mut TxContext
    ) {
        let amount = balance::value(&character.ocw_balance);
        let reward_balance = balance::split(&mut character.ocw_balance, amount);
        let reward_coin = coin::from_balance(reward_balance, ctx);
        transfer::public_transfer(reward_coin, tx_context::sender(ctx));
    }
}

// OCW Token Module
module 0x0::ocw_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::option;

    /// One-time witness type with no fields or a single boolean field
    public struct OCW_TOKEN has drop {}

    fun init(witness: OCW_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"OCW",
            b"On-Chain Clan Wars Token",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<OCW_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    public entry fun burn(treasury_cap: &mut TreasuryCap<OCW_TOKEN>, coin: Coin<OCW_TOKEN>) {
        coin::burn(treasury_cap, coin);
    }
}
