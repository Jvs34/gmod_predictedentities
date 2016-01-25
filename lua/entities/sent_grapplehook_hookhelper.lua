AddCSLuaFile()

--[[
	Much like the physgun beam, this is an external entity that draws the beam separately from the grapple hook itself
	You could see this as a Lua env_laser of some sort
]]

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
			--might happen, you never knoooooow, bad addons are everywhere
			if self:GetParent():GetClass() ~= "sent_grapplehook_bpack" then
				self:Remove()
			end
		else
			if self:GetParent():IsHookActive() then
				--yeah this might seem like a big fucking deal, but the env_laser and the physics gun all do the same, so shush, I'm doing it the valve way
				self:SetRenderBoundsWS( self:GetPos() , self:GetParent():GetAttachedTo() )
			else
				self:SetRenderBounds( self:GetParent():GetRenderBounds() )
			end
		end
	end
end

--screw calling setpos and setangles manually, this needs to be shared 
function ENT:CalcAbsolutePosition( pos , ang )
	if IsValid( self:GetParent() ) then
		return self:GetParent():GetHookAttachment()
	end
end

if CLIENT then
	function ENT:Draw( flags )
		if IsValid( self:GetParent() ) and self:GetParent():IsHookActive() then
			self:GetParent():DrawGrapple( flags )
		end
	end
end