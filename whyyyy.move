module FW::character {
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::random::{Self, Random};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::ascii::String;
    use sui::display::{Self, Display};
    use sui::vec_map::{Self, VecMap};
    use sui::package;
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

    const PALETTE: vector<vector<u8>> = vector[
        b"be4a2f", b"d77643", b"ead4aa", b"e4a672",
        b"b86f50", b"733e39", b"3e2731", b"a22633",
        b"e43b44", b"f77622", b"feae34", b"fee761",
        b"63c74d", b"3e8948", b"265c42", b"193c3e",
        b"124e89", b"0099db", b"2ce8f5", b"ffffff",
        b"c0cbdc", b"8b9bb4", b"5a6988", b"3a4466",
        b"262b44", b"181425", b"ff0044", b"68386c",
        b"b55088", b"f6757a", b"e8b796", b"c28569",
    ];    
    
    const BURN_ADDRESS: address = @0x0;

    // STRUCTS
    public struct Builder has key {
        id: UID,
        body: VecMap<String, vector<Rect>>,
        hair: VecMap<String, vector<Rect>>,
        colours: vector<vector<u8>>,
    }

    public struct Rect(u8, u8, u8, u8, String) has store, copy, drop;
    
    public struct Props has store, drop {
        body_type: String,
        hair_type: String,
        body: String,
        hair: String,
        hair_colour: String,
        eyes_colour: String,
        pants_colour: String,
        skin_colour: String,
        base_colour: String,
        accent_colour: String,
    }

    public struct CHARACTER has drop {}

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
        damage: u64,
        unclaimed_ocw: u64,
        last_raid_epoch: u64,
        last_raided_epoch: u64,
        last_reward_epoch: u64,
        image: Props,
        has_staff: bool,
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
        has_staff: bool,
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
    public entry fun create_and_share(
        b: &mut Builder,
        body_type: String,
        hair_type: String,
        eyes_colour: String,
        hair_colour: String,
        pants_colour: String,
        skin_colour: String,
        base_colour: String,
        accent_colour: String,
        ctx: &mut TxContext
    ) {
        let image = Props {
            body_type,
            hair_type,
            body: urlencode(&render_part(b.body[&body_type])),
            hair: urlencode(&render_part(b.hair[&hair_type])),
            hair_colour,
            eyes_colour,
            pants_colour,
            skin_colour,
            base_colour,
            accent_colour,
        };

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
            damage: 100,
            unclaimed_ocw: 0,
            last_raid_epoch: 0,
            last_raided_epoch: 0,
            last_reward_epoch: 0,
            image,
            has_staff: false,
        };

        transfer::transfer(character, tx_context::sender(ctx));
    }

    fun init(otw: CHARACTER, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        let mut display = display::new<Character>(&publisher, ctx);

        let mut builder = Builder {
            id: object::new(ctx),
            body: vec_map::empty(),
            hair: vec_map::empty(),
            colours: PALETTE,
        };

        set_initial_assets(&mut builder);
        set_display(&mut display);

        transfer::public_transfer(display, ctx.sender());
        transfer::public_transfer(publisher, ctx.sender());
        transfer::share_object(builder);
    }

    fun rect_to_svg_bytes(rect: Rect): vector<u8> {
        let Rect(x, y, w, h, class) = rect;
        let mut res = vector[];
        let data = vector[
            b"<rect x='", num_to_ascii(x), b"' y='", num_to_ascii(y), b"' width='", num_to_ascii(w), b"' height='", num_to_ascii(h), b"' class='", class.into_bytes(), b"'/>"
        ];

        let mut i = 0;
        while (i < data.length()) {
            res.append(data[i]);
            i = i + 1;
        };
        res
    }

    fun render_part(mut part: vector<Rect>): String {
        let mut res = vector[];
        while (part.length() > 0) {
            res.append(rect_to_svg_bytes(part.pop_back()));
        };
        res.to_ascii_string()
    }

    fun num_to_ascii(mut num: u8): vector<u8> {
        let mut res = vector[];
        if (num == 0) return vector[48];
        while (num > 0) {
            let digit = (num % 10) as u8;
            num = num / 10;
            res.insert(digit + 48, 0);
        };
        res
    }

    /// Set the initial assets for the character.
    fun set_initial_assets(builder: &mut Builder) {
        builder.hair.insert(b"punk".to_ascii_string(), vector[
            Rect(60, 10, 80, 20, b"h".to_ascii_string()),   // Top part of hair
            Rect(50, 20, 100, 20, b"h".to_ascii_string()),  // Bottom part of hair
        ]);

        builder.body.insert(b"blazer".to_ascii_string(), vector[
            Rect(60, 100, 80, 95, b"b".to_ascii_string()),  // Hoodie body
        ]);
    }

    /// Display setup
    fun set_display(d: &mut Display<Character>) {
        let mut image_url = b"data:image/svg+xml;charset=utf8,".to_string();
        image_url.append(build_character_base());
        d.add(b"image_url".to_string(), image_url);
        d.add(b"name".to_string(), b"FudWars!".to_string());
        d.add(b"description".to_string(), b"How much can you FUD?".to_string());
        d.add(b"wizard_staff_color".to_string(), b"{wizard_staff_color}".to_string());        
        d.update_version();
    }


    fun build_pure_svg(): String {
        let head = Rect(60, 20, 80, 80, b"s".to_ascii_string());
        let hair_top = Rect(60, 10, 80, 20, b"h".to_ascii_string());
        let hair_bottom = Rect(50, 20, 100, 20, b"h".to_ascii_string());
        let l_eye = Rect(75, 60, 10, 20, b"e".to_ascii_string());
        let r_eye = Rect(115, 60, 10, 20, b"e".to_ascii_string());
        let hoodie_body = Rect(60, 100, 80, 95, b"b".to_ascii_string());
        let l_arm = Rect(40, 100, 20, 80, b"b".to_ascii_string());
        let r_arm = Rect(140, 100, 20, 80, b"b".to_ascii_string());
        let l_leg = Rect(60, 195, 30, 45, b"l".to_ascii_string());
        let r_leg = Rect(110, 195, 30, 45, b"l".to_ascii_string());
        let l_shoe = Rect(60, 240, 30, 14, b"sh".to_ascii_string());
        let r_shoe = Rect(110, 240, 30, 14, b"sh".to_ascii_string());
        let staff_body = Rect(145, 150, 10, 100, b"staff".to_ascii_string());
        let staff_orb = Rect(130, 135, 30, 30, b"staff_orb".to_ascii_string());
        let haccent = Rect(80, 155, 40, 20, b"ha".to_ascii_string());  // Accent part
        let l_string = Rect(85, 150, 5, 20, b"st".to_ascii_string());  // Left string
        let r_string = Rect(110, 110, 5, 20, b"st".to_ascii_string()); // Right string
    
        let mut svg = vector[];
        svg.append(b"<svg xmlns='http://www.w3.org/2000/svg' viewBox='20 0 255 255'>");
        svg.append(b"<style>.s{fill:#SKIN; stroke:#000000; stroke-width:1.5} .e{fill:#EYES; stroke:#000000; stroke-width:1.5} .h{fill:#HAIR; stroke:#000000; stroke-width:1.5} .b{fill:#BODY; stroke:#000000; stroke-width:1.5} .l{fill:#PANTS; stroke:#000000; stroke-width:1.5} .sh{fill:#SHOES; stroke:#000000; stroke-width:1.5} .a{fill:#ACCENT; stroke:#000000; stroke-width:1.5} .ha{fill:#ACCENT; stroke:#000000; stroke-width:1.5} .st{fill:#000000; stroke:#000000; stroke-width:1.5}</style>");        
        svg.append(rect_to_svg_bytes(head));
        svg.append(rect_to_svg_bytes(hair_top));
        svg.append(rect_to_svg_bytes(hair_bottom));
        svg.append(rect_to_svg_bytes(l_eye));
        svg.append(rect_to_svg_bytes(r_eye));
        svg.append(rect_to_svg_bytes(hoodie_body));
        svg.append(rect_to_svg_bytes(l_arm));
        svg.append(rect_to_svg_bytes(r_arm));
        svg.append(rect_to_svg_bytes(l_leg));
        svg.append(rect_to_svg_bytes(r_leg));
        svg.append(rect_to_svg_bytes(l_shoe));
        svg.append(rect_to_svg_bytes(r_shoe));
        svg.append(rect_to_svg_bytes(staff_body));
        svg.append(rect_to_svg_bytes(staff_orb));
        svg.append(rect_to_svg_bytes(haccent));
        svg.append(rect_to_svg_bytes(l_string));
        svg.append(rect_to_svg_bytes(r_string));
        svg.append(b"TEMPLATE");
        svg.append(b"</svg>");
        svg.to_ascii_string()
    }
    
    
    fun build_character_base(): string::String {
        let template = urlencode(&build_pure_svg()).to_string();

        let template = replace(template, b"HAIR".to_string(), b"{image.hair_colour}".to_string());
        let template = replace(template, b"EYES".to_string(), b"{image.eyes_colour}".to_string());
        let template = replace(template, b"PANTS".to_string(), b"{image.pants_colour}".to_string());
        let template = replace(template, b"SKIN".to_string(), b"{image.skin_colour}".to_string());
        let template = replace(template, b"BODY".to_string(), b"{image.base_colour}".to_string());
        let template = replace(template, b"ACCENT".to_string(), b"{image.accent_colour}".to_string());

        let template = replace(template, b"TEMPLATE".to_string(), b"{image.hair}{image.body}".to_string());

        template
    }

    public fun urlencode(s: &String): String {
        let mut res = vector[];
        let mut i = 0;
        while (i < s.length()) {
            let c = s.as_bytes()[i];
            if (c == 32) { // whitespace " "
                res.append(b"%20")
            } else if ((c < 48 || c > 57) && (c < 65 || c > 90) && (c < 97 || c > 122)) {
                res.push_back(37);
                res.push_back((c / 16) + if (c / 16 < 10) 48 else 55);
                res.push_back((c % 16) + if (c % 16 < 10) 48 else 55);
            } else {
                res.push_back(c);
            };
            i = i + 1;
        };
        res.to_ascii_string()
    }
  

	// Function for entering level 1 dungeon (free)
	public entry fun enter_dungeon_level_1(
	    character: &mut Character,
	    clock: &Clock,
	) {
	    let current_time = clock::timestamp_ms(clock);
	    assert!(!character.locked, ERR_CHARACTER_LOCKED);
	    assert!(current_time >= character.last_dungeon_entry + get_dungeon_duration(character.current_dungeon), ERR_DUNGEON_TIME_NOT_ELAPSED);
	    assert!(!character.is_injured, ERR_CHARACTER_INJURED);
	    assert!(character.current_hp == character.max_hp, ERR_CHARACTER_INJURED);

	    character.locked = true;
	    character.last_dungeon_entry = current_time;
	    character.current_dungeon = 1;

	    emit_character_info(character);
	}

	// Function for entering dungeons level 2-5 (requires payment)
	public entry fun enter_dungeon(
	    character: &mut Character,
	    dungeon_level: u8,
	    clock: &Clock,
	    payment: &mut Coin<OCW>,
	    ctx: &mut TxContext
	) {
	    let current_time = clock::timestamp_ms(clock);
	    assert!(!character.locked, ERR_CHARACTER_LOCKED);
	    assert!(dungeon_level >= 2 && dungeon_level <= 5, ERR_INVALID_DUNGEON_LEVEL);
	    assert!(current_time >= character.last_dungeon_entry + get_dungeon_duration(character.current_dungeon), ERR_DUNGEON_TIME_NOT_ELAPSED);
	    assert!(!character.is_injured, ERR_CHARACTER_INJURED);
	    assert!(character.current_hp == character.max_hp, ERR_CHARACTER_INJURED);

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
		
		// Check for staff acquisition
		let staff_drop_chance = random::generate_u64_in_range(&mut gen, 1, 100);
		if (staff_drop_chance <= 20 && !character.has_staff) { // 20% chance to get a staff
		    character.has_staff = true;
		    character.damage = character.damage + random::generate_u64_in_range(&mut gen, 10, 100);
		    character.image.base_colour = std::ascii::string(b"FF0000"); //changing the base color to red to reflect that a change took place
		}
	    } else {
		take_damage(character, hp_lost);
	    };
	    
	    character.locked = false;
	    character.current_dungeon = 0;
	    
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
        let healing_cost = (missing_hp as u64) * 1_000_000_000 / 100; // 1 OCW per 1% of missing HP
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
    
    
    
    public struct WrappedTreasuryCap has key {
        id: UID,
        cap: TreasuryCap<OCW>
    }

    public entry fun create_wrapped_treasury_cap(
        treasury_cap: TreasuryCap<OCW>, 
        ctx: &mut TxContext
    ) {
        let wrapped_cap = WrappedTreasuryCap {
            id: object::new(ctx),
            cap: treasury_cap
        };
        transfer::share_object(wrapped_cap);
    }    
    
    
    
	public entry fun claim_ocw_rewards(
	    wrapped_cap: &mut WrappedTreasuryCap,
	    character: &mut Character,
	    ctx: &mut TxContext
	) {
	    let current_epoch = tx_context::epoch(ctx);
	    
	    // Check if we're in a new epoch compared to when rewards were last earned
	    if (current_epoch > character.last_reward_epoch) {
		// Calculate the total claimable amount
		let claimable_amount = character.ocw_balance + character.unclaimed_ocw;
		
		// Reset the balances
		character.ocw_balance = 0;
		character.unclaimed_ocw = 0;
		
		// Update the last claimed epoch
		character.last_reward_epoch = current_epoch;

		// Mint new OCW coins using the wrapped treasury cap and transfer to the recipient
		if (claimable_amount > 0) {
		    mint_wrapped(wrapped_cap, claimable_amount, tx_context::sender(ctx), ctx);
		};
	    };

	    emit_character_info(character);
	}

    fun mint_wrapped(
            wrapped_cap: &mut WrappedTreasuryCap, 
            amount: u64, 
            recipient: address, 
            ctx: &mut TxContext
        ) {
            let coin = coin::mint(&mut wrapped_cap.cap, amount, ctx);
            transfer::public_transfer(coin, recipient);
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

	fun get_dungeon_entry_cost(dungeon_level: u8): u64 {
	    if (dungeon_level == 1) { 0 }
	    else if (dungeon_level == 2) { 100_000_000_000 } // 100 OCW
	    else if (dungeon_level == 3) { 200_000_000_000 } // 200 OCW
	    else if (dungeon_level == 4) { 300_000_000_000 } // 300 OCW
	    else if (dungeon_level == 5) { 400_000_000_000 } // 400 OCW
	    else { 0 }
	}

	fun get_ocw_reward(dungeon_level: u8): u64 {
	    if (dungeon_level == 1) { 50_000_000_000 }  // 50 OCW
	    else if (dungeon_level == 2) { 200_000_000_000 } // 200 OCW
	    else if (dungeon_level == 3) { 400_000_000_000 } // 400 OCW
	    else if (dungeon_level == 4) { 600_000_000_000 } // 600 OCW
	    else if (dungeon_level == 5) { 800_000_000_000 } // 800 OCW
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
    
    use std::string;

    fun replace(str: string::String, from: string::String, to: string::String): string::String {
        let pos = str.index_of(&from);
        let str = {
            let mut lhs = str.substring(0, pos);
            let rhs = str.substring(pos + from.length(), str.length());
            lhs.append(to);
            lhs.append(rhs);
            lhs
        };
        str
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
            has_staff: character.has_staff,
        });
    }
}
