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
else
	ENT.ShowPickupNotice = true
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
end

ENT.MinBounds = Vector( -5 , -5 , -5 )
ENT.MaxBounds = Vector( 5 , 5 , 5 )

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_pelvis",
	OffsetVec = Vector( 0 , 8 , -2 )
	OffsetAng = Angle( -20 , 90 , 180),
}

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Float" , "WingsCycle" )
end

function ENT:Think()
	if not self:IsCarried() then
		self:CalculateWingCycle( false )
	end
	
	if CLIENT then
		self:HandleWings()
	end
	
	return BaseClass.Think( self )
end

function ENT:PredictedMove( owner , data )
	
	if data:KeyDown(IN_DUCK) then
		return
	end

	local eye = owner:EyeAngles()
	eye.p = eye.p + self.PitchOffset

	local local_velocity = data:GetVelocity() * -1
	local length = math.min( local_velocity:Length() / 2000 , 1 )

	local final = ( ( ( eye:Forward() - ( eye:Up() * 0.3 ) ):Normalize() * local_velocity.x ) * Vector( 1 , 1 , 0.5 ) * 0.04 ) * length

	data:SetVelocity( data:GetVelocity() + ( final * FrameTime() * 200 ) )
	
	self:CalculateWingCycle( true )
end

function ENT:CalculateWingCycle( predicted , owner , mv )
	
	if CLIENT and not predicted then
		return
	end
	
	if IsValid( owner ) then
		--play the sounds
	else
	
	
	end
	
	--[[
	self.sound_wind:ChangePitch(70)
	self.sound_wind:ChangeVolume(math.Clamp(ply:GetVelocity():Length() / 4000, 0, 1))

	self.sound_flap:ChangePitch(math.Clamp(50+pitch, 0, 255))
	self.sound_flap:ChangeVolume(math.Clamp(cycle^10, 0, 1))

	self:SetWingsCycle(cycle)
	]]
	
	--[[
	local zup = math.Clamp(self:GetVelocity().z/1000,0,5)
		if zup < 3 then
			self.flapcycle = math.max(self.flapcycle - (self.flapcycle/2),0)
		else
			self.flapcycle = self.flapcycle + zup
		end

		if self.flapped > 0 then
			local ply = self.dt.ply
			local velocity = self:GetLocalVelocity()
			velocity.x = 0
			local mult = 500 / (1 + velocity:Length() / 2000)
			ply:SetVelocity((ply:EyeAngles():Up() + ply:EyeAngles():Forward()) * mult * (-(self.flapped / 100) + 1) * 0.1 )

			self.flapped = self.flapped - math.Clamp(math.abs((self:GetLocalVelocity().z + 900) / 700), 0, 1.5)
			self.flapcycle = -self.flapped
			--Print(self.flapped)
		end

		self.dt.cycle = (math.Clamp(-(self:GetLocalVelocity().x/80)+25,0,50) + self.flapcycle) % 100
		self.dt.cycle = self.dt.cycle / 100
		self.dt.cycle = self.dt.cycle%1

		if self.ply:KeyDown(IN_DUCK) then
			self.dt.cycle = 60
		end
	]]
	
end

if SERVER then

else
	function ENT:HandleWings()
		if not IsValid( self.WingModel ) then
			self.WingModel = self:CreateWing()
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
	
	BaseClass.OnRemove( self )
end