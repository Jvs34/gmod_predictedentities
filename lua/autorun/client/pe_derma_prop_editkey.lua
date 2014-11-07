--[[
	A DProperty that allows the user to set a preferred key using the same DBinder used in sandbox's tools
]]

local PANEL = {}

function PANEL:Init()

end


function PANEL:Setup( vars )

	self:Clear()
	
	local ctrl = self:Add( "DBinder" )
	ctrl:Dock( FILL )
	
	self.IsEditing = function( self )
		return ctrl.Trapping
	end
	
	self.SetValue = function ( self , val )
		ctrl:SetSelected( tonumber( val ) )	--use this instead of setValue to possibly avoid feedback loops
	end
	
	--DBinder doesn't have an onchange callback, so we must do this little hack to add it
	ctrl.SetValue = function( ctrl , val )
		ctrl:SetSelected( val )
		self:ValueChanged( val )
	end

end

derma.DefineControl( "DProperty_EditKey" , "" , PANEL , "DProperty_Generic" )