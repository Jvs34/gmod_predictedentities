--[[
	A DProperty that allows the user to left click on an entity to choose it
	This also needs to highlight the selected entity and show an arrow leaving this panel pointing to that entity
]]

local PANEL = {}

function PANEL:Init()

end

function PANEL:GetEntity()
	local entindex = tonumber( self:GetValue() )
	if entindex then
		return Entity( entindex )
	end
end

function PANEL:Setup( vars )

	self:Clear()
	
	--create a text entry, when the user clicks on it, start a world picker
	
	local ctrl = self:Add( "DButton" )
	ctrl:SetText( "Choose Entity" )
	
	
	--[[
	local ctrl = self:Add( "DBinder" )
	ctrl:Dock( FILL )	--this'll look a bit ugly
	
	self.IsEditing = function( self )
		return ctrl.Trapping
	end
	
	self.SetValue = function ( self , val )
		ctrl:SetSelected( tonumber( val ) )	--use this instead of setValue to possibly avoid feedback loops
	end
	
	--DBinder doesn't have an onchange callback, so we must do this little hack to add it
	ctrl.SetValue = function( self , val )
		self:SetSelected( val )
		self:OnChange( val )
	end
	
	ctrl.OnChange = function( ctrl , newval )
		self:ValueChanged( newval )
	end
	]]
end

derma.DefineControl( "DProperty_PickEnt", "", PANEL, "DProperty_Generic" )