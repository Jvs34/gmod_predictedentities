AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Grappling hook Backpack"

if CLIENT then
	language.Add( "sent_grapplehook_bpack" , ENT.PrintName )
	ENT.ConVar = CreateConVar( "grapplehook_key" , "17", FCVAR_ARCHIVE + FCVAR_USERINFO , "The key code to trigger IN_GRENADE1 and use the grappling hook." )
end

ENT.HookKey = IN_GRENADE1
ENT.HookMaxRange = 10000
ENT.HookHullMins = Vector( -4 , -4 , -4 )
ENT.HookHullMaxs = Vector( 4 , 4 , 4 )

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

--TODO: create an extra entity called sent_grapplehook_hook to handle the hook drawing along with the beam
--for now, the old behaviour of drawing it manually is fine

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 36

	local ent = ents.Create( ClassName )
	ent:SetSlotName( ClassName )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	return ent

end

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		
		self:ResetGrapple()
		self:Detach()
		
	else
	
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Float" , "NextFire" )
	self:DefineNWVar( "Float" , "AttachTime" )
	self:DefineNWVar( "Float" , "AttachStart" )
	self:DefineNWVar( "Vector" , "AttachedTo" )
	self:DefineNWVar( "Vector" , "GrappleNormal" )
	self:DefineNWVar( "Bool" , "IsAttached" )
	self:DefineNWVar( "Bool" , "AttachSoundPlayed" )
end


function ENT:Think()
	if not IsValid( self:GetControllingPlayer() ) then
		self:HandleSounds( false )
	end
	
	return BaseClass.Think( self )
end

function ENT:ResetGrapple()
	self:SetNextFire( CurTime() + 1 )
	self:SetAttachTime( CurTime() )
	self:SetAttachStart( CurTime() )
	self:SetAttachedTo( vector_origin )
	self:SetGrappleNormal( vector_origin )
	self:SetIsAttached( false )
	self:SetAttachSoundPlayed( false )
end

function ENT:Detach( forced )
	self:SetIsAttached( false )
	self:SetAttachTime( CurTime() )
	self:SetAttachStart( CurTime() )
	self:SetNextFire( CurTime() + ( forced and 0.5 or 1 ) )
end

function ENT:HandleSounds( predicted )
	--TODO: rewrite this
	
	if CLIENT and not predicted then
		self.LaunchSound = nil
		self.ReelSound = nil
		return
	end
	
	
	if not self.LaunchSound then
		self.LaunchSound = CreateSound( self , "TripwireGrenade.ShootRope" )
	end
	
	if not self.ReelSound then
		self.ReelSound = CreateSound( self , "vehicles/digger_grinder_loop1.wav" )
	end
	
	--[[
	self.LaunchSound = CreateSound( self , "TripwireGrenade.ShootRope" )
	self.ReelSound = CreateSound( self , "vehicles/digger_grinder_loop1.wav" )
	
	if self:GetIsAttached() then 
		if self:GetAttachTime()<=CurTime() then
			if not self:GetAttachSoundPlayed() then
				self:EmitSound( "NPC_CombineMine.CloseHooks")
				self:SetAttachSoundPlayed(true)
			end
			if self.ReelSound then
				self.ReelSound:Play()
				self.ReelSound:ChangePitch(200,0)
				self.ReelSound:ChangeVolume(0.3,0)
			end
			if self.LaunchSound then
				self.LaunchSound:Stop()
			end
		end

	else
		if self.LaunchSound then
			self.LaunchSound:Stop()
		end
		if self.ReelSound then
			self.ReelSound:Stop()
		end
	end
	]]
end

function ENT:PredictedSetupMove( owner , mv , usercmd )
	
	if mv:KeyPressed( self.HookKey ) then
		if self:GetNextFire() <= CurTime() then
			self:FireHook()
		end
	end
	
end

function ENT:PredictedMove( owner , mv )
	if self:CanPull( mv ) then
		owner:SetGroundEntity( NULL )
		mv:SetForwardSpeed( 0 )
		mv:SetSideSpeed( 0 )
		mv:SetUpSpeed( 0 )
		--TODO: clamp the velocity
		mv:SetVelocity( mv:GetVelocity() + self:GetDirection() * 2000 * FrameTime() )
	end
end

function ENT:PredictedThink( owner , mv )
	self:HandleSounds( true )
	
	if self:GetIsAttached() then 
		if self:GetAttachTime() <= CurTime() then
			if self:ShouldStopPulling( mv ) then
				self:Detach( true )
			end
		end
	end
end

function ENT:FireHook()
	if self:GetIsAttached() then
		return
	end
	
	self:SetNextFire( CurTime() + 3 )
	
	self:GetControllingPlayer():LagCompensation( true )
	
	local result = self:DoHookTrace()
	
	self:GetControllingPlayer():LagCompensation( false )
	
	if not result.HitSky and result.Hit then
		local len = ( self:GetControllingPlayer():EyePos():Distance( result.HitPos ) ) / self.HookMaxRange
		local timetoreach = Lerp( result.Fraction , 0 , 2.5 )
		
		
		self:SetAttachedTo( result.HitPos )
		self:SetAttachTime( CurTime() + timetoreach )
		self:SetAttachStart( CurTime() )
		self:SetIsAttached( true )
		
		--TODO: rewrite this
		
		--[[
		if entity.LaunchSound then
			entity.LaunchSound:Play()
			entity.LaunchSound:ChangeVolume(4,0)
		end
		
		entity:EmitSound("ambient/machines/catapult_throw.wav")
		]]
		self:SetGrappleNormal( self:GetDirection() )
	end

end

function ENT:GetDirection()
	return ( self:GetAttachedTo() - self:GetControllingPlayer():EyePos() ):GetNormalized()
end

function ENT:DoHookTrace()
	local tr = {
		filter = self:GetControllingPlayer(),
		mask = MASK_SOLID_BRUSHONLY,
		start = self:GetControllingPlayer():EyePos(),
		endpos = self:GetControllingPlayer():EyePos() + self:GetControllingPlayer():GetAimVector() * self.HookMaxRange,
		mins = self.HookHullMins,
		maxs = self.HookHullMax
	}
	return util.TraceHull( tr )
end

function ENT:ShouldStopPulling( mv )
	return ( self:GetControllingPlayer():NearestPoint( self:GetAttachedTo() ) ):Distance( self:GetAttachedTo() ) <= 45 or not mv:IsKeyDown( self.HookKey )
end

function ENT:CanPull( mv )
	return self:GetIsAttached() and self:GetAttachTime() < CurTime() and not self:ShouldStopPulling( mv )
end

if SERVER then

	function ENT:OnAttach( ply )
	
	end
	
	function ENT:OnDrop( ply , forced )
		self:ResetGrapple()
		self:Detach( not forced )
	end
	
	function ENT:OnInitPhysics( physobj )

	end

	function ENT:OnRemovePhysics()

	end
	
else

	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
		end
	end

end