AddCSLuaFile()

DEFINE_BASECLASS( "sent_jetpack" )

ENT.Spawnable = true
ENT.PrintName = "Jetpack 2.0"

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
		self:SetInputVector( vector_origin )
	else
	
	end

end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Vector" , "InputVector" ) --set during setupmove, this is where we actually want to go, based on both AIM and input data
end

if SERVER then
	function ENT:OnAttach( ply )
		BaseClass.OnAttach( self )
		self:SetInputVector( vector_origin )
	end
end

--TODO: override CanFly so we can start flying when pressing the movement keys in midair

function ENT:PredictedSetupMove( owner , mv , usercmd )
	

	self:HandleFly( true , owner , mv , usercmd )
	self:HandleFuel( true )
	
	if self:GetActive() then
		--TODO: make an input vector from AIM and movement keys, then set that to InputVector
		
		--TODO: after making the input vector, zero out the player's input movedata, we don't want him to have access to source's default air control
		
		--TODO: holding space: hover mode from willox's code?
		
		--TODO: apply velocity
		
		--TODO: air friction
	end
end

function ENT:PredictedMove( owner , data )

end

function ENT:PredictedFinishMove( owner , movedata )
	if self:GetActive() then
		--TODO: clamp velocity? what if the player releases the keys after reaching max speed?
	end
end

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
end

function ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
	local ret = BaseClass.HandleUpdateAnimationOverride( self , ply , velocity , maxseqgroundspeed )
	if self:GetActive() then
		--set the pose parameters to where we're actually trying to move to, not to our actual velocity
		local vec = self:GetInputVector()
		--TODO: convert to 2d from the player angle and then setposeparameter move_x and move_y
	end
	
	return ret
end







