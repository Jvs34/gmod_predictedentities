AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Long jump module"

if CLIENT then
	language.Add( "sent_longjump" , ENT.PrintName )
else
	
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
	name = "longjump.execute",
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
		self:SetInButton( IN_JUMP )
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		self:SetLongJumpSpeed( 350 )
		
		self:SetMaxHealth( 100 )
		self:SetHealth( self:GetMaxHealth() )
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Bool" , "LongJumping" )
	self:DefineNWVar( "Float" , "LongJumpSpeed" , true , "The speed to apply on a long jump" , 1 , 1000 )
	self:DefineNWVar( "Float" , "LongJumpAnimCycle" )
end

function ENT:Think()
	return BaseClass.Think( self )
end

--cancel the animation cycle immediately if there's gestures that rely on a holdtype or whatever on the player
--but only if it's being carried by the localplayer to prevent animation fuck ups on other players ( since they will do it serverside and on their client )
--AKA PREDICTION, OK? Although I don't know if I can even set these variables here due to the prediction errors fallback, worth a try

function ENT:HandleAnimationEventOverride( ply , event , data )
	
	--this player is outside of prediction shit, don't even bother
	if CLIENT and not self:IsCarriedByLocalPlayer() then
		return
	end
	
	if self:IsLongJumping() and not self:IsAnimationDone() and event ~= PLAYERANIMEVENT_JUMP then
		self:SetLongJumpAnimCycle( 1 )
	end
end

function ENT:PredictedThink( owner , movedata )
	if self:IsLongJumping() and not self:IsAnimationDone() then
		local cycle = self:GetLongJumpAnimCycle()
		cycle = ( cycle + 1.5 * FrameTime() ) % 1	--TODO: tweak the cycle speed
		self:SetLongJumpAnimCycle( math.Clamp( cycle , 0 , 1 ) )
	end
end

function ENT:PredictedMove( owner , data )
	
	--IN_DUCK check is a duplicate of :Crouching perhaps?
	
	if not self:GetLongJumping() and owner:OnGround() and owner:Crouching() and owner:KeyDown( IN_DUCK ) and self:IsKeyDown() then
		
		local forward = data:GetMoveAngles():Forward()
		
		if data:GetVelocity():Length() > 50 then
			self:SetLongJumping( true )
			self:EmitPESound( "HL2Player.SprintStart" , nil , nil , nil , nil , true )
			self:SetLongJumpAnimCycle( 0 )
			owner:ViewPunch( Angle( -5 , 0 , 0 ) )
			
			local vel = forward * self:GetLongJumpSpeed() * 1.6
			vel.z = math.sqrt( 2 * sv_gravity:GetFloat() * 56 )	--hl2's gravity is 600, and 800 is hl1's ( I guess technically quake's, and then tf, hl1 and tfc )
			--the 56 is in theory hl1's jump power? gotta test this and replace it with the player's jump power
			
			data:SetVelocity( vel )	--* FrameTime() ? probably not, this is pretty much just an impulse, no need to gradually apply it
		end
	end
end

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
	self:SetLongJumping( false )
	self:SetLongJumpAnimCycle( 1 )
end

function ENT:IsLongJumping()
	return self:GetLongJumping() and not self:GetControllingPlayer():OnGround()
end

function ENT:IsAnimationDone()
	return self:GetLongJumpAnimCycle() >= 1
end

function ENT:ResetVars()
	self:SetLongJumping( false )
	self:SetLongJumpAnimCycle( 1 )
end

if SERVER then
	
	function ENT:OnAttach( ply )
		self:ResetVars()
	end

	function ENT:OnDrop( ply , forced )
		self:ResetVars()
	end

	function ENT:OnInitPhysics( physobj )
		if IsValid( physobj ) then
			physobj:SetMass( 75 )
		end
		self:SetCollisionGroup( COLLISION_GROUP_NONE )
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
		end
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
	end
	
end

function ENT:HandleMainActivityOverride( ply , velocity )
	--do the unarmed swimming animation, should be kind of similar to the hl1 jumping 
	if self:IsLongJumping() then
		
		local idealact = ACT_INVALID
		
		--once we've done a full unarmed swimming cycle revert to the armed one, if we have a weapon
		if IsValid( ply:GetActiveWeapon() ) and self:IsAnimationDone() then
			idealact = ACT_MP_SWIM
		else
			idealact = ACT_HL2MP_IDLE + 9
		end
		
		return idealact , ACT_INVALID
	end
end

function ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
	if self:IsLongJumping() then
		--once we've done a full unarmed swimming cycle revert to the armed one, if we have a weapon
		if IsValid( ply:GetActiveWeapon() ) and self:IsAnimationDone() then
			ply:SetCycle( 0 )
			ply:SetPlaybackRate( 0 )
		else
			ply:SetCycle( self:GetLongJumpAnimCycle() )
			ply:SetPlaybackRate( 0 )
		end
		
		return true
	end
end