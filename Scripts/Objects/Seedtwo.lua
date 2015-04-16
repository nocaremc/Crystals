include("Scripts/Core/Common.lua")
include("Scripts/Objects/GrowableDataTwo.lua")
--include("Scripts/Objects/Consumable.lua")

local PHYSICS = Eternus.PhysicsWorld
local OUTPUT = Eternus.Output



-------------------------------------------------------------------------------
if (Seed == nil) then
	Seed = Consumable.Subclass("Seed")

	Seed.m_currentCheckTimer = 0.0
	Seed.m_checkFrequency = 10.0
	
	Seed.m_nextFormName = ""
	Seed.m_nextFormObject = nil
	Seed.m_growableMaterialName = ""
	Seed.m_bodyToCheck = "none"
	Seed.m_minGrowthTime = 0
	Seed.m_maxGrowthTime = 2400
	Seed.m_isInWorld = false
	Seed.m_clearanceRadius = 1.0
	Seed.m_debugOutput = false

	Seed.DefaultConsumeSound   = "SeedlingEating"
	
	Seed.m_tempTimer = 0.0
	Seed.m_growthData = nil
	
	Seed.m_swingAnimationName = "Consume"
	Seed.m_showVoxelSelectionBox = false
end
 
Seed.m_leftoverDropped = "none"
Seed.DefaultConsumeSound   = "SeedlingEating"

Seed.ThreeDSoundOffset = vec3.new(0, 0, 0)
--[[
	Events
]]--

NKRegisterEvent("Play3DSound",
	{ 
		sound = "string" 
	}
)
 
-------------------------------------------------------------------------------
function Seed:Constructor(args)
	local outString = "Setting up Seed script...\n"
	local printError = false
	
	if (args.nextFormName ~= nil) then
		self.m_nextFormName = args.nextFormName
	else
		outString = outString .. "Error: No name specified for next form of seeds.\n"
		printError = true
	end
	
	self.m_growthData = GrowableData.new(args)
	
	if (args.enableDebugOutput ~= nil) then
		if (args.enableDebugOutput == 1) then
			self.m_debugOutput = true
		end
	end

	--------------------------------------------------------------------------
	-- Edible Seeds
	
	self.m_staminaModifier 	= 0
	self.m_energyModifier 	= 0
	self.m_healthModifier 	= 0
	self.m_edible = false

	if args.healthModifier then
		self.m_healthModifier  = args.healthModifier
	end

	if args.energyModifier then
		self.m_energyModifier  = args.energyModifier
	end

	if args.staminaModifier then
		self.m_staminaModifier  = args.staminaModifier
	end
	
	if (self.m_staminaModifier ~= 0 or self.m_energyModifier ~= 0 or self.m_healthModifier ~= 0) then
		self.m_edible = true
	end
	
	if args.consumeSound ~= nil then
		self.m_consumeSound = args.consumeSound
	else
		self.m_consumeSound = Seed.DefaultConsumeSound
	end
	
	if printError then
		self:out(outString)
	end
end

-------------------------------------------------------------------------------
function Seed:PostLoad()
	Seed.__super.PostLoad(self)
end

-------------------------------------------------------------------------------
function Seed:Spawn()
	
	
end

-------------------------------------------------------------------------------
function Seed:Despawn()
	self.m_isInWorld = false
end


-------------------------------------------------------------------------------
-- Returns the name of the animation to be played on swing for this seed.  If
-- the seed is not edible, nil is returned.
function Seed:GetRandSwingAnimationName()
	if (self.m_edible) then
		return self.m_swingAnimationName
	else
		return nil
	end
end

-------------------------------------------------------------------------------
-- Eat the seed.  Note that this logic is duplicated from Consumable.  This is
-- because Consumable needs to be reworked into a mixin, but that introduces
-- several potential problems that need to be addressed first.  In the meantime,
-- this should provide the functionality we need.
function Seed:PrimaryAction( args )
	if (not self.m_edible) then
		return false
	end
	
	Seed.__super.PrimaryAction(self, args)
end


function Seed:SecondaryAction( args )
	self:NKSetPosition(args.targetPoint)
	return self:Plant()
end


-------------------------------------------------------------------------------
-- Callback for when a player places this object.  Creates a GrowableStarter
-- that begins the growth process.  If the GrowableStarter returns a new object
-- (meaning it succeeded its growth check), then the Seed is deleted.
function Seed:Plant()
	if (not Eternus.IsServer) then
		return false
	end
	
	-- First off, determine whether or not we can even attempt to place something.
	local canGrow = self.m_growthData:CheckConditions(self.object, {self.object})
    
	if (canGrow ~= 0) then
		return false
	end

	-- Create new object
	local growableStarter = Eternus.GameObjectSystem:NKCreateGameObject(self.m_nextFormName, true)
	if (growableStarter == nil) then
		NKError("Attemtping to create starter object " .. self.m_nextFormName .. ", but object could not be created.\n")
		return false
	end
	
	-- Starter successfully created.  Set its position and grow!
	growableStarter:NKSetPosition(self:NKGetWorldPosition(), false)
	local grownObject = nil
	local starterScript = growableStarter:NKGetInstance()
	if (starterScript.Grow == nil) then
		NKError("Object " .. self.m_nextFormName .. " is not a growable starter!\n")
		return false
	end
	
	grownObject = starterScript:Grow({self.object})
	if (grownObject ~= nil) then
		growableStarter = nil
		self:ModifyStackSize(-1) -- Starter should delete itself.
		return true
	end
	
	return false
end

-------------------------------------------------------------------------------
function Seed:out(msg)
	if (self.m_debugOutput) then
		NKError(msg)
	end
end


-------------------------------------------------------------------------------
EntityFramework:RegisterGameObject(Seed)
return Seed