AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Jetpack"

if CLIENT then
	ENT.MatHeatWave		= Material( "sprites/heatwave" )
	ENT.MatFire			= Material( "effects/fire_cloud1" )
	
	AccessorFunc( ENT , "WingClosure" , "WingClosure" )
	AccessorFunc( ENT , "WingClosureStartTime" , "WingClosureStartTime" )
	AccessorFunc( ENT , "WingClosureEndTime" , "WingClosureEndTime" )
	AccessorFunc( ENT , "NextParticle" , "NextParticle" )
	AccessorFunc( ENT , "LastActive" , "LastActive" )
	
	ENT.MaxEffectsSize = 0.25
	ENT.MinEffectsSize = 0.1
	
	ENT.JetpackWings = {
		Scale = 0.4,
		Model = Model( "models/xqm/jettailpiece1.mdl" ),
		{
			OffsetVec = Vector( 0 , -9 , 0 ),
			OffsetAng = Angle( 0 , 0 , 90 ),
		},
		{
			OffsetVec = Vector( 0 , 10 , 0 ),
			OffsetAng = Angle( 180 , 0 , -90 ),
		},
	}
	
	ENT.JetpackFireBlue = Color( 0 , 0 , 255 , 128 )
	ENT.JetpackFireWhite = Color( 255 , 255 , 255 , 128 )
	ENT.JetpackFireNone = Color( 255 , 255 , 255 , 0 )
	ENT.JetpackFireRed = Color( 255 , 128 , 128 , 255 )
	
	language.Add( "sent_jetpack" , ENT.PrintName )
else
	
	ENT.StandaloneApeShitAngular = Vector( 0 , 30 , 10 )	--do a corkscrew
	ENT.StandaloneApeShitLinear = Vector( 0 , 0 , 0 )
	
	ENT.StandaloneAngular = vector_origin
	ENT.StandaloneLinear = Vector( 0 , 0 , 0 )
	
	ENT.ShowPickupNotice = true
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
	level = 75,
	sound = "^thrusters/jet02.wav"
})

local sv_gravity = GetConVar "sv_gravity"

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 36

	local ent = ents.Create( ClassName )
	ent:SetSlotName( ClassName )	--this is the best place to set the slot, don't modify it dynamically ingame
	ent:SetPos( SpawnPos )
	ent:SetAngles( Angle( 0 , 0 , 180 ) )
	ent:Spawn()
	return ent

end

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		
		self:SetMaxHealth( 100 )
		self:SetHealth( self:GetMaxHealth() )
		
		self:SetInfiniteFuel( true )
		self:SetMaxFuel( 100 )
		self:SetFuel( self:GetMaxFuel() )
		self:SetFuelDrain( 10 )	--drain in seconds
		self:SetFuelRecharge( 15 )	--recharge in seconds
		self:SetActive( false )
		self:SetGoneApeshit( math.random( 0 , 100 ) > 95 ) --little chance that on spawn we're gonna be crazy!
		self:SetGoneApeshitTime( 0 )
		
		self:SetDoGroundSlam( false )
		self:SetAirResistance( 2.5 )
		self:SetRemoveGravity( false )
		self:SetJetpackSpeed( 224 )
		self:SetJetpackStrafeSpeed( 600 )
		self:SetJetpackVelocity( 1200 )
		self:SetJetpackStrafeVelocity( 1200 )
	else
		self:SetLastActive( false )
		self:SetWingClosure( 0 )
		self:SetWingClosureStartTime( 0 )
		self:SetWingClosureEndTime( 0 )
		self:SetNextParticle( 0 )
	end
	
	self:SetCustomCollisionCheck( true )
	self:InstallHook( "ShouldCollide" , self.HandleShouldCollide )
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )

	self:DefineNWVar( "Bool" , "Active" )
	self:DefineNWVar( "Bool" , "GoneApeshit" , true )	--set either when the owner dies with us active, or when we're being shot at
	self:DefineNWVar( "Bool" , "RemoveGravity" )
	self:DefineNWVar( "Bool" , "InfiniteFuel" , true , "Infinite Fuel" )
	self:DefineNWVar( "Bool" , "DoGroundSlam" )
	
	self:DefineNWVar( "Float" , "Fuel" )
	self:DefineNWVar( "Float" , "MaxFuel" )	--don't modify the max amount, the drain scales anyway, set to -1 to disable the fuel drain
	self:DefineNWVar( "Float" , "FuelDrain" , true , "Seconds to drain fuel" , 1 , 60 ) --how many seconds it's gonna take to drain all the fuel
	self:DefineNWVar( "Float" , "FuelRecharge" , true , "Seconds to recharge the fuel" , 1 , 60 ) --how many seconds it should take to fully recharge this
	self:DefineNWVar( "Float" , "AirResistance" , true , "Air Resistance" , 0 , 10 )
	self:DefineNWVar( "Float" , "GoneApeshitTime" ) --only used if infinite fuel is on
	
	self:DefineNWVar( "Int" , "JetpackSpeed" , true , "Jetpack idle upward speed" , 1 , 1000 )
	self:DefineNWVar( "Int" , "JetpackStrafeSpeed" , true , "Jetpack idle side speed" , 1 , 1000 )
	self:DefineNWVar( "Int" , "JetpackVelocity" , true , "Jetpack active upward speed" , 1 , 3000 )
	self:DefineNWVar( "Int" , "JetpackStrafeVelocity" , true , "Jetpack active side speed" , 1 , 3000 )
	
