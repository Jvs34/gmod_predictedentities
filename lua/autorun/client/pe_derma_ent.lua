--[[
	This is the actual representation of the predicted entity on the hud, when clicked this will run the pe_drop concommand
	to drop it
	
	This will draw a rounded texture of the entity class with stencils
	
	This will also support custom elements added to it during ENT:SetupCustomHUDElements( panel )
]]


local PANEL = {}
PANEL.WhiteTex = surface.GetTextureID( "vgui/white" )
PANEL.DefaultEntityMaterial = Material( "entities/npc_alyx.png" )
PANEL.CircleMaskMaterial = Material( "" )

function PANEL:Init()
	self:SetMouseInputEnabled( true )
	self:SetWorldClicker( false )
	self:SetSize( 64 , 64 )	--TODO: ask our parent for the best size scale
	self:SetText( "" )
	self.RecheckMat = false
	
	--[[
	self.Label = self:Add( "DLabel" )
	self.Label:SetFont( "Default" )
	self.Label:Dock( BOTTOM )
	self.Label:SetContentAlignment( 5 )
	]]
end

function PANEL:GenerateCircleVertices( x, y, radius, ang_start, ang_size )

    local vertices = {}
    local passes = radius -- Seems to look pretty enough
    self.PolySize = radius
    -- Ensure vertices resemble sector and not a chord
    vertices[ 1 ] = { 
        x = x,
        y = y
    }

    for i = 0, passes do

        local ang = math.rad( -90 + ang_start + ang_size * i / passes )

        vertices[ i + 2 ] = {
            x = x + math.cos( ang ) * radius,
            y = y + math.sin( ang ) * radius
        }

    end
	
    return vertices

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
	
	--try to get the material from the entity class
	if not self:IsEntityMaterialSet() and self.RecheckMat then
		local class = self:GetEntity():GetClass()
		local mat = Material( "entities/" .. class .. ".png" )
		
		if self.Label then
			self.Label:SetText( "#"..class )	--will resolve to the Localize of that entity class
		end
		
		if not mat:IsError() then
			self:SetEntityMaterial( mat )
		end
		
		self.RecheckMat = false
	end
	
	if self.PolySize ~= self:GetTall() / 2 then
		self.Poly = self:GenerateCircleVertices( self:GetWide() / 2 , self:GetTall() / 2 , self:GetTall() / 2 , 0 , 360 )
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
	
	if self.Poly then
	render.SetStencilEnable( true )

		render.SetStencilReferenceValue( 1 )
		render.SetStencilWriteMask( 1 )
		render.SetStencilTestMask( 1 )

		render.SetStencilPassOperation( STENCIL_REPLACE )
		render.SetStencilFailOperation( STENCIL_KEEP )
		render.SetStencilZFailOperation( STENCIL_KEEP )

		render.ClearStencil()

		render.SetStencilCompareFunction( STENCIL_NOTEQUAL )
			
			surface.SetTexture( self.WhiteTex )
			surface.SetDrawColor( color_white )
			surface.DrawPoly( self.Poly )
		
		render.SetStencilCompareFunction( STENCIL_EQUAL )
	end
	
			surface.SetDrawColor( color_white )
			surface.SetMaterial( mat )
			surface.DrawTexturedRect( 0 , 0 , w , h )
			self:CustomPaint( w , h )
	if self.Poly then
		render.ClearStencil()

	render.SetStencilEnable( false )
	end
end

function PANEL:CustomPaint()
	
end

derma.DefineControl( "DPredictedEnt", "", PANEL, "DButton" )