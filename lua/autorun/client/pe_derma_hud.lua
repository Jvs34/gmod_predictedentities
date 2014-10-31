--[[
	The panel that contains all the predicted entity buttons, and will shift them either on a vertical
	or horizontal layout depending on the pe_* convars
	
	It would be best to show these buttons in the space between the health/armor hud and  the ammo
	but this, of course may depend on the user
	
	The entity buttons register themselves from the entities they originate from, and they're associated to slots
	Once the entity in that slot has been removed
]]

local PANEL = {}

PANEL.HUDSide = 0 --goes from 0 to 3 --CreateConVar

function PANEL:Init()

end

function PANEL:Think()

end

function PANEL:Paint()

end

derma.DefineControl( "DPredictedEntManager", "", PANEL, "DPanel" )