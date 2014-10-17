AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.SlotName = "jetpack"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.PrintName = "Jetpack"

sound.Add( {
	name = "jetpack.thruster_loop",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 0.1,
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
	end
	
	local clampedchargerate = math.Clamp( self:GetFuel() + rechargerate , 0 , self:GetMaxFuel() )
	self:SetFuel( clampedchargerate )
	
end

function ENT:HandleSounds( predicted )
	if not predicted and CLIENT then
		--TODO: stop the sound the old controller had on the client
		return
	end
	
	--create the soundpatch if it doesn't exist, it might happen on the client sometimes since it's garbage collected and all
	
	if self:GetActive() then
		
	else
	
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

function ENT:PredictedMove( owner , movedata )
	if self:GetActive() then
		--actually do the movement here
	end
	
end

function ENT:PredictedFinishMove( owner , movedata )
	if self:GetActive() then
		--and here
	end
end

--TODO:	use this to calculate the position on the parent because I can't be arsed to deal with source's parenting bullshit with local angles and position
--		plus this is also called during that parenting position recompute, so it's perfect

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

function ENT:GetCustomParentOrigin( ply )
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
			self:Draw( STUDIO_RENDER )
		end
	end
	
	function ENT:Draw( flags )
		if self:CanDraw() then
			--is this actually necessary due to CalcAbsolutePosition?
			--that seems to trigger the calcabsoluteposition in the engine, but only if you call setpos here?
			--[[
			if IsValid( self:GetControllingPlayer() ) then
				local pos , ang = self:GetCustomParentOrigin( self:GetControllingPlayer() )
				self:SetRenderOrigin( pos )
				self:SetRenderAngles( ang )
			else
				self:SetRenderOrigin( nil )
				self:SetRenderAngles( nil )
			end]]
			
			self:DrawModel()
		end
	end
	
	function ENT:DrawTranslucent( flags )
		self:Draw( flags )
		
		if self:CanDraw() and self:GetActive() then
			--TODO: fire effects and smoke particles
		end
	end
end

function ENT:OnRemove()
	--TODO: remove the sounds on both client and server, in case we got removed while the player was using us
	--happens during a mass cleanup
end