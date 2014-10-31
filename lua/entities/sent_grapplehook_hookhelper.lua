AddCSLuaFile()

DEFINE_BASECLASS( "base_entity" )

function ENT:Initialize()
	if SERVER then
		self:SetSolid( SOLID_NONE )
		self:SetMoveType( MOVETYPE_NONE )
		self:DrawShadow( false )
	end
end

function ENT:Think()
	if IsValid( self:GetParent() ) then
		
		if SERVER then
			if self:GetParent():GetClass() ~= "sent_grapplehook_bpack" then
				self:Remove()
			end
		else
			if self:GetParent():GetIsAttached() then
				self:SetRenderBoundsWS( self:GetPos() , self:GetParent():GetAttachedTo() )
			else
				self:SetRenderBounds( self:GetParent():GetRenderBounds() )
			end
		end
	end
end

function ENT:CalcAbsolutePosition( pos , ang )
	if IsValid( self:GetParent() ) then
		return self:GetParent():GetHookAttachment()
	end
end

if CLIENT then
	function ENT:Draw( flags )
		if IsValid( self:GetParent() ) then
			self:GetParent():DrawGrapple()
		end
	end
end

function ENT:OnRemove()

end