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
PANEL.PanelDeleteTimeOut = 5	--after 5 seconds a stranded ent panel will be removed

PANEL.VerticalMargin = 0.25
PANEL.HorizontalMargin = 0.5

function PANEL:Init()
	--since they're being added to the IconLayout, they're not technically my children, so keep track of them manually
	self.MyChildren = {}
	
	self.IconSize = 64
	
	self.IconLayout = self:Add( "DIconLayout" )
	self.IconLayout:SetSize( self.IconSize , self.IconSize )
	self.IconLayout:SetBorder( 1 )
	self.IconLayout:SetSpaceX( 2 )
	self.IconLayout:SetSpaceY( 2 )
end

function PANEL:Think()

end

function PANEL:PerformLayout( w , h )
	
	local dockpos = RIGHT
	
	self.IconLayout:Dock( dockpos )	--TODO: get from the convar
	
	local margin = 0
	
	if dockpos == RIGHT or dockpos == LEFT then
		margin = h * self.VerticalMargin
		self.IconLayout:DockMargin( 0 , margin , 0 , margin )
	else
		margin = w * self.HorizontalMargin
		self.IconLayout:DockMargin( margin , 0 , margin , 0 )
	end

end

function PANEL:Paint( w , h )
end

function PANEL:AddPEPanel( panel )
	
	if not panel then
		return
	end
	
	panel:SetSize( self.IconSize , self.IconSize )
	
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
	panel:SetVisible( true )
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

if IsValid( PE_HUD ) then
	CreatePEHud()
end


hook.Add( "Initialize" , "PEHud" , CreatePEHud )