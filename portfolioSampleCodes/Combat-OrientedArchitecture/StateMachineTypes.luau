--!strict
-- @Big_Honor | sirlael 

export type StateName = string
export type DomainName = "Locomotion" | "Combat" | "Control" | "Life"

export type StateDomain = {
	[StateName]: boolean,
}

export type StatesConfig = {
	[DomainName]: {
		States: StateDomain,
		Initial: string,
	},
}

export type StateMachine = {
	_currentStates: {[DomainName]: StateName},
	_domains: StatesConfig,

	SetState: (self: StateMachine, domain: DomainName, newState: StateName) -> boolean,
	GetState: (self: StateMachine, domain: DomainName) -> StateName?,
	Is: (self: StateMachine, domain: DomainName, state: StateName) -> boolean,
	StateChanged: (self: EntityState, domain: DomainName) -> RBXScriptSignal,
}

export type EntityState =  {
	_stateMachine: StateMachine,

	TrySetState: (self: EntityState, domain: DomainName, newState: StateName) -> boolean,
	GetState: (self: EntityState, domain: DomainName) -> StateName?,
	Is: (self: EntityState, domain: DomainName, state: StateName) -> boolean,

	GetAllStates: (self: EntityState) -> {[DomainName]: StateName},
	
	StateChanged: (self: EntityState, domain: DomainName) -> RBXScriptSignal,
}

return nil
