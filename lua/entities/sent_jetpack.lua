AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.SlotName = "jetpack"
ENT.PrintName = "Jetpack"

if CLIENT then
	ENT.WingModel = Model( "models/xqm/jettailpiece1.mdl" )
	AccessorFunc( ENT , "WingClosure" , "WingClosure" )
	AccessorFunc( ENT , "WingClosureStartTime" , "WingClosureStartTime" )
	AccessorFunc( ENT , "WingClosureEndTime" , "WingClosureEndTime" )
end

--use this to calculate the position on the parent because I can't be arsed to deal with source's parenting bullshit with local angles and position
--plus this is also called during that parenting position recompute, so it's perfect

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

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
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )	--comment to reenable collisions with players and npcs
		self:InitPhysics()

		self:SetMaxFuel( 100 )	--set this to -1 to disable the fuel drain
		self:SetFuel( self:GetMaxFuel() )
		self:SetFuelDrain( 10 )
		self:SetFuelRecharge( 20 )
		hook.Add( "PostPlayerDeath" , self , self.ControllingPlayerDeath )
	else
		self:SetWingClosure( 0 )
		self:SetWingClosureStartTime( 0 )
		self:SetWingClosureEndTime( 0 )
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )

	self:DefineNWVar( "Bool" , "Active" )
	self:DefineNWVar( "Bool" , "GoneApeshit" )	--set when the player using us dies while we're active
	self:DefineNWVar( "Float" , "Fuel" )
	self:DefineNWVar( "Float" , "MaxFuel" )	--don't modify the max amount, the drain scales anyway, set to -1 to disable the fuel drain
	self:DefineNWVar( "Float" , "FuelDrain" ) --how many seconds it's gonna take to drain all the fuel
	self:DefineNWVar( "Float" , "FuelRecharge" ) --how many seconds it should take to fully recharge this
end

function ENT:HandleFly( predicted , owner , movedata , usercmd )
	self:SetActive( self:CanFly( owner , movedata ) )
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

	if self:GetMaxFuel() == -1 then
		self:SetFuel( 1 )	--can't be arsed to add a maxfuel == -1 check in canfly, so this is a workaround
		self:SetGoneApeshit( false )
		return
	end

	local rechargetime = self:GetActive() and self:GetFuelDrain() or self:GetFuelRecharge()

	local rechargerate = self:GetMaxFuel() / ( rechargetime / ft )

	if self:GetActive() then
		rechargerate = rechargerate * -1

		if self:GetGoneApeshit() then
			--drain twice as much fuel if we're going craaaazy
			--no need to stop the recharge rate when we're not active, because then we're not crazy anymore
			rechargerate = rechargerate * 2
		end
	else
		--can't recharge until our owner is on the ground!
		--prevents the player from tapping the jump button to fly and recharge at the same time
		if IsValid( self:GetControllingPlayer() ) then
			if not self:GetControllingPlayer():OnGround() then
				rechargerate = 0
			end
		end
	end

	local clampedchargerate = math.Clamp( self:GetFuel() + rechargerate , 0 , self:GetMaxFuel() )
	self:SetFuel( clampedchargerate )

	--we exhausted all of our fuel, chill out
	if self:GetFuel() <= 0 and self:GetGoneApeshit() then
		self:SetGoneApeshit( false )
	end
end

function ENT:HandleSounds( predicted )
	if not predicted and CLIENT then
		--stop the sound the old controlling player had on the client
		
		if self.JetpackSound then
			self.JetpackSound:Stop()
			self.JetpackSound = nil
		end

		return
	end

	--create the soundpatch if it doesn't exist, it might happen on the client sometimes since it's garbage collected

	if not self.JetpackSound then
		self.JetpackSound = CreateSound( self, "jetpack.thruster_loop" )
	end

	if self:GetActive() then
		--this may actually be pretty bad for performance I believe, since every change to a soundpatch causes a net message to replay the sound
		--with the new parameters
		
		--TODO: check netgraph when running this
		
		local randompitch = 0.25
		
		if predicted then
			randompitch = util.SharedRandom( "JetpackSound", 0.25 , 0.40 )
		else
			randompitch = math.random( 0.25 , 0.40 )
		end
		
		self.JetpackSound:PlayEx( randompitch  , 125 )
	else
		self.JetpackSound:Stop()
	end
