--[[
	This is the actual representation of the predicted entity on the hud, when clicked this will run the pe_drop concommand
	to drop it
	
	This will draw a rounded texture of the entity class with stencils
	
	This will also support custom elements added to it during ENT:SetupCustomHUDElements( panel )
]]


local PANEL = {}

function PANEL:Init()
	--create a dlabel
	
end

function PANEL:Think()
	
	if self:IsMarkedForDeletion() then
		return
	end
	
	if not IsValid( LocalPlayer():GetNWEntity( self:GetSlot() ) ) then
		--only delete when the entity actually gets deleted, because the user could just be lagging at the moment
		return
	end
	
	self:CustomThink()
end

--can be overridden by SetupCustomHUDElements
function PANEL:CustomThink()

end

function PANEL:SetSlot( str )
	self.Slot = str
end

function PANEL:Paint()
	--
end

derma.DefineControl( "DPredictedEnt", "", PANEL, "DPanel" )