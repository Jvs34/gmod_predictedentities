--[[
	This is the actual representation of the predicted entity on the hud, when clicked this will run the pe_drop concommand
	to drop it
	
	This will draw a rounded texture of the entity class with stencils
	
	This will also support custom elements added to it during ENT:SetupCustomHUDElements( panel )
]]


local PANEL = {}
PANEL.IconPathFolder = "pe/"
PANEL.IconPath = "models/"..PANEL.IconPathFolder

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetWorldClicker( false )
	self:SetSize( 64 , 64 )	--TODO: ask our parent for the best size scale
	self:SetText( "" )
	
	self.ModelIcon = self:Add( "SpawnIcon" )
	self.ModelIcon:SetModel( "models/error.mdl" )
	self.ModelIcon:SetSize( 64 , 64 )
	self.ModelIcon:SetPaintedManually( true )
	self.BuiltSpawnIcon = false
	
	--[[
	self.Label = self:Add( "DLabel" )
	self.Label:SetFont( "Default" )
	self.Label:Dock( BOTTOM )
	self.Label:SetContentAlignment( 5 )
	]]
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
	
	self.LastSlotKnown = UnPredictedCurTime()
	
	--ask to rebuild the spawnicon
	self:CheckSpawnIcon()
	
	--only fires if the entity is valid
	self:CustomThink()
end

function PANEL:GetEntity()
	return LocalPlayer():GetNWEntity( self:GetSlot() )
end


--can be overridden by SetupCustomHUDElements, won't be called if the entity is not valid
function PANEL:CustomThink()

end

function PANEL:DoRebuild()
	self.BuiltSpawnIcon = true
	
	self.DummyModel = ClientsideModel( "models/error.mdl" )
	self.DummyModel:SetNoDraw( true )
	self.DummyModel.RenderOverride = function( dummy , flags )
		
		render.SuppressEngineLighting( true )
		
		render.SetLightingOrigin( Vector( 0 , 0 , 100 ) )
		
		render.ResetModelLighting( 0.2 , 0.2 , 0.2 )
		
		render.SetModelLighting( BOX_TOP , 10 , 10 , 10 )
		
		--call the utility draw from the entity
		self:DrawSpawnIcon( flags )
		
		render.SuppressEngineLighting( false )
	end
	
	local tab = {}
	tab.ent		= self.DummyModel
	tab.cam_pos = Vector( -30 , 0 , 0 )
	tab.cam_ang = Angle( 0 , 0 , 0 )
	tab.cam_fov = 45

	self.ModelIcon:RebuildSpawnIconEx( tab )
end

function PANEL:GetSpawnIconMat()
	return Material( "spawnicons/"..self.IconPath .. self.Slot .. ".png" )
end

function PANEL:GetSpawnIconModelPath()
	return self.IconPath .. self.Slot .. ".mdl"
end

function PANEL:SetSlot( str )
	self.Slot = str
	self.ModelIcon:SetModel( self:GetSpawnIconModelPath() )
	self.SpawnIconMat = self:GetSpawnIconMat()
	self:DoRebuild()
end

function PANEL:CheckSpawnIcon()
	
	if self.BuiltSpawnIcon then
		if self.ModelIcon then
			self.ModelIcon:Remove()
			self.ModelIcon = nil
		end
		return
	end
	
	if self.SpawnIconMat:IsError() then
		self:DoRebuild()
	end
end

function PANEL:GetSlot()
	return self.Slot
end

function PANEL:DoClick()
	RunConsoleCommand( "pe_drop" , self:GetSlot() )
end

function PANEL:Paint( w , h )
	local x , y = self:LocalToScreen( 0 , 0 )
	
	surface.SetDrawColor( self:GetColor() )
	render.SetColorMaterial()
	surface.DrawRect( 0 , 0 , w , h )
	
	if not self.BuiltSpawnIcon then
		self.ModelIcon:SetPaintedManually( false )
		self.ModelIcon:PaintAt( x , y , w , h )
		self.ModelIcon:SetPaintedManually( true )
	else
		surface.SetDrawColor( color_white )
		surface.SetMaterial( self.SpawnIconMat )
		surface.DrawTexturedRect( 0 , 0 , w , h )
	end
	
	self:CustomPaint( w , h )
end

function PANEL:CustomPaint( w , h )
	
end

function PANEL:DrawSpawnIcon( flags )
	local ent = self:GetEntity()
	if IsValid( ent ) and ent.DrawSpawnIcon then
		ent:DrawSpawnIcon( flags )
	end
end

function PANEL:OnRemove()
	if IsValid( self.DummyModel ) then
		self.DummyModel:Remove()
	end
end

derma.DefineControl( "DPredictedEnt", "", PANEL, "DButton" )