end

function ENT:CanFly( owner , mv )
	--To willox, change this if you want to have the hover mode

	if IsValid( owner ) then
		return owner:GetMoveType() == MOVETYPE_WALK and not owner:OnGround() and mv:KeyDown( IN_JUMP ) and owner:Alive() and self:GetFuel() > 0
	end

	--making it so the jetpack can also fly on its own without an owner ( in the case we want it go go nuts if the player dies or some shit )
	if self:GetGoneApeshit() then
		return self:GetFuel() > 0
	end

	return false
end

function ENT:Think()

	--recharge while we're not being held by a player
	if not IsValid( self:GetControllingPlayer() ) then
		self:HandleFly( false )
		self:HandleFuel( false )
		self:HandleSounds( false )
	end

	--animation related stuff should be fine to call here

	if CLIENT then
		self:HandleWings()
	end

	return BaseClass.Think( self )
end

function ENT:PredictedSetupMove( owner , movedata , usercmd )
	self:HandleFly( true , owner , movedata , usercmd )
end

function ENT:PredictedThink( owner , movedata )
	self:HandleFuel( true )
	self:HandleSounds( true )
end

function ENT:PredictedMove( owner , data )
	if self:GetActive() then

		--To Willox: REPLACE ME!
		--this is just some really shitty code I used years ago, can't even be arsed to recode it properly

		local oldspeed=data:GetVelocity()
		local sight=owner:EyeAngles()
		local factor=1.5
		local sidespeed=math.Clamp(data:GetSideSpeed(),-data:GetMaxClientSpeed()*factor,data:GetMaxClientSpeed()*factor)
		local forwardspeed=math.Clamp(data:GetForwardSpeed(),-data:GetMaxClientSpeed()*factor,data:GetMaxClientSpeed()*factor)
		local upspeed=data:GetVelocity().z
		sight.pitch=0
		sight.roll=0
		sight.yaw=sight.yaw-90
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



if SERVER then

	function ENT:ControllingPlayerDeath( ply )
		if IsValid( self:GetControllingPlayer() ) and self:GetControllingPlayer() == ply then
			self:Drop()
		end
	end

	function ENT:OnAttach( ply )
		self:SetGoneApeshit( false )	--someone might be able to catch us midflight!
		self:SetActive( false )
		self:SetNoDraw( true )
	end

	function ENT:OnDrop( ply )
		if IsValid( ply ) and not ply:Alive() then
			--when the player dies while still using us, keep us active and let us fly with physics until
			--our fuel runs out
			if self:GetActive() then
				self:SetGoneApeshit( true )
			end
		else
			self:SetActive( false )
		end
		self:SetNoDraw( false )
	end

	function ENT:OnInitPhysics( physobj )
		if IsValid( physobj ) then
			self:StartMotionController()
		end
	end
	
	function ENT:OnRemovePhysics()
		self:StopMotionController()
	end

	function ENT:PhysicsSimulate( physobj , delta )
		if self:GetGoneApeshit() then
			--TODO:apply an angular spin so that we fly in a corkscrew pattern
			return vector_origin , Vector( 0 , 0 , -1000 ) * physobj:GetMass() , SIM_LOCAL_FORCE
		end
	end
	
	function ENT:PhysicsCollide( data , physobj )
		
		if self:IsEFlagSet( EFL_KILLME ) then return end
		
		if self:CheckDetonate( data , physobj ) then
			self:Detonate()
			return
		end
		
		if data.DeltaTime < 0.05 or data.Speed < 70 then
			return
		end
		
		local volume = speed * speed * ( 1 / ( 320 * 320 ) )
		if volume > 1 then
			volume = 1
		end
		
		self:EmitSound( "SolidMetal.ImpactHard" , nil , nil , volume , CHAN_BODY )
		
	end
	
	function ENT:CheckDetonate( data , physobj )
		return self:GetActive() and self:GetGoneApeshit() and data.Speed > 800
	end
	
	function ENT:Detonate()
		--check how much fuel was left when we impacted
		local dmg = 2 * self:GetFuel()
		local radius = 2.5 * self:GetFuel()
		--do a constant 50 damage for infinite fuel
		
		if self:GetMaxFuel() == -1 then
			dmg = 50
			radius = 250
		end
		
		util.BlastDamage( self , self , self:GetPos() , radius , dmg )
		
		
		self:Remove()
	end

