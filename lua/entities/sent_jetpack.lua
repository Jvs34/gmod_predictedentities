AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.SlotName = "jetpack"
ENT.RenderGroup = RENDERGROUP_BOTH

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
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	self:NetworkVar( "Bool" , 0 , "Active" )
end

if SERVER then
	function ENT:OnAttach( ply )
		self:FollowBone( ply , ply:LookupBone("ValveBiped.Bip01_Spine2") )
		self:SetLocalPos( vector_origin )
		self:SetLocalAngles( angle_zero )
	end
else
	function ENT:Draw( flags )
		if self:GetControllingPlayer() == LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() then
			return
		end
		self:DrawModel()
	end
	
	function ENT:DrawTranslucent( )
		if self:GetActive() then
			--TODO: effects
		end
	end
end