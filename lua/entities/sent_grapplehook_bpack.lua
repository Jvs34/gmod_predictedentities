AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Grappling hook Backpack"

if CLIENT then
	language.Add( "sent_grapplehook_bpack" , ENT.PrintName )
	ENT.CableMaterial = Material( "cable/cable2" )
else
	ENT.ShowPickupNotice = true
end

ENT.InButton = IN_GRENADE1
ENT.HookMaxRange = 10000
ENT.HookHullMins = Vector( -2 , -2 , -2 )
ENT.HookHullMaxs = Vector( 2 , 2 , 2 )

--TODO: position ourselves on the player's belt
ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

ENT.HookAttachmentInfo = {
	OffsetVec = vector_origin,
	OffsetAng = angle_zero,
}

--[[
sound.Add( {
	name = "grapplehook.hit",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^vehicles/digger_grinder_loop1.wav"
})
]]

sound.Add( {
	name = "grapplehook.launch",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^ambient/machines/catapult_throw.wav"
})

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
		--TODO: change to a dummy model and set the collision bounds and render bounds manually
		self:SetModel( "models/thrusters/jetpack.mdl" )
		
		self:SetKey( 17 )	--the G key on my keyboard
		self:InitPhysics()
		
		self:ResetGrapple()
		self:Detach()
	else
		self:CreateModels()
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Float" , "AttachTime" )
	self:DefineNWVar( "Float" , "AttachStart" )
	self:DefineNWVar( "Vector" , "AttachedTo" )
	self:DefineNWVar( "Vector" , "GrappleNormal" )
	self:DefineNWVar( "Bool" , "IsAttached" )
	self:DefineNWVar( "Bool" , "AttachSoundPlayed" )
	self:DefineNWVar( "Entity" , "HookHelper" )
end


function ENT:Think()
	
	self:HandleHookHelper( false )
	
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

function ENT:HandleHookHelper( predicted )
	if CLIENT then
		return
	end
	
	if IsValid( self:GetHookHelper() ) then
		return
	end
	
	local hh = ents.Create( "sent_grapplehook_hookhelper" )
	
	if not IsValid( hh ) then
		return
	end
	
	hh:SetParent( self )
	hh:Spawn()
	
	self:SetHookHelper( hh )
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
					self:EmitPESound( "NPC_CombineMine.CloseHooks" , nil , nil , nil , CHAN_BODY , true , self:GetControllingPlayer() )
				end
				
				--[[
				--precache sound doesn't add the sound to the sound precache list, and thus EmitSound whines 
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

function ENT:PredictedSetupMove( owner , mv , usercmd )
	if self:IsKeyDown( mv ) then
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
	
	self:SetNextFire( CurTime() + 0.5 )
	
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
		
		self:EmitPESound( "grapplehook.launch" , nil , nil , nil , CHAN_WEAPON , true )
	end

end

function ENT:GetDirection()
	if not IsValid( self:GetControllingPlayer() ) then
		return ( self:GetAttachedTo() - self:GetPos() ):GetNormalized()
	end
	return ( self:GetAttachedTo() - self:GetControllingPlayer():EyePos() ):GetNormalized()
end

function ENT:DoHookTrace()
	--TODO: allow hooking to entities that never move, maybe trough the callback?
	local tr = {
		--TODO: custom filter callback?
		filter = {
			self:GetControllingPlayer(),
			self,
		},
		mask = MASK_PLAYERSOLID_BRUSHONLY,
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
	
	return ( self:GetControllingPlayer():NearestPoint( self:GetAttachedTo() ) ):Distance( self:GetAttachedTo() ) <= 45 or not self:IsKeyDown( mv )
end

function ENT:CanPull( mv )
	return self:GetIsAttached() and self:GetAttachTime() < CurTime() and not self:ShouldStopPulling( mv )
end

function ENT:OnRemove()
	if CLIENT then
		self:RemoveModels()
	else
		if IsValid( self:GetHookHelper() ) then
			self:GetHookHelper():Remove()
		end
	end
	
	self:StopSound( "grapplehook.reelsound" )
	self:StopSound( "grapplehook.shootrope" )
	
	BaseClass.OnRemove( self )
end

function ENT:GetHookAttachment()
	return LocalToWorld( self.HookAttachmentInfo.OffsetVec , self.HookAttachmentInfo.OffsetAng , self:GetPos() , self:GetAngles() )
end

if SERVER then

	function ENT:OnAttach( ply )
	end
	
	function ENT:OnDrop( ply , forced )
		--like for the jetpack, we still let the entity function as usual when the user dies
		if not ply:Alive() then
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
		--create all the models, hook , our custom one, the pulley etc
		self.CSModels = {}
		
	end
	
	function ENT:RemoveModels()
		for i , v in pairs( self.CSModels ) do
			if IsValid( v ) then
				v:Remove()
			end
		end
	end
	
	--draws the rope and grapple
	
	function ENT:DrawGrapple()
		
		local startgrapplepos , startgrappleang = self:GetHookAttachment()
		
		local endgrapplepos = vector_origin
		local endgrappleang = angle_zero
		
		if self:GetIsAttached() then
			endgrappleang = self:GetGrappleNormal():Angle()
			
			if self:GetAttachTime() >= CurTime() then
				local travelfraction = math.TimeFraction( self:GetAttachStart() , self:GetAttachTime() , CurTime() )
				endgrapplepos = LerpVector( travelfraction , startgrapplepos , self:GetAttachedTo() )
			else
				endgrapplepos = self:GetAttachedTo()
			end
			
			render.SetMaterial( self.CableMaterial )
			
			--TODO: if we haven't reached the hitpos yet then sway the rope with a sine wave
			
			render.StartBeam( 2 )
				render.AddBeam( startgrapplepos , 0.5 , 2 , color_white )
				render.AddBeam( endgrapplepos , 0.5 , 3 , color_white )
			render.EndBeam()
			
			self:DrawHook( endgrapplepos , endgrappleang )
			
		end
	end
	
	--draws the hook at the given position
	function ENT:DrawHook( pos , ang )
	
	end
	
	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
			
			if not self:GetIsAttached() then
				local pos , ang = self:GetHookAttachment()
				self:DrawHook( pos , ang )
			end
		end
	end
	
	function ENT:DrawFirstPerson( ply , vm )
	
	end

end