else

	function ENT:Draw( flags )
		if self:CanDraw() then

			self:DrawModel()

			--always draw the wings, because we still need to do the open and close animations
			--regardless if we're active or not

			self:DrawWings()

			--TODO:	create two phx wings and animate them when we switch from inactive to active
			--		there's three options in how to go with it
			--		1) linear movement from inside the jetpack, like buzz lightyears' wings
			--		2) wings are always there but they expand up to the desired length with a bone matrix scale
			--		3) the wings have only have an angular movement, this might look the best

			if self:GetActive() then
				self:DrawJetpackFire( self:GetPos() + self:GetAngles():Up() * 10 , self:GetAngles():Up() , 0.25 )
			end

			self:DrawJetpackSmoke( self:GetPos() + self:GetAngles():Up() * 10 , self:GetAngles():Up() , 0.2 )
		end
	end

	function ENT:CreateWing()

		local wing = ClientsideModel( self.WingModel )
		wing:SetModelScale( 0.4 , 0 )
		wing:SetNoDraw( true )
		return wing
	end
	
	function ENT:HandleWings()
		--TODO: handle the rotations or whatever on the wings that they should draw with
		if not IsValid( self.LeftWing ) then
			self.LeftWing = self:CreateWing()
		end

		if not IsValid( self.RightWing ) then
			self.RightWing = self:CreateWing()
		end

		if self.LastActive ~= self:GetActive() then
			self.LastDirection = self:GetActive()
			self:SetWingClosureStartTime( UnPredictedCurTime() )
			self:SetWingClosureEndTime( UnPredictedCurTime() + 1 )
			self.LastActive = self:GetActive()
		end
		
		--do the math time fraction from the closure time to the UnPredictedCurTime,
		--and set everything on the wingclosure so that we can use it on a Lerp later during the draw
		if self:GetWingClosureStartTime() ~= 0 and self:GetWingClosureEndTime() ~= 0 then
			local starttime = self:GetWingClosureStartTime()
			local endtime = self:GetWingClosureEndTime()
			
			if self.LastDirection == nil then
				self.LastDirection = false
			end
			
			if not self.LastDirection then
				starttime , endtime = endtime , starttime
			end
			
			
			self:SetWingClosure( math.TimeFraction( starttime , endtime , UnPredictedCurTime() ) )
			
			--we're done here, stop calculating the closure
			if self:GetWingClosureEndTime() < UnPredictedCurTime() then
				self:SetWingClosureStartTime( 0 )
				self:SetWingClosureEndTime( 0 )
			end
		end
	end

	function ENT:DrawWings()
		--TODO: draw the wings with the offsets we've gotten from HandleWings

		local pos = self:GetPos()
		local ang = self:GetAngles()

		--temporary offsets

		if IsValid( self.LeftWing ) then
			local gpos , gang = LocalToWorld( Vector( 0 , -9 * self:GetWingClosure(), 0 ) , Angle( 0 , 0 , 90 ) , pos , ang )
			self.LeftWing:SetRenderOrigin( gpos )
			self.LeftWing:SetRenderAngles( gang )
			self.LeftWing:DrawModel()
		end

		if IsValid( self.RightWing ) then
			local gpos , gang = LocalToWorld( Vector( 0 , 10 * self:GetWingClosure() , 0 ) , Angle( 180 , 0 , -90 ) , pos , ang )
			self.RightWing:SetRenderOrigin( gpos )
			self.RightWing:SetRenderAngles( gang )
			self.RightWing:DrawModel()
		end
	end

	function ENT:RemoveWings()
		if IsValid( self.LeftWing ) then
			self.LeftWing:Remove()
		end

		if IsValid( self.RightWing ) then
			self.RightWing:Remove()
		end
	end

	ENT.MatHeatWave		= Material( "sprites/heatwave" )
	ENT.MatFire			= Material( "effects/fire_cloud1" )

	--copied straight from the thruster code

	function ENT:DrawJetpackFire( pos , normal , scale )
		local vOffset = pos or vector_origin
		local vNormal = normal or vector_origin

		local scroll = 1000 + ( CurTime() * -10 )

		local Scale = scale or 1

		render.SetMaterial( self.MatFire )

		render.StartBeam( 3 )
			render.AddBeam( vOffset, 8 * Scale , scroll , Color( 0 , 0 , 255 , 128) )
			render.AddBeam( vOffset + vNormal * 60 * Scale , 32 * Scale , scroll + 1, Color( 255, 255, 255, 128 ) )
			render.AddBeam( vOffset + vNormal * 148 * Scale , 32 * Scale , scroll + 3, Color( 255, 255, 255, 0 ) )
		render.EndBeam()

		scroll = scroll * 0.5

		render.UpdateRefractTexture()
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( vOffset, 8 * Scale , scroll , Color( 0 , 0 , 255 , 128 ) )
			render.AddBeam( vOffset + vNormal * 32 * Scale, 32 * Scale , scroll + 2, Color( 255, 255, 255, 255 ) )
			render.AddBeam( vOffset + vNormal * 128 * Scale, 48 * Scale , scroll + 5, Color( 0, 0, 0, 0) )
		render.EndBeam()


		scroll = scroll * 1.3
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( vOffset , 8 * Scale , scroll, Color( 0 , 0 , 255 , 128 ) )
			render.AddBeam( vOffset + vNormal * 60 * Scale , 16 * Scale , scroll + 1 , Color( 255, 255, 255, 128 ) )
			render.AddBeam( vOffset + vNormal * 148 * Scale , 16 * Scale , scroll + 3 , Color( 255, 255, 255, 0 ) )
		render.EndBeam()
	end

	function ENT:DrawJetpackSmoke( pos , normal , scale )

		--would it be a good idea to actually just render the smoke in local positions and then manually
		--draw it in relative positions? it's not gonna look realistic but I think it'd look better than
		--how it is now

		if not self.JetpackParticleEmitter then
			self.JetpackParticleEmitter = ParticleEmitter( pos )
			--self.JetpackParticleEmitter:SetNoDraw( true )
		end

		self.NextParticle = self.NextParticle or CurTime()



		if self.NextParticle < CurTime() and self:GetActive() then
			self.NextParticle = CurTime() + 0.01

			local particle = self.JetpackParticleEmitter:Add("particle/particle_noisesphere", pos )
			if particle then
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

		--self.JetpackParticleEmitter:SetPos( pos )
		--self.JetpackParticleEmitter:Draw()

	end

end

function ENT:OnRemove()
	--TODO: remove the sounds on both client and server, in case we got removed while the player was using us
	--happens during a mass cleanup
	if self.JetpackSound then
		self.JetpackSound:Stop()
	end

	self:StopSound( "jetpack.thruster_loop" )

	if CLIENT then
		self:RemoveWings()
	end
end