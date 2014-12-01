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
		self:SetKey( 0 )
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		self:SetMaxHealth( 100 )
		self:SetLongJumpSpeed( 350 )
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

function ENT:PredictedSetupMove( owner , mv , usercmd )
end

function ENT:PredictedThink( owner , movedata )
	if self:IsLongJumping() then
		local cycle = self:GetLongJumpAnimCycle()
		cycle = ( cycle + 1.5 * FrameTime() ) % 1
		self:SetLongJumpAnimCycle( math.Clamp( cycle , 0 , 1 ) )
	end
end

function ENT:PredictedMove( owner , data )
	
	if not self:GetLongJumping() and owner:OnGround() and owner:Crouching() and owner:KeyDown( IN_DUCK ) and self:IsKeyDown() then
		
		local forward = data:GetMoveAngles():Forward()
		
		if data:GetVelocity():Length() > 50 then
			self:SetLongJumping( true )
			self:EmitPESound( "HL2Player.SprintStart" , nil , nil , nil , nil , true )
			self:SetLongJumpAnimCycle( 0 )
			owner:ViewPunch( Angle( -5 , 0 , 0 ) )
			
			local vel = forward * self:GetLongJumpSpeed() * 1.6
			vel.z = math.sqrt( 2 * 800 * 56 )
			data:SetVelocity( vel )	--* FrameTime() ? probably not, this is pretty much just an impulse, no need to gradually apply it
		end
	end
end

function ENT:PredictedFinishMove( owner , movedata )
end

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
	self:SetLongJumping( false )
end

function ENT:IsLongJumping()
	return self:GetLongJumping() and not self:GetControllingPlayer():OnGround()
end

function ENT:IsAnimationDone()
	return self:GetLongJumpAnimCycle() >= 1
end

function ENT:ResetVars()
	self:SetLongJumping( false )
	self:SetLongJumpAnimCycle( 0 )
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
	
	function ENT:OnRemovePhysics( physobj )
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
		
		local idealact = -1
		
		--once we've done a full unarmed swimming cycle revert to the armed one, if we have a weapon
		
		if IsValid( ply:GetActiveWeapon() ) and self:IsAnimationDone() then
			idealact = ACT_MP_SWIM
		else
			idealact = ACT_HL2MP_IDLE + 9
		end
		
		return idealact , -1
	end
end

function ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
	if self:IsLongJumping() then
		--once we've done a full unarmed swimming cycle revert to the armed one, if we have a weapon
		if not IsValid( ply:GetActiveWeapon() ) or not self:IsAnimationDone() then
			ply:SetCycle( self:GetLongJumpAnimCycle() )
			ply:SetPlaybackRate( 0 )
			return true
		end
	end
end

function ENT:OnRemove()
end