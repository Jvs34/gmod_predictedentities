AddCSLuaFile()

--[[
	Capsadmin's wings https://github.com/CapsAdmin/unfinished/blob/master/birdwings.lua
]]

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
--keeping this because I ain't no stealer yo
ENT.Category = "CapsAdmin"
ENT.PrintName = "Bird Wings"
ENT.Author = "CapsAdmin"
ENT.Contact = "sboyto@gmail.com"
ENT.Purpose = "Fly around"
ENT.Instructions = "Press use to wear, undo to unwear"

ENT.PitchOffset = 90

if CLIENT then
	language.Add( "sent_wings" , ENT.PrintName )
	ENT.WingBoneResize = {
		{
			name = "Crow.Humerus_R",
			scale = Vector( 10 , 10 , 10 )
		},
		{
			name = "Crow.Humerus_L", 
			scale = Vector( 10 , 10 , 10 )
		},
		--[[
		{
			name = "Seagull.Body",
			scale = Vector( 0.1 , 0.1 , 0.1 )
		},
		]]
	}
else
	ENT.ShowPickupNotice = true
end

ENT.MinBounds = Vector( -5 , -5 , -5 )
ENT.MaxBounds = Vector( 5 , 5 , 5 )

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_pelvis",
	OffsetVec = Vector( 0 , 8 , -2 ),
	OffsetAng = Angle( -20 , 90 , 180),
}

sound.Add( {
	name = "birdwings.flap",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "vehicles/fast_windloop1.wav"
})

sound.Add( {
	name = "birdwings.wind",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "ambient/wind/windgust_strong.wav"
})

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/props_junk/wood_crate001a.mdl" )
		self:DrawShadow( false )
		self:InitPhysics()
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Float" , "WingsCycle" )
	self:DefineNWVar( "Float" , "Flapped" )
	self:DefineNWVar( "Float" , "FlapCycle" )
end

function ENT:Think()

	if not self:IsCarried() then
		self:HandleSounds( false )
	end
	
	if CLIENT then
		self:HandleWings()
	end
	
	return BaseClass.Think( self )
end

function ENT:CanFly()
	if not self:IsCarried() then
		return false
	end
	return self:GetControllingPlayer():GetMoveType() == MOVETYPE_WALK and not self:GetControllingPlayer():OnGround()
end

function ENT:GetLocalVel( currentvel )
	local eye = self:GetControllingPlayer():EyeAngles()
	eye.p = eye.p + self.PitchOffset
	return ( { WorldToLocal( currentvel , Angle( self.PitchOffset , 0 , 0 ) , Vector( 0  , 0 , 0 ) , eye ) } )[1]
end

function ENT:PredictedStartCommand( owner , ucmd )
	if self:CanFly() then
		ucmd:SetForwardMove( 0 )
		ucmd:SetSideMove( 0 )
		if ucmd:GetMouseX() > 0 then
			ucmd:SetSideMove( 1 )
		elseif ucmd:GetMouseX() < 0 then
			ucmd:SetSideMove( -1 )
		end
	end
end

function ENT:PredictedMove( owner , data )
	self:HandleSounds( true )
	
	if data:KeyDown( IN_DUCK ) or not self:CanFly() then
		return
	end

	--there's a few problems with the movement code due to me using 
	
	local eye = owner:EyeAngles()
	eye.p = eye.p + self.PitchOffset
	
	local local_velocity = self:GetLocalVel( data:GetVelocity() ) * -1
	local length = math.min( local_velocity:Length() / 2000 , 1 )

	local final = ( ( ( eye:Forward() - ( eye:Up() * 0.3 ) ):GetNormal() * local_velocity.x ) * Vector( 1 , 1 , 0.5 ) * 0.04 ) * length

	data:SetVelocity( data:GetVelocity() + ( final * FrameTime() * 200 ) )
	
	if data:KeyPressed( IN_JUMP ) then
		if self:GetFlapped() <= 10 then
			self:SetFlapped( 100 )
		end
	end
	
	local zup = math.Clamp( data:GetVelocity().z / 1000 , 0 , 5 )
	if zup < 3 then
		self:SetFlapCycle( math.max( self:GetFlapCycle() - ( self:GetFlapCycle() / 2 ) , 0 ) )
	else
		self:SetFlapCycle( self:GetFlapCycle() + zup )
	end

	if self:GetFlapped() > 0 then
		local velocity = self:GetLocalVel( data:GetVelocity() )
		velocity.x = 0
		
		local mult = 500 / ( 1 + velocity:Length() / 2000 )
		data:SetVelocity( ( owner:EyeAngles():Up() + owner:EyeAngles():Forward() ) * mult * ( - ( self:GetFlapped() / 100 ) + 1 ) * 0.1 )

		self:SetFlapped( self:GetFlapped() - math.Clamp( math.abs( ( self:GetLocalVel( data:GetVelocity() ).z + 900 ) / 700 ) , 0 , 1.5 ) )
		self:SetFlapCycle( -self:GetFlapped() )
	end

	self:SetWingsCycle( ( math.Clamp( - ( self:GetLocalVel( data:GetVelocity() ).x / 80 ) + 25 , 0 , 50 ) + self:GetFlapCycle() ) % 100 )
	self:SetWingsCycle( self:GetWingsCycle() / 100 )
	self:SetWingsCycle( self:GetWingsCycle() % 1 )

	if data:KeyDown( IN_DUCK ) then
		self:SetWingsCycle( 60 )
	end
	
	return true
end

function ENT:HandleSounds( predicted , owner , mv )
	
	if CLIENT and not predicted then
		return
	end
	
	local cycle = self:GetWingsCycle()
	local pitch = cycle * 10
	
	if not self.SoundFlap then
		self.SoundFlap = CreateSound( self , "birdwings.flap" )
	end
	
	if not self.SoundWind then
		self.SoundWind = CreateSound( self , "birdwings.wind" )
	end
	
	if IsValid( owner ) and self:CanFly() then
		self.SoundWind:PlayEx( math.Clamp( mv:Length() / 4000 , 0 , 1 ) , 70 )
		self.SoundFlap:PlayEx( math.Clamp( cycle ^ 10 , 0 , 1 ) , math.Clamp( 50 + pitch , 0 , 255 ) )
	else
		self.SoundWind:Stop()
		self.SoundFlap:Stop()
	end
end

if SERVER then
	function ENT:OnAttach( ply )
		self:SetFlapCycle( 0 )
		self:SetFlapped( 0 )
	end
else
	function ENT:Draw( flags )
		local pos , ang = self:GetCustomParentOrigin()
		
		if pos and ang then
			self:SetPos( pos )
			self:SetAngles( ang )
		end
		
		if IsValid( self.WingModel ) then
			self.WingModel:SetPos( self:GetPos() )
			self.WingModel:SetAngles( self:GetAngles() )
			self.WingModel:DrawModel()
		end
	end
	
	function ENT:HandleWings()
		if not IsValid( self.WingModel ) then
			self.WingModel = self:CreateWing()
		end
		
		local cycle = self:GetWingsCycle()
		cycle = cycle / 3 % 0.33
		if IsValid( self.WingModel ) then
			self.WingModel:SetCycle( cycle )
		end
	end
	
	function ENT:CreateWing()
		local wing = ClientsideModel( "models/crow.mdl" )
		local wingseq = wing:LookupSequence( "fly01" )
		
		if wingseq then
			wing:SetSequence( wingseq )
		end
		
		wing.BonesResize = self.WingBoneResize
		
		wing:AddCallback( "BuildBonePositions" , function( self )
			
			if not self.BonesResize then
				return
			end
			
			for key, bone in pairs( self.BonesResize ) do
				local index = self:LookupBone( bone.name )
				if index then
					local matrix = self:GetBoneMatrix( index )
					matrix:Scale( bone.scale * 0.9 )
					self:SetBoneMatrix( index , matrix )
				end
			end
		end)
		
		wing:SetNoDraw( true )
		return wing
	end
end

function ENT:OnRemove()
	if CLIENT then
		if IsValid( self.WingModel ) then
			self.WingModel:Remove()
		end
	end
	
	self:StopSound( "birdwings.flap" )
	self:StopSound( "birdwings.wind" )
	
	BaseClass.OnRemove( self )
end