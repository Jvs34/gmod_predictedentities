--[[
	This is the actual representation of the predicted entity on the hud, when clicked this will run the pe_drop concommand
	to drop it
	
	This will draw a rounded texture of the entity class with stencils
	
	This will also support custom elements added to it during ENT:SetupCustomHUDElements( panel )
]]


local PANEL = {}

PANEL.DefaultEntityMaterial = Material( "entities/npc_alyx.png" )
PANEL.CircleMaskMaterial = Material( "" )

function PANEL:Init()
	self:SetSize( 128 , 128 )	--TODO: ask our parent for the best size scale
	
	self.RecheckMat = false
	
	self.Label = self:Add( "DLabel" )
	self.Label:SetFont( "Default" )
	self.Label:Dock( BOTTOM )
end

function PANEL:Think()
	
	if self:IsMarkedForDeletion() then
		return
	end
	
	--don't do anything if the entity in this slot is not valid, because the user might just be lagging or something
	--and in case of deletion, it's the entity itself that will ask for it
	if not IsValid( self:GetEntity() ) then
		return
	end
	
	--try to get the material from the entity class
	if not self:IsEntityMaterialSet() and self.RecheckMat then
		local class = self:GetEntity():GetClass()
		local mat = Material( "entities/" .. class .. ".png" )
		
		self.Label:SetText( "#"..class )	--will resolve to the Localize of that entity class
		
		if not mat:IsError() then
			self:SetEntityMaterial( mat )
		end
		
		self.RecheckMat = false
	end
	
	self:CustomThink()
end

function PANEL:GetEntity()
	return LocalPlayer():GetNWEntity( self:GetSlot() )
end

function PANEL:SetEntityMaterial( mat )
	if not mat or mat:IsError() then
		return
	end
	self.EntityMaterial = mat
end

function PANEL:GetEntityMaterial()
	if not self.EntityMaterial or self.EntityMaterial:IsError() then
		return self.DefaultEntityMaterial
	end
	return self.EntityMaterial
end

function PANEL:IsEntityMaterialSet()
	return self:GetEntityMaterial() and self:GetEntityMaterial() ~= self.DefaultEntityMaterial
end

--can be overridden by SetupCustomHUDElements, won't be called if the entity is not valid
function PANEL:CustomThink()

end

function PANEL:SetSlot( str )
	self.RecheckMat = true
	self.Slot = str
end

function PANEL:GetSlot()
	return self.Slot
end

function PANEL:DoClick()
	RunConsoleCommand( "pe_drop" , self:GetSlot() )
end

function PANEL:Paint( w , h )
	local mat = self:GetEntityMaterial()
	
	--TODO: apply stencils
	surface.SetMaterial( mat )
	surface.DrawTexturedRect( 0 , 0 , w , h )
end

derma.DefineControl( "DPredictedEnt", "", PANEL, "DButton" )