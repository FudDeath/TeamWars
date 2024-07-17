module game::character {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::TxContext;

    struct Character has key, store {
        id: UID,
        level: u64,
        exp: u64,
        max_hp: u64,
        current_hp: u64,
        is_injured: bool,
    }

    public fun new(ctx: &mut TxContext): Character {
        Character {
            id: object::new(ctx),
            level: 1,
            exp: 0,
            max_hp: 100,
            current_hp: 100,
            is_injured: false,
        }
    }

    public fun level_up(self: &mut Character, exp_gain: u64) {
        self.exp = self.exp + exp_gain;
        if (self.exp >= self.level * 100) {
            self.level = self.level + 1;
            self.max_hp = self.max_hp + 20;
            self.current_hp = self.max_hp;
        }
    }

    public fun is_injured(self: &Character): bool {
        self.is_injured
    }

    public fun set_injured(self: &mut Character, injured: bool) {
        self.is_injured = injured;
    }

    public fun heal(self: &mut Character, amount: u64) {
        self.current_hp = self.current_hp + amount;
        if (self.current_hp > self.max_hp) {
            self.current_hp = self.max_hp;
        }
        if (self.current_hp == self.max_hp) {
            self.is_injured = false;
        }
    }

    public fun take_damage(self: &mut Character, damage: u64) {
        if (damage >= self.current_hp) {
            self.current_hp = 0;
            self.is_injured = true;
        } else {
            self.current_hp = self.current_hp - damage;
        }
    }

    public fun transfer_character(character: Character, recipient: address) {
        transfer::public_transfer(character, recipient);
    }
}
