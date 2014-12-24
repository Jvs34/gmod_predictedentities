--[[
	The panel that contains all the predicted entity buttons, and will shift them either on a vertical
	or horizontal layout depending on the pe_* convars
	
	It would be best to show these buttons in the space between the health/armor hud and  the ammo
	but this, of course may depend on the user
	
	The entity buttons register themselves from the entities they originate from, and they're associated to slots
]]

local PANEL = {}

PANEL.HUDSideConVar = CreateConVar( "cl_pe_hud_side" , "1", FCVAR_ARCHIVE , "" )
PANEL.PanelDeleteTimeOut = 5	--after 5 seconds a stranded ent panel will be removed

PANEL.VerticalMargin = 0.25
PANEL.HorizontalMargin = 0.35

function PANEL:Init()
	self:MouseCapture( true )
	self:RequestFocus()
	--self:MakePopup()
	self:SetMouseInputEnabled( true )
	self:SetKeyboardInputEnabled( false )
	self:SetWorldClicker( true )
	--since they're being added to the IconLayout, they're not technically my children, so keep track of them manually
	self.MyChildren = {}
	
	if not self.IconSize then
		self.IconSize = 64
	end
	
	self.IconLayout = self:Add( "DIconLayout" )
	self.IconLayout:Dock( FILL )
	self.IconLayout:SetBorder( 0 )
	self.IconLayout:SetSpaceX( 2 )
	self.IconLayout:SetSpaceY( 2 )
end

function PANEL:Think()
	
	if self.IconLayout:GetDock() ~= self:GetHUDSide() then
		self:InvalidateLayout()
	end
	
	for i , v in pairs( self.MyChildren ) do
		if IsValid( v ) and v.LastSlotKnown and v.LastSlotKnown <= UnPredictedCurTime() - self.PanelDeleteTimeOut then
			self:RemovePanelBySlot( i )
		end
	end
end

function PANEL:GetHUDSide()
	return math.Clamp( self.HUDSideConVar:GetInt() + 2 , LEFT , BOTTOM )
end

function PANEL:PerformLayout( w , h )
	
	local dockpos = self:GetHUDSide()
	
	self.IconLayout:Dock( dockpos )
	
	local margin = 0
	
	if dockpos == RIGHT or dockpos == LEFT then
		margin = h * self.VerticalMargin
		self.IconLayout:DockMargin( 0 , margin , 0 , margin )
	elseif dockpos == TOP or dockpos == BOTTOM then
		margin = w * self.HorizontalMargin
		self.IconLayout:DockMargin( margin , 0 , margin , 0 )
	end
	
	self.IconLayout:SetSize( self.IconSize , self.IconSize )
	self.IconLayout:InvalidateLayout()
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

derma.DefineControl( "DPredictedEntManager", "", PANEL, "EditablePanel" )

function CreatePEHud()
	local panel = vgui.Create( "DPredictedEntManager" )
	panel:SetVisible( true )
	panel:SetParent( vgui.GetWorldPanel() )
	--panel:ParentToHUD()
	panel:Dock( FILL )
	
	if IsValid( PE_HUD ) then
		PE_HUD:Remove()
	end
	
	PE_HUD = panel
	
	--[[
	local tab = scripted_ents.GetStored( "base_predictedent" )
	if tab then
		if IsValid( tab.MainHUDPanel ) then
			tab.MainHUDPanel:Remove()
		end
		tab.MainHUDPanel = panel
		print( tab.MainHUDPanel )
	end
	]]
end

hook.Add( "InitPostEntity" , "PEHud" , CreatePEHud )