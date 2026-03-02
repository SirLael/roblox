return {
	Locomotion = {
		Initial = "Idle",
		States = {
			Idle = true,
			Moving = true,
			Airborne = true,
			Dashing = true,
		}
	};

	Combat = {
		Initial = "Neutral",
		States = {
			Neutral = true,
			Attacking = true,
			Ragdolled = true,
			UsingUniqueAbility = true,
		}
	},

	Control = {
		Initial = "Normal",
		States = {
			Normal = true,
			Stunned = true,
			InputLocked = true,
		}
	},

	Life = {
		Initial = "Alive",
		States = {
			Alive = true,
			Dead = true,
		}
	}
}
