AddCSLuaFile()

--[[
	A conversion of my old controllable birds entities from the drive system
	Hopefully I'm also gonna make them suck less
]]

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Driveable Crow"
ENT.AttachesToPlayer = false

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 36

	local ent = ents.Create( ClassName )
	ent:SetSlotName( ClassName )	--this is the best place to set the slot, don't modify it dynamically ingame
	ent:SetPos( SpawnPos )
	ent:SetAngles( angle_zero )
	ent:Spawn()
	return ent

end

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		--never initialize the physics for this, we want to be fully BBOXy
	else
	
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	--turn speed, acceleration and all that shit
end

if SERVER then
	
	--the bird has been dropped, add some shitty bbox fly physics, we don't care about a physobj
	function ENT:DoInitPhysics()
		self:SetMoveType( MOVETYPE_FLYGRAVITY )
		self:SetSolid( SOLID_BBOX )
		self:SetMoveCollide( MOVECOLLIDE_FLY_BOUNCE )
	end
	
	function ENT:DoRemovePhysics()
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		self:SetMoveCollide( MOVECOLLIDE_DEFAULT )
	end
	
	function ENT:OnAttach( ply )
		self:RemovePhysics()
	end
	
	function ENT:OnDrop( ply )
		self:InitPhysics()
	end
	
end

function ENT:PredictedFinishMove( ply , mv )
	local mvbackup = self:BackupMoveData( mv )
	
	--bird logic here
	
	self:RestoreMoveData( mv , mvbackup )
end