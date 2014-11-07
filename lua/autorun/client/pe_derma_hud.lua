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

--UGH, there has to be a better way than setting this
local function CreatePEHud()
	
	if IsValid( PE_HUD ) then
		PE_HUD:Remove()
		PE_HUD = nil
	end
	
	local panel = vgui.Create( "DPredictedEntManager" )
	panel:ParentToHUD()
	panel:Dock( FILL )
	
	
	PE_HUD = panel
	
	--this didn't work properly in my tests, I think it was autorefresh that fucked it up
	--welp, guess I gotta add support for that as well
	--[[
	local tab = scripted_ents.GetStored( "base_predictedent" )
	if tab then
		tab.MainHUDPanel = PE_HUD
	end
	]]
end


hook.Add( "Initialize" , "PEHud" , CreatePEHud )
hook.Add( "OnReloaded" , "PEHud" , CreatePEHud )