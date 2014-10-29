AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Grappling hook Backpack"

if CLIENT then
	language.Add( "sent_grapplehook_bpack" , ENT.PrintName )
	ENT.KeyConvar = CreateConVar( "grapplehook_key" , "17", FCVAR_ARCHIVE + FCVAR_USERINFO , "The key code to trigger IN_GRENADE1 and use the grappling hook." )
else
	ENT.ShowPickupNotice = true
end

ENT.HookKey = IN_GRENADE1
ENT.HookMaxRange = 10000
ENT.HookHullMins = Vector( -2 , -2 , -2 )
ENT.HookHullMaxs = Vector( 2 , 2 , 2 )

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

sound.Add( {
	name = "grapplehook.reelsound",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^vehicles/digger_grinder_loop1.wav"
})

sound.Add( {
	name = "grapplehook.shootrope",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^weapons/tripwire/ropeshoot.wav",
})

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
		
		--TODO: change to a dummy model and set the collision bou
		self:SetModel( "models/thrusters/jetpack.mdl" )
		
		self:InitPhysics()
		
		self:ResetGrapple()
		self:Detach()
	else
		self:CreateModels()
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
		self:HandleDetach( false )
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
	self:SetAttachSoundPlayed( false )
end

function ENT:HandleDetach( predicted , mv )
	
	if CLIENT and not predicted then
		return
	end
	
	if self:GetIsAttached() then 
		if self:GetAttachTime() < CurTime() then
			if self:ShouldStopPulling( mv ) then
				self:Detach( true )
			end
		end
	end
end

function ENT:HandleSounds( predicted )
	if CLIENT and not predicted then
		self.LaunchSound = nil
		self.ReelSound = nil
		return
	end
	
	if not self.LaunchSound then
		self.LaunchSound = CreateSound( self , "grapplehook.shootrope" )
	end
	
	if not self.ReelSound then
		self.ReelSound = CreateSound( self , "grapplehook.reelsound" )
	end
	
	if self:GetIsAttached() then
		if self:GetAttachTime() < CurTime() then
			
			if not self:GetAttachSoundPlayed() then
				
				--play the hit sound only the controlling player and one on the world position
				
				if IsValid( self:GetControllingPlayer() ) then
					self:EmitPESound( "NPC_CombineMine.CloseHooks" , nil , nil , nil , nil , true , self:GetControllingPlayer() )
				end
				
				--[[
				if SERVER then
					EmitSound( "NPC_CombineMine.CloseHooks" , self:GetAttachedTo() , 0 , CHAN_AUTO , 0.7 , 75 , SND_NOFLAGS , 100 )
				end
				]]
				
				self:SetAttachSoundPlayed( true )
			end
			
			self.ReelSound:PlayEx( 0.3 , 200 )
			self.LaunchSound:Stop()
		else
			self.LaunchSound:PlayEx( 1 , 100 )
		end
	else
		self.LaunchSound:Stop()
		self.ReelSound:Stop()
	end
end


--allows the user to have a keybind
function ENT:PredictedStartCommand( owner , usercmd )
	if CLIENT then
		local mykey = self.KeyConvar:GetInt()
		if mykey ~= BUTTON_CODE_NONE and mykey > BUTTON_CODE_NONE and mykey < BUTTON_CODE_COUNT then
			if input.IsButtonDown( mykey ) then
				usercmd:SetButtons( bit.bor( usercmd:GetButtons() , self.HookKey ) )
			end
		end
	end
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
	self:HandleDetach( true , mv )
	self:HandleSounds( true )
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
		local timetoreach = Lerp( result.Fraction , 0 , 4 )
		
		self:SetAttachedTo( result.HitPos )
		self:SetAttachTime( CurTime() + timetoreach )
		self:SetAttachStart( CurTime() )
		self:SetIsAttached( true )
		self:SetGrappleNormal( self:GetDirection() )
		
		self:EmitPESound( "ambient/machines/catapult_throw.wav" , nil , nil , nil , nil , true )
	end

end

function ENT:GetDirection()
	if not IsValid( self:GetControllingPlayer() ) then
		return ( self:GetAttachedTo() - self:GetPos() ):GetNormalized()
	end
	return ( self:GetAttachedTo() - self:GetControllingPlayer():EyePos() ):GetNormalized()
end

function ENT:DoHookTrace()
	local tr = {
		--TODO: custom filter callback?
		filter = {
			self:GetControllingPlayer(),
			self,
		},
		mask = MASK_SOLID_BRUSHONLY,	--TODO: use the player solid mask?
		start = self:GetControllingPlayer():EyePos(),
		endpos = self:GetControllingPlayer():EyePos() + self:GetControllingPlayer():GetAimVector() * self.HookMaxRange,
		mins = self.HookHullMins,
		maxs = self.HookHullMax
	}
	return util.TraceHull( tr )
end

function ENT:ShouldStopPulling( mv )

	if not IsValid( self:GetControllingPlayer() ) then
		return ( self:NearestPoint( self:GetAttachedTo() ) ):Distance( self:GetAttachedTo() ) <= 45
	end
	
	return ( self:GetControllingPlayer():NearestPoint( self:GetAttachedTo() ) ):Distance( self:GetAttachedTo() ) <= 45 or not mv:KeyDown( self.HookKey )
end

function ENT:CanPull( mv )
	return self:GetIsAttached() and self:GetAttachTime() < CurTime() and not self:ShouldStopPulling( mv )
end

function ENT:OnRemove()
	if CLIENT then
		self:RemoveModels()
		self:StopSound( "grapplehook.reelsound" )
		self:StopSound( "grapplehook.shootrope" )
	end
	
	BaseClass.OnRemove( self )
end

if SERVER then

	function ENT:OnAttach( ply )
	end
	
	function ENT:OnDrop( ply , forced )
		if not ply:Alive() then
			--TODO: like for the jetpack, we still let the entity function as usual when the user dies
			return
		end
		
		self:ResetGrapple()
		self:Detach( not forced )
	end
	
	--TODO: override the physics because we use a dummy model
	
	--[[
		function ENT:InitPhysics()
			--create a bbox for us and set our movetype and solid to VPHYSICS
		end
		
		function ENT:RemovePhysics()
			--destroy the physobj and set the solid to BBOX, so we can be shot at like the jetpack
		end
	]]
	
	function ENT:OnInitPhysics( physobj )
		self:StartMotionController()
	end

	function ENT:OnRemovePhysics()
		self:StopMotionController()
	end
	
	function ENT:PhysicsSimulate( physobj , delta )
		
		if self:GetIsAttached() and not self:GetBeingHeld() and self:CanPull() then
			physobj:Wake()
			local force = self:GetDirection() * 1000
			local angular = vector_origin
			
			return angular , force * physobj:GetMass() , SIM_GLOBAL_FORCE
		end
	end
	
else
	
	function ENT:CreateModels()
		--create all the models, hook , our custom one 
	end
	
	function ENT:RemoveModels()
	
	end
	
	function ENT:DrawHook( pos , ang )
	
	end
	
	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
		end
	end

end