end

function ENT:HandleFly( predicted , owner , movedata , usercmd )
	self:SetActive( self:CanFly( owner , movedata ) )
	
	--we have infinite fuel and the apeshit timeout hasn't been set, do it now
	--this is most useful because I CBA to do that everytime ok?
	--also it's serverside only because we only set the apeshit on the server anyway
	
	if SERVER then
		if self:GetGoneApeshit() and self:GetGoneApeshitTime() == 0 and self:GetInfiniteFuel() then
			self:SetGoneApeshitTime( CurTime() + 5 )
		end
	end
	
	--the check below has to be done with prediction on the client!
	
	if CLIENT and not predicted then
		return
	end
	
	--fixes a bug where if you set goneapeshit manually via the contextmenu and the physobj is asleep it wouldn't apply the simulated forces
	if SERVER and not predicted and self:GetGoneApeshit() then
		local physobj = self:GetPhysicsObject()
		if IsValid( physobj ) and physobj:IsAsleep() then
			physobj:Wake()
		end
	end
	
	--if we have an apeshit timeout, calm us down ( this doesn't check for infinite fuel, in case we did this manually )
	if self:GetGoneApeshit() and self:GetGoneApeshitTime() ~= 0 and self:GetGoneApeshitTime() <= CurTime() then
		self:SetGoneApeshit( false )
		self:SetGoneApeshitTime( 0 )
	end
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

	local fueltime = self:GetActive() and self:GetFuelDrain() or self:GetFuelRecharge()

	local fuelrate = self:GetMaxFuel() / ( fueltime / ft )

	if self:GetActive() then
		fuelrate = fuelrate * -1

		if self:GetGoneApeshit() then
			--drain twice as much fuel if we're going craaaazy
			fuelrate = fuelrate * 2
		end
		
		--don't drain any fuel when infinite fuel is on, but still allow recharge
		if self:GetInfiniteFuel() then
			fuelrate = 0
		end
	else
		--recharge in different ways if we have an owner or not, because players might drop and reequip the jetpack to exploit the recharging
		if IsValid( self:GetControllingPlayer() ) then
			--can't recharge until our owner is on the ground!
			--prevents the player from tapping the jump button to fly and recharge at the same time
			if not self:GetControllingPlayer():OnGround() then
				fuelrate = 0
			end
		else
			--only recharge if our physobj is sleeping and it's valid ( should never be invalid in the first place )
			local physobj = self:GetPhysicsObject()
			if not IsValid( physobj ) or not physobj:IsAsleep() then
				fuelrate = 0
			end
		end
	end
	
	self:SetFuel( math.Clamp( self:GetFuel() + fuelrate , 0 , self:GetMaxFuel() ) )

	--we exhausted all of our fuel, chill out if we're crazy
	if not self:HasFuel() and self:GetGoneApeshit() then
		self:SetGoneApeshit( false )
	end
end

function ENT:HandleSounds( predicted )
	if not predicted and CLIENT then
		self.JetpackSound = nil
		return
	end

	--create the soundpatch if it doesn't exist, it might happen on the client sometimes since it's garbage collected

	if not self.JetpackSound then
		self.JetpackSound = CreateSound( self, "jetpack.thruster_loop" )
	end

	if self:GetActive() then
		local pitch = 125
		
		if self:GetGoneApeshit() then
			pitch = 175
		end
		
		self.JetpackSound:PlayEx( 0.5  , pitch )
	else
		self.JetpackSound:Stop()
	end
end

function ENT:HasFuel()
	return self:GetFuel() > 0
end

function ENT:GetFuelFraction()
	return self:GetFuel() / self:GetMaxFuel()
end

function ENT:CanFly( owner , mv )
	
	
	if IsValid( owner ) then
	
		--don't care about player inputs in this case, the player's jetpack is going craaazy
		
		if self:GetGoneApeshit() then
			return owner:WaterLevel() == 0 and owner:GetMoveType() == MOVETYPE_WALK and self:HasFuel()
		end
		
		return ( mv:KeyDown( IN_JUMP ) or mv:KeyDown( IN_DUCK ) or mv:KeyDown( IN_SPEED ) ) and not owner:OnGround() and owner:WaterLevel() == 0 and owner:GetMoveType() == MOVETYPE_WALK and owner:Alive() and self:HasFuel()
	end

	--making it so the jetpack can also fly on its own without an owner ( in the case we want it go go nuts if the player dies or some shit )
	if self:GetGoneApeshit() then
		return self:WaterLevel() == 0 and self:HasFuel()
	end

	return false
end

function ENT:Think()

	--still act if we're not being held by a player
	if not self:IsCarried() then
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

function ENT:PredictedSetupMove( owner , mv , usercmd )
	
	self:HandleFly( true , owner , mv , usercmd )
	self:HandleFuel( true )
	self:HandleSounds( true )
	
	if self:GetActive() then
		
		local vel = mv:GetVelocity()
		
		if mv:KeyDown( IN_JUMP ) and vel.z < self:GetJetpackSpeed() then

			-- Apply constant jetpack_velocity
			
			vel.z = vel.z + self:GetJetpackVelocity() * FrameTime()
		
		elseif mv:KeyDown( IN_SPEED ) and vel.z < 0 then

			-- Apply just the right amount of thrust
			
			vel.z = math.Approach( vel.z , 0 , self:GetJetpackVelocity() * FrameTime() )

		end
		
		
		
		-- Quickly descend to do a ground slam, don't check for the velocity cap, we want to slam down as fast as we can
		
		self:SetDoGroundSlam( mv:KeyDown( IN_DUCK ) )
		
		if mv:KeyDown( IN_DUCK ) then
			vel.z = vel.z - self:GetJetpackVelocity() * FrameTime()
		end

		--
		-- Remove gravity when velocity is supposed to be zero for hover mode
		--

		if vel.z == 0 then

			self:SetRemoveGravity( true )

			vel.z = vel.z + sv_gravity:GetFloat() * 0.5 * FrameTime()

		end

		--
		-- Apply movement velocity
		--
		
		local move_vel = Vector( 0, 0, 0 )

		local ang = mv:GetMoveAngles()
		ang.p = 0

		move_vel:Add( ang:Right() * mv:GetSideSpeed() )
		move_vel:Add( ang:Forward() * mv:GetForwardSpeed() )

		move_vel:Normalize()
		move_vel:Mul( self:GetJetpackStrafeVelocity() * FrameTime() )

		if vel:Length2D() < self:GetJetpackStrafeSpeed() then

			vel:Add( move_vel )

		end
		
		--TODO: goneapeshit stuff, do it before air resistance
		
		if self:GetGoneApeshit() then
			--boost us in the direction the jetpack is facing in the world ( actual third person angles )
			--ragdolling the user and attaching us to the ragdoll would be quite expensive and wouldn't be worth it
			--as cool as that might look, that might also break stuff in other gamemodes
			
			local addvel = self:GetAngles():Up() * -1 * self:GetJetpackVelocity() * FrameTime()
			vel:Add( addvel )
		end
		
		--
		-- Apply air resistance
		--
		vel.x = math.Approach( vel.x, 0, FrameTime() * self:GetAirResistance() * vel.x )
		vel.y = math.Approach( vel.y, 0, FrameTime() * self:GetAirResistance() * vel.y )
	
		--
		-- Write our calculated velocity back to the CMoveData structure
		--
		mv:SetVelocity( vel )

		mv:SetForwardSpeed( 0 )
		mv:SetSideSpeed( 0 )
		mv:SetUpSpeed( 0 )
		
		-- Removes the crouch button from the movedata, effectively disabling the crouching behaviour
		
		mv:SetButtons( bit.band( mv:GetButtons(), bit.bnot( IN_DUCK ) ) )
	
	end
end

function ENT:PredictedThink( owner , movedata )
end

function ENT:PredictedMove( owner , data )
	if self:GetActive() and self:GetGoneApeshit() then
		owner:SetGroundEntity( NULL )
	end
end

function ENT:PredictedFinishMove( owner , movedata )
	if self:GetActive() then
		
		--
		-- Remove gravity when velocity is supposed to be zero for hover mode
		--
		if self:GetRemoveGravity() then
			local vel = movedata:GetVelocity()

			vel.z = vel.z + sv_gravity:GetFloat() * 0.5 * FrameTime()

			movedata:SetVelocity( vel )

			self:SetRemoveGravity( false )
		end
		
	end
end

local	SF_PHYSEXPLOSION_NODAMAGE			=	0x0001
local	SF_PHYSEXPLOSION_PUSH_PLAYER		=	0x0002
local	SF_PHYSEXPLOSION_RADIAL				=	0x0004
local	SF_PHYSEXPLOSION_TEST_LOS			=	0x0008
local	SF_PHYSEXPLOSION_DISORIENT_PLAYER	=	0x0010

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
	
	local dogroundslam = self:GetDoGroundSlam()
	self:SetDoGroundSlam( false )
	
	if dogroundslam and speed > 500 then
		
		ply:EmitSound( "Player.FallDamage" )
		--self:EmitPESound( "" , nil , nil , nil , nil , true )	--find the sound smod uses when the player hits the ground in smod
		
		local fraction = self:GetJetpackStrafeVelocity() / speed	--because the fall speed might be higher than the jetpack one
		
		local effect = EffectData()
		effect:SetEntity( ply )
		effect:SetOrigin( ply:WorldSpaceCenter() )	--apparently the player is considered in the ground in this hook and stuff doesn't spawn
		effect:SetScale( 128 )
		util.Effect( "ThumperDust" , effect , true )	--todo, make our own effect where the particles start from the player and expand in a circle
														--can even copy the code from c_thumper_dust
		if SERVER then
			--TODO: get the code from the sdk and replicate this on my own
			ply:LagCompensation( true )
			
			local physexpl = ents.Create( "env_physexplosion" )
			if IsValid( physexpl ) then
				physexpl:SetPos( ply:WorldSpaceCenter() )
				physexpl:SetKeyValue( "spawnflags" , bit.bor( SF_PHYSEXPLOSION_NODAMAGE , SF_PHYSEXPLOSION_RADIAL , SF_PHYSEXPLOSION_TEST_LOS ) )
				physexpl:SetKeyValue( "magnitude" , 500 * fraction )
				physexpl:SetKeyValue( "radius" , 250 )
				physexpl:Spawn()
				physexpl:Fire( "Explode" , "" , 0 )
				physexpl:Fire( "Kill" , "" , 0.1 )
			end
			
			ply:LagCompensation( false )
		end
		
		ply:AnimRestartGesture( GESTURE_SLOT_JUMP, ACT_LAND, true )
		return true	--override the fall damage and other hooks
	end
end

if SERVER then
	
	function ENT:OnTakeDamage( dmginfo )
		--we're already dead , might happen if multiple jetpacks explode at the same time
		if self:Health() <= 0 then
			return
		end
		
		self:TakePhysicsDamage( dmginfo )
		
		local oldhealth = self:Health()
		
		local newhealth = math.Clamp( self:Health() - dmginfo:GetDamage() , 0 , self:GetMaxHealth() )
		self:SetHealth( newhealth )
		
		if self:Health() <= 0 then
			--maybe something is relaying damage to the jetpack instead, an explosion maybe?
			if IsValid( self:GetControllingPlayer() ) then
				self:Drop( true )
			end
			self:Detonate( dmginfo:GetAttacker() )
			return
		end
		
		--roll a random, if we're not being held by a player and the random succeeds, go apeshit
		if dmginfo:GetDamage() > 3 and not self:GetGoneApeshit() then
			local rand = math.random( 1 , 10 )
			if rand <= 2 then
				self:SetGoneApeshit( true )
			end
		end
	end
	
	function ENT:OnAttach( ply )
		self:SetDoGroundSlam( false )
		self:SetSolid( SOLID_BBOX )	--we can still be hit when on the player's back
	end

	function ENT:OnDrop( ply , forced )
		if IsValid( ply ) and not ply:Alive() then
			--when the player dies while still using us, keep us active and let us fly with physics until
			--our fuel runs out
			if self:GetActive() then
				self:SetGoneApeshit( true )
			end
		else
			self:SetActive( false )
		end
		
	end

	function ENT:OnInitPhysics( physobj )
		if IsValid( physobj ) then
			physobj:SetMass( 75 )
			self:StartMotionController()
		end
		self:SetCollisionGroup( COLLISION_GROUP_NONE )
		--self:SetCollisionGroup( COLLISION_GROUP_WEAPON )	--set to COLLISION_GROUP_NONE to reenable collisions against players and npcs
	end
	
	function ENT:OnRemovePhysics( physobj )
		self:StopMotionController()
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
		--self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
	end
	
	function ENT:PhysicsSimulate( physobj , delta )
		
		--no point in applying forces and stuff if something is holding our physobj
		
		if self:GetActive() and not self:GetBeingHeld() then
			physobj:Wake()
			local force = self.StandaloneLinear
			local angular = self.StandaloneAngular
			
			if self:GetGoneApeshit() then
				force = self.StandaloneApeShitLinear
				angular = self.StandaloneApeShitAngular
			end
			
			force.z = -self:GetJetpackVelocity()
			
			return angular * physobj:GetMass() , force * physobj:GetMass() , SIM_LOCAL_FORCE
		end
	end
	
	function ENT:PhysicsCollide( data , physobj )
		--taken straight from valve's code, it's needed since garry overwrote VPhysicsCollision, friction sound is still there though
		--because he didn't override the VPhysicsFriction
		if SERVER then
			--only do this check serverside because if the gravity gun holds us, the clientside collisions still happen
			--and play sounds on regardless of garry's override
			if data.DeltaTime >= 0.05 and data.Speed >= 70 then
				local volume = data.Speed * data.Speed * ( 1 / ( 320 * 320 ) )
				if volume > 1 then
					volume = 1
				end
				
				--TODO: find a better impact sound for this model
				self:EmitSound( "SolidMetal.ImpactHard" , nil , nil , volume , CHAN_BODY )
			end
			
			if self:CheckDetonate( data , physobj ) then
				self:Detonate()
			end
		end
	end
	
	--can't explode on impact if we're not active
	function ENT:CheckDetonate( data , physobj )
		return self:GetActive() and data.Speed > 500 and not self:GetBeingHeld()
	end
	
	function ENT:Detonate( attacker )
		--you never know!
		if self:IsEFlagSet( EFL_KILLME ) then 
			return 
		end
		
		self:Remove()
		
		local fuel = self:GetFuel()
		local atk = IsValid( attacker ) and attacker or self
		
		--check how much fuel was left when we impacted
		local dmg = 1.5 * fuel
		local radius = 2.5 * fuel
		
		util.BlastDamage( self , atk , self:GetPos() , radius , dmg )
		util.ScreenShake( self:GetPos() , 1.5 , dmg , 0.25 , radius * 2 )
		
		local effect = EffectData()
		effect:SetOrigin( self:GetPos() )
		effect:SetMagnitude( dmg )	--this is actually the force of the explosion
		effect:SetFlags( bit.bor( 0x80 , 0x20 ) ) --NOFIREBALLSMOKE, ROTATE
		util.Effect( "Explosion" , effect )
	end

else

	function ENT:Draw( flags )
		local pos , ang = self:GetCustomParentOrigin()
		
		--even though the calcabsoluteposition hook should already prevent this, it doesn't on other players
		--might as well not give it the benefit of the doubt in the first place
		if pos and ang then
			self:SetPos( pos )
			self:SetAngles( ang )
			self:SetupBones()
		end
		
		self:DrawModel( flags )
		
		self:DrawWings( flags )
		
		local atchpos , atchang = self:GetEffectsOffset()
		
		local effectsscale = self:GetEffectsScale()
		
		--technically we shouldn't draw the fire from here, it should be done in drawtranslucent
		--but since we draw from the player and he's not translucent this won't get called despite us being translucent
		--might as well just set us to opaque
		
		if self:GetActive() then	-- and bit.band( flags , STUDIO_TRANSPARENCY ) ~= 0 then
			self:DrawJetpackFire( atchpos , atchang , effectsscale )
		end
		
		self:DrawJetpackSmoke( atchpos , atchang , effectsscale )
	end
	
	--the less fuel we have, the smaller our particles will be
	function ENT:GetEffectsScale()
		return Lerp( self:GetFuel() / self:GetMaxFuel() , self.MinEffectsSize , self.MaxEffectsSize )
	end
	
	function ENT:GetEffectsOffset()
		local angup = self:GetAngles():Up()
		return self:GetPos() + angup * 10 , angup
	end
	
	function ENT:CreateWing()
		local wing = ClientsideModel( self.JetpackWings.Model )
		wing:SetModelScale( self.JetpackWings.Scale , 0 )
		wing:SetNoDraw( true )
		return wing
	end
	
	function ENT:HandleWings()
		if not IsValid( self.LeftWing ) then
			self.LeftWing = self:CreateWing()
		end

		if not IsValid( self.RightWing ) then
			self.RightWing = self:CreateWing()
		end

		if self:GetLastActive() ~= self:GetActive() then
			self:SetWingClosureStartTime( UnPredictedCurTime() )
			self:SetWingClosureEndTime( UnPredictedCurTime() + 0.25 )
			self:SetLastActive( self:GetActive() )
		end
		
		--do the math time fraction from the closure time to the UnPredictedCurTime,
		--and set everything on the wingclosure so that we can use it on a Lerp later during the draw
		if self:GetWingClosureStartTime() ~= 0 and self:GetWingClosureEndTime() ~= 0 then
			local starttime = self:GetWingClosureStartTime()
			local endtime = self:GetWingClosureEndTime()
			
			if not self:GetActive() then
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
	
	function ENT:DrawWings( flags )
		local pos = self:GetPos()
		local ang = self:GetAngles()

		self.WingMatrix = Matrix()
		--TODO: reset the scale to Vector( 1 , 1 , 1 ) instead of recreating the matrix every frame
		local dist = Lerp( self:GetWingClosure() , -15 , 0 )
		self.WingMatrix:SetTranslation( Vector( 0 ,0 , dist ) )	--how far inside the jetpack we should go to hide our scaled down wings
		self.WingMatrix:Scale( Vector( 1 , 1 , self:GetWingClosure() ) ) --our scale depends on the wing closure
		
		if IsValid( self.LeftWing ) then
			local gpos , gang = LocalToWorld( self.JetpackWings[1].OffsetVec , self.JetpackWings[1].OffsetAng , pos , ang )
			self.LeftWing:SetRenderOrigin( gpos )
			self.LeftWing:SetRenderAngles( gang )
			self.LeftWing:EnableMatrix( "RenderMultiply" , self.WingMatrix )
			self.LeftWing:DrawModel( flags )
		end

		if IsValid( self.RightWing ) then
			local gpos , gang = LocalToWorld( self.JetpackWings[2].OffsetVec , self.JetpackWings[2].OffsetAng , pos , ang )
			self.RightWing:SetRenderOrigin( gpos )
			self.RightWing:SetRenderAngles( gang )
			self.RightWing:EnableMatrix( "RenderMultiply" , self.WingMatrix )
			self.RightWing:DrawModel( flags )
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

	--copied straight from the thruster code
	function ENT:DrawJetpackFire( pos , normal , scale )
		local scroll = 1000 + UnPredictedCurTime() * -10
		
		--the trace makes sure that the light or the flame don't end up inside walls
		--although it should be cached somehow, and only do the trace every tick
		
		local tracelength = 148 * scale
		
		local tr = {
			start = pos,
			endpos = pos + normal * tracelength,
			mask = MASK_OPAQUE,
			filter = self:GetControllingPlayer(),
		}
		tr.output = tr
		
		util.TraceLine( tr )
		
		-- tr.Fraction * ( 60 * scale ) / tracelength
		
		
		--TODO: fix the middle segment not being proportional to the tracelength ( and Fraction )
		
		render.SetMaterial( self.MatFire )

		render.StartBeam( 3 )
			render.AddBeam( pos, 8 * scale , scroll , self.JetpackFireBlue )
			render.AddBeam( pos + normal * 60 * scale , 32 * scale , scroll + 1, self.JetpackFireWhite )
			render.AddBeam( tr.HitPos , 32 * scale , scroll + 3, self.JetpackFireNone )
		render.EndBeam()

		scroll = scroll * 0.5

		render.UpdateRefractTexture()
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( pos, 8 * scale , scroll , self.JetpackFireBlue )
			render.AddBeam( pos + normal * 32 * scale, 32 * scale , scroll + 2, color_white )
			render.AddBeam( tr.HitPos, 48 * scale , scroll + 5, self.JetpackFireNone )
		render.EndBeam()


		scroll = scroll * 1.3
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( pos , 8 * scale , scroll, self.JetpackFireBlue )
			render.AddBeam( pos + normal * 60 * scale , 16 * scale , scroll + 1 , self.JetpackFireWhite )
			render.AddBeam( tr.HitPos , 16 * scale , scroll + 3 , self.JetpackFireNone )
		render.EndBeam()
		
		local light = DynamicLight( self:EntIndex() )
		
		if not light then
			return
		end
		
		light.Pos = tr.HitPos
		light.r = self.JetpackFireRed.r
		light.g = self.JetpackFireRed.g
		light.b = self.JetpackFireRed.b
		light.Brightness = 3
		light.Dir = normal
		light.InnerAngle = -45 --light entities in a cone
		light.OuterAngle = 45 --
		light.Size = 250 * scale -- 125 when the scale is 0.25
		light.Style = 1	--this should do the flicker for us
		light.Decay = 1000
		light.DieTime = UnPredictedCurTime() + 1
	end

	function ENT:DrawJetpackSmoke( pos , normal , scale )
		
		if not self.JetpackParticleEmitter then
			local emittr = ParticleEmitter( pos )
			if not emittr then
				return
			end
			self.JetpackParticleEmitter = emittr
		end

		--to prevent the smoke from drawing inside of the player when he's looking at a mirror, draw it manually if he's the local player
		--this behaviour is disabled if he's not the one actually using the jetpack ( this also happens when the jetpack is dropped and flies off )
		
		local particlenodraw = self:IsCarriedByLocalPlayer()
		
		self.JetpackParticleEmitter:SetNoDraw( particlenodraw )
		
		if self:GetNextParticle() < UnPredictedCurTime() and self:GetActive() then
			local particle = self.JetpackParticleEmitter:Add( "particle/particle_noisesphere", pos )
			if particle then
				--only increase the time on a successful particle
				self:SetNextParticle( UnPredictedCurTime() + 0.01 )
				particle:SetLighting( true )
				particle:SetCollide( true )
				particle:SetBounce( 0.25 )
				particle:SetVelocity( normal * self:GetJetpackSpeed() )
				particle:SetDieTime( 0.1 )
				particle:SetStartAlpha( 150 )
				particle:SetEndAlpha( 0 )
				particle:SetStartSize( 16 * scale )
				particle:SetEndSize( 64 * scale )
				particle:SetRoll( math.Rand( -10 , 10  ) )
				particle:SetRollDelta( math.Rand( -0.2 , 0.2 ) )
				particle:SetColor( 255 , 255 , 255 )
			end
		end
		
		if particlenodraw then
			self.JetpackParticleEmitter:Draw()
		end
	end
	
	
	function ENT:SetupCustomHUDElements( panel )
		
		--TODO: use a quarter of a circle instead
		
		panel.FuelGauge = panel:Add( "DPanel" )
		panel.FuelGauge:SetSize( panel:GetWide() , panel:GetTall() / 4 )
		panel.FuelGauge:Dock( BOTTOM )
		
		panel.FuelGauge.FuelColorEmpty = Color( 255 , 127 ,127 , 255 )
		panel.FuelGauge.FuelColorFilled = Color( 127 , 127 , 255 , 255 )
		panel.FuelGauge.Paint = function( self , w , h )
			surface.SetDrawColor( self.FuelColorEmpty )
			surface.DrawRect( 0 , 0 , w , h )
			
			surface.SetDrawColor( self.FuelColorFilled )
			surface.DrawRect( w * ( 1 - self.FuelFraction ) , 0 , w , h )
		end
	
		panel.CustomThink = function( self )
			self.FuelGauge.FuelFraction = self:GetEntity():GetFuelFraction()
		end
	end

end

function ENT:HandleShouldCollide( ent1 , ent2 )
	if ent1 ~= self then
		return
	end
	
	if IsValid( self:GetControllingPlayer() ) and ( ent2:GetOwner() == self:GetControllingPlayer() or self:GetControllingPlayer() == ent2 ) then
		return false
	end
end

function ENT:HandleMainActivityOverride( ply , velocity )
	if self:GetActive() then
		local vel2d = velocity:Length2D()
		local idealact = -1
		
		if IsValid( ply:GetActiveWeapon() ) then
			idealact = ACT_MP_SWIM--vel2d >= 10 and ACT_MP_SWIM or ACT_MP_SWIM_IDLE
		else
			idealact = ACT_HL2MP_IDLE + 9
		end
		
		return idealact , -1
	end
end

function ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
	if self:GetActive() then
		ply:SetPlaybackRate( 0 )	--don't do the full swimming animation
		return true
	end
end

function ENT:OnRemove()
	--if stopping the soundpatch doesn't work, stop the sound manually
	self:StopSound( "jetpack.thruster_loop" )

	if CLIENT then
		self:RemoveWings()
		if self.JetpackParticleEmitter then
			self.JetpackParticleEmitter:Finish()
			self.JetpackParticleEmitter = nil
		end
	end
	
	BaseClass.OnRemove( self )
end