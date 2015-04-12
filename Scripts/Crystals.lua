-- Crystals

include("Scripts/Core/Common.lua")

-------------------------------------------------------------------------------
if Crystals == nil then
	Crystals = EternusEngine.ModScriptClass.Subclass("Crystals")
end

-------------------------------------------------------------------------------
function Crystals:Constructor(  )

end

 -------------------------------------------------------------------------------
 -- Called once from C++ at engine initialization time
function Crystals:Initialize()
	Eternus.CommandService:NKRegisterChatCommand("TestCommand", "TestCommandFunction")
end

-------------------------------------------------------------------------------
-- Called from C++ when the current game enters 
function Crystals:Enter()	
end

-------------------------------------------------------------------------------
-- Called from C++ when the game leaves it current mode
function Crystals:Leave()
end

-------------------------------------------------------------------------------
-- Called from C++ every update tick
function Crystals:Process(dt)
end

function Crystals:TestCommandFunction(args)
	NKError("Registered Command Worked!")
end

EntityFramework:RegisterModScript(Crystals)