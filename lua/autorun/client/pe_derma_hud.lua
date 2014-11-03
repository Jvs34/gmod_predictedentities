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
	self.MyChildren = {}
	self.IconLayout = self:Add( "DIconLayout" )
	self.IconLayout:SetBorder( 1 )
	self.IconLayout:SetSpaceX( 2 )
	self.IconLayout:SetSpaceY( 2 )
	self.IconLayout:Dock( BOTTOM )
end

function PANEL:Think()

end

function PANEL:Paint( w , h )
--	surface.SetDrawColor( color_white )
--	surface.DrawRect( 0 , 0 , w , h )
end

function PANEL:AddPEPanel( panel )
	if not panel then
		return
	end
	
	self.MyChildren[panel:GetSlot()] = panel
	panel:SetParent( self.IconLayout )
end

function PANEL:HasSlot( slotname )
	return IsValid( self.MyChildren[slotname] )
end

function PANEL:RemovePanelBySlot( slotname )
	if IsValid( self.MyChildren[slotname] ) then
		self.MyChildren[slotname]:Remove()
		self.MyChildren[slotname] = nil
	end
end

derma.DefineControl( "DPredictedEntManager", "", PANEL, "DPanel" )


local function CreatePEHud()
	
	local panel = vgui.Create( "DPredictedEntManager" )
	panel:ParentToHUD()
	panel:Dock( FILL )
	
	return panel
end


hook.Add( "Initialize" , "PEHud" , function()
	PE_HUD = CreatePEHud()
end)
