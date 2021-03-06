AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Long jump module"

if SERVER then
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
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		self:SetLongJumpSpeed( 550 )
		
		self:SetMaxHealth( 100 )
		self:SetHealth( self:GetMaxHealth() )
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	self:DefineNWVar( "Int" , "Key" )	--override it to disallow people from editing the key since it's unused
	
	self:DefineNWVar( "Bool" , "DoLongJump" )
	self:DefineNWVar( "Bool" , "LongJumping" )
	
	self:DefineNWVar( "Float" , "LongJumpSpeed" , true , "The speed to apply on a long jump" , 1 , 1000 )
	self:DefineNWVar( "Float" , "LongJumpAnimCycle" )
end

function ENT:Think()
	return BaseClass.Think( self )
end

--these are here instead of being the single functions so I can eventually reverse the cycle direction ( from 1 to 0 ) if the animation is not good enough

function ENT:StartJumpCycle()
	self:SetLongJumpAnimCycle( 1 )
end

function ENT:FinishJumpCycle()
	self:SetLongJumpAnimCycle( 0 )
end

function ENT:HandleJumpCycle()
	local cycle = self:GetLongJumpAnimCycle()
	cycle = cycle + -1.5 * FrameTime()	--TODO: tweak the cycle speed
	self:SetLongJumpAnimCycle( math.Clamp( cycle , 0 , 1 ) )
	self:GetControllingPlayer():AnimSetGestureWeight( GESTURE_SLOT_JUMP , 0.5 )
end

function ENT:IsAnimationDone()
	return self:GetLongJumpAnimCycle() <= 0
end

function ENT:PredictedThink( owner , movedata )
	if self:IsLongJumping() and not self:IsAnimationDone() then
		self:HandleJumpCycle()
	elseif not self:IsLongJumping() then--and self:IsAnimationDone() then
		self:ResetGesture()
	end
end

function ENT:PredictedSetupMove( owner , data )
	
	if self:GetLongJumping() and owner:OnGround() then
		self:ResetVars()
	end
	
	--:Crouching() only checks if the player is fully crouched, but not if he's in the middle of the crouching, that info is inaccessible from Lua
	--so might as well check if the player is not crouched but still pressing IN_DUCK
	
	if not self:GetDoLongJump() and owner:OnGround() and not owner:Crouching() and data:KeyDown( IN_DUCK ) and data:KeyPressed( IN_JUMP ) and owner:WaterLevel() == 0 then
		if data:GetVelocity():Length2D() > owner:GetWalkSpeed() / 4 then
			owner:SetGroundEntity( NULL )
			self:SetDoLongJump( true )
		end
	end
	
	--prevent the player from spamming the crouch button while long jumping by holding it down, this should really be fixed somewhere else
	
	if self:GetLongJumping() then
		owner:SetGroundEntity( NULL )
		--data:SetButtons( bit.band( data:GetButtons() , bit.bnot( IN_DUCK ) ) )
	end
end

function ENT:PredictedFinishMove( owner , data )
	if self:GetDoLongJump() then
	
		local ang = data:GetMoveAngles()
		ang.p = 0
		
		local forward = ang:Forward()
		
		self:SetLongJumping( true )
		self:EmitPESound( "HL2Player.SprintStart" , 125 , 1 , 100 , nil , true )
		self:StartJumpCycle()
		owner:ViewPunch( Angle( -5 , 0 , 0 ) )
		
		local vel = forward * self:GetLongJumpSpeed() * 1.6	--I dunno where valve pulled this 1.6 from
		
		--hl2's gravity is 600, and 800 is hl1's ( I guess technically quake's, and then tf, hl1, tfc and tf2's )
		--the 56 is in theory hl1's jump power more or less, sandbox's jump power is 200, so just divide it by 4
		vel.z = math.sqrt( 2 * sv_gravity:GetFloat() * ( owner:GetJumpPower() / 4 ) )
		
		data:SetVelocity(  vel )
		self:SetDoLongJump( false )
		
		--this overlaps the jump sequence on a gesture layer with the swimming animation, and then we blend them
		local seq = owner:LookupSequence( "jump_dual" )
		--using GESTURE_SLOT_JUMP just so in case we don't override it first with :ResetVars, the landing gesture will
		if seq and seq ~= ACT_INVALID then
			owner:AddVCDSequenceToGestureSlot( GESTURE_SLOT_JUMP , seq , 0 , false )
			owner:AnimSetGestureWeight( GESTURE_SLOT_JUMP , 0.5 )
		end
	end
end

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
	self:ResetVars()
end

function ENT:ResetGesture()
	if self:IsCarried() then
		self:GetControllingPlayer():AnimResetGestureSlot( GESTURE_SLOT_JUMP )
	end
end

function ENT:IsLongJumping()
	return self:GetLongJumping() and not self:GetControllingPlayer():OnGround() and self:GetControllingPlayer():WaterLevel() == 0
end

function ENT:ResetVars()
	self:SetLongJumping( false )
	self:FinishJumpCycle()
	self:SetDoLongJump( false )
	
	self:ResetGesture()
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
		if SERVER then
			if data.DeltaTime >= 0.05 and data.Speed >= 70 then
				local volume = data.Speed * data.Speed * ( 1 / ( 320 * 320 ) )
				if volume > 1 then
					volume = 1
				end
				
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