AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.SlotName = "jetpack"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.PrintName = "Jetpack"

sound.Add( {
	name = "jetpack.thruster_loop",
	channel = CHAN_ITEM,
	volume = 1.0,
	level = 0.25,
	sound = "^thrusters/jet02.wav"
})

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 36
	
	local ent = ents.Create( ClassName )
	ent:SetPos( SpawnPos )
	ent:Spawn()
	return ent
	
end

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
		self:InitPhysics()
		self:SetMaxFuel( 100 )
		self:SetFuel( self:GetMaxFuel() )
		self:SetFuelDrain( 10 )
		self:SetFuelRecharge( 20 )
	else
		hook.Add( "PostPlayerDraw" , self , self.DrawOnPlayer )
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Bool" , "Active" )
	self:DefineNWVar( "Float" , "Fuel" )
	self:DefineNWVar( "Float" , "MaxFuel" )
	self:DefineNWVar( "Float" , "FuelDrain" ) --how many seconds it's gonna take to drain all the fuel
	self:DefineNWVar( "Float" , "FuelRecharge" ) --how many seconds it should take to fully recharge this
end

function ENT:HandleFuel( predicted )
	
	--like with normal rules of prediction, we don't want to run on the client if we're not in the simulation
	
	if not predicted and CLIENT then
		return
	end
	
	--we set the think rate on the entity to the tickrate on the server, we could've done NextThink() - CurTime(), but it's only a setter, not a getter
	
	local ft = engine.TickInterval()
	
	--screw that, during prediction we need to recharge with FrameTime()
	if predicted then
		ft = FrameTime()
	end
	
	local rechargetime = self:GetActive() and self:GetFuelDrain() or self:GetFuelRecharge()
	
	local rechargerate = self:GetMaxFuel() / ( rechargetime / ft )
	
	if self:GetActive() then
		rechargerate = rechargerate * -1
	else
		--can't recharge until our owner is on the ground!
		if IsValid( self:GetControllingPlayer() ) then
			if not self:GetControllingPlayer():OnGround() then
				rechargerate = 0
			end
		end
	end
	
	local clampedchargerate = math.Clamp( self:GetFuel() + rechargerate , 0 , self:GetMaxFuel() )
	self:SetFuel( clampedchargerate )
	
end

function ENT:HandleSounds( predicted )
	if not predicted and CLIENT then
		--stop the sound the old controller had on the client
		if self.JetpackSound then
			self.JetpackSound:Stop()
		end
		return
	end
	
	--create the soundpatch if it doesn't exist, it might happen on the client sometimes since it's garbage collected and all
	if not self.JetpackSound then
		self.JetpackSound = CreateSound( self, "jetpack.thruster_loop" )
	end
	
	if self:GetActive() then
		self.JetpackSound:PlayEx( 0.25 , 125 )
	else
		self.JetpackSound:Stop()
	end
end

function ENT:CanFly( owner , mv )
	--To willox, change this if you want to have the hover mode
	
	if IsValid( owner ) then
		return not owner:OnGround() and mv:KeyDown( IN_JUMP ) and owner:Alive() and self:GetFuel() > 0
	else
		--making it so the jetpack can also fly on its own without an owner ( in the case we want it go go nuts if the player dies or some shit )
		return self:GetFuel() > 0
	end
end

function ENT:Think()
	
	--recharge while we're not being held by a player
	if not IsValid( self:GetControllingPlayer() ) then
		self:HandleFuel( false )
		self:HandleSounds( false )
	end
	
	return BaseClass.Think( self )
end

function ENT:PredictedSetupMove( owner , movedata , usercmd )
	self:SetActive( self:CanFly( owner , movedata ) )
end

function ENT:PredictedThink( owner , movedata )
	self:HandleFuel( true )
	self:HandleSounds( true )
end

function ENT:PredictedMove( owner , data )
	if self:GetActive() then
		
		--To Willox: REPLACE ME!
		
		local oldspeed=data:GetVelocity()
		local sight=owner:EyeAngles()
		local factor=1.5
		local sidespeed=math.Clamp(data:GetSideSpeed(),-data:GetMaxClientSpeed()*factor,data:GetMaxClientSpeed()*factor)
		local forwardspeed=math.Clamp(data:GetForwardSpeed(),-data:GetMaxClientSpeed()*factor,data:GetMaxClientSpeed()*factor)
		local upspeed=data:GetVelocity().z
		sight.pitch=0;
		sight.roll=0;
		sight.yaw=sight.yaw-90;
		local upspeed=(sidespeed<=200 and forwardspeed<=100) and 22 or 12
		
		local moveang=Vector(sidespeed/70,forwardspeed/70,upspeed)
		
		moveang:Rotate(sight)
		local horizontalspeed=moveang
		data:SetVelocity(oldspeed+horizontalspeed)
	end
	
end

function ENT:PredictedFinishMove( owner , movedata )
	if self:GetActive() then
		
	end
end

--use this to calculate the position on the parent because I can't be arsed to deal with source's parenting bullshit with local angles and position
--plus this is also called during that parenting position recompute, so it's perfect

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

function ENT:GetCustomParentOrigin( ply )
	--Jvs:	I put this here because since the entity moves to the player bone matrix, it'll only be updated on the client
	--		when the player is actally drawn, or his bones are setup again ( which happens before a draw anyway )
	
	if CLIENT and ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then
		ply:SetupBones()
	end
	local boneid = ply:LookupBone( self.AttachmentInfo.BoneName )
	
	if not boneid then return end
	
	local matrix = self:GetControllingPlayer():GetBoneMatrix( boneid )
	
	if not matrix then return end
	
	return LocalToWorld( self.AttachmentInfo.OffsetVec , self.AttachmentInfo.OffsetAng , matrix:GetTranslation() , matrix:GetAngles() )
end

function ENT:CalcAbsolutePosition( pos , ang )
	if IsValid( self:GetControllingPlayer() ) then
		return self:GetCustomParentOrigin( self:GetControllingPlayer() )
	end
end



if SERVER then
	function ENT:OnAttach( ply )
		self:SetActive( false )
		self:SetNoDraw( true )
	end
	
	function ENT:OnDrop( ply )
		--surely don't want to keep the noises up
		self:SetActive( false )
		self:SetNoDraw( false )
	end
	
else
	--[[
		NOTE:	since we're parenting ourselves to the player, internally the parent is going to be redrawn invisibly before we do,
				so technically, it should be safe to draw ourselves attached to the player bones
				
				
				
				if this doesn't work, hook up PostPlayerDraw like I do for most of my stuff
	]]
	
	function ENT:CanDraw()
		if self:GetControllingPlayer() == LocalPlayer() then
			return LocalPlayer():ShouldDrawLocalPlayer()
		else
			return true
		end
	end
	
	function ENT:DrawOnPlayer( ply )
		if IsValid( self:GetControllingPlayer() ) and self:GetControllingPlayer() == ply then
			self:DrawModel()
		end
	end
	
	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
			if self:GetActive() then
				self:DrawJetpackFire( self:GetPos() + self:GetAngles():Up() * 10 , self:GetAngles():Up() , 0.25 )
				self:DrawJetpackSmoke( self:GetPos() + self:GetAngles():Up() * 10 , self:GetAngles():Up() , 0.2 )
			end
		end
	end
	
	ENT.MatHeatWave		= Material( "sprites/heatwave" )
	ENT.MatFire			= Material( "effects/fire_cloud1" )
	
	function ENT:DrawTranslucent( flags )
		--self:Draw( flags )
		
		if self:CanDraw() and self:GetActive() then
			--TODO: fire effects and smoke particles
			--self:drawFire(self:GetPos(),self:GetAngles():Up(),0.2)
		end
	end
	
	
	--copied straight from the thruster code
	
	function ENT:DrawJetpackFire( pos , normal , scale , vOffset2 )
		local vOffset = pos or vector_origin
		local vNormal = normal or vector_origin

		local scroll = 1000 + (CurTime() * -10)
		
		local Scale = scale or 1
		
		render.SetMaterial( self.MatFire )
		
		render.StartBeam( 3 )
			render.AddBeam( vOffset, 8 * Scale, scroll, Color( 0, 0, 255, 128) )
			render.AddBeam( vOffset + vNormal * 60 * Scale, 32 * Scale, scroll + 1, Color( 255, 255, 255, 128) )
			render.AddBeam( vOffset + vNormal * 148 * Scale, 32 * Scale, scroll + 3, Color( 255, 255, 255, 0) )
		render.EndBeam()
		
		scroll = scroll * 0.5
		
		render.UpdateRefractTexture()
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( vOffset, 8 * Scale, scroll, Color( 0, 0, 255, 128) )
			render.AddBeam( vOffset + vNormal * 32 * Scale, 32 * Scale, scroll + 2, Color( 255, 255, 255, 255) )
			render.AddBeam( vOffset + vNormal * 128 * Scale, 48 * Scale, scroll + 5, Color( 0, 0, 0, 0) )
		render.EndBeam()
		
		
		scroll = scroll * 1.3
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( vOffset, 8 * Scale, scroll, Color( 0, 0, 255, 128) )
			render.AddBeam( vOffset + vNormal * 60 * Scale, 16 * Scale, scroll + 1, Color( 255, 255, 255, 128) )
			render.AddBeam( vOffset + vNormal * 148 * Scale, 16 * Scale, scroll + 3, Color( 255, 255, 255, 0) )
		render.EndBeam()
	end
	
	function ENT:DrawJetpackSmoke( pos , normal , scale )
		
		if not self.ParticleEmitter then 
			self.ParticleEmitter = ParticleEmitter( pos )
		end
		
		self.NextParticle = self.NextParticle or CurTime()
		
		
		if self.NextParticle >= CurTime() then return end
		self.NextParticle = CurTime() + 0.01
		
		local particle = self.ParticleEmitter:Add("particle/particle_noisesphere", pos )
		if not particle then return end
		particle:SetVelocity( normal * 100 )
		particle:SetDieTime( 0.5 )
		particle:SetStartAlpha( 255 )
		particle:SetEndAlpha( 0 )
		particle:SetStartSize( 4 )
		particle:SetEndSize( 16 )
		particle:SetRoll( math.Rand( -10,10  ) )
		particle:SetRollDelta( math.Rand( -0.2, 0.2 ) )
		particle:SetColor( 200 , 200 , 200 )
		
	end
	
end

function ENT:OnRemove()
	--TODO: remove the sounds on both client and server, in case we got removed while the player was using us
	--happens during a mass cleanup
	if self.JetpackSound then
		self.JetpackSound:Stop()
	end
end