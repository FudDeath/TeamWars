module ocw::character {
    // === Structs ===

    use sui::bag::{Self, Bag};

    public struct OCWRewardsKey has copy, drop, store {}

    public struct Character has key, store {
        id: UID,
        level: u64,
        exp: u64,
        max_hp: u64,
        current_hp: u64,
        is_injured: bool,
        bag: Bag
    }

    // === Mutative Functions ===

    public fun new(ctx: &mut TxContext): Character {
        Character {
            id: object::new(ctx),
            level: 1,
            exp: 0,
            max_hp: 100,
            current_hp: 100,
            is_injured: false,
            bag: bag::new(ctx)
        }
    }

    // === View Functions ===

    public fun addy(self: &Character): address {
        self.id.to_address()
    }

    public fun level(self: &Character): u64 {
        self.level
    }

    public fun exp(self: &Character): u64 {
        self.exp
    }

    public fun max_hp(self: &Character): u64 {
        self.max_hp
    }

    public fun current_hp(self: &Character): u64 {
        self.current_hp
    }

    public fun is_injured(self: &Character): bool {
        self.is_injured
    }

    public fun healing_cost(_self: &Character): u64 {
        // TODO logic?!

        10
    }

    public fun ocw_rewards(self: &Character): u64 {
        if (!self.bag.contains(OCWRewardsKey {})) return 0;

        *self.bag.borrow(OCWRewardsKey {})
    }

    // === Package-only Functions ===

    public(package) fun set_injured(self: &mut Character, injured: bool) {
        self.is_injured = injured;
    }

    public(package) fun level_up(self: &mut Character, exp_gain: u64) {
        self.exp = self.exp + exp_gain;
        if (self.exp >= self.level * 100) {
            self.level = self.level + 1;
            self.max_hp = self.max_hp + 20;
            self.current_hp = self.max_hp;
        }
    }

    public(package) fun take_damage(self: &mut Character, damage: u64) {
        if (damage >= self.current_hp) {
            self.current_hp = 0;
            self.is_injured = true;
        } else {
            self.current_hp = self.current_hp - damage;
        }
    }

    public(package) fun heal(self: &mut Character, amount: u64) {
        self.current_hp = self.current_hp + amount;
        if (self.current_hp > self.max_hp) {
            self.current_hp = self.max_hp;
        };

        if (self.current_hp == self.max_hp) {
            self.is_injured = false;
        }
    }

    public(package) fun add_ocw_rewards(self: &mut Character, amount: u64): u64 {
        if (!self.bag.contains(OCWRewardsKey {}))
            self.bag.add(OCWRewardsKey {}, 0);
        
        let v = self.bag.borrow_mut<OCWRewardsKey, u64>(OCWRewardsKey {});
        *v = *v + amount;

        *v
    }
}
