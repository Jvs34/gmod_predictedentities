AddCSLuaFile()

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.SlotName = "grapplehookbpack"
ENT.PrintName = "Grappling hook Backpack"

if CLIENT then
	language.Add( "sent_grapplehook_bpack" , ENT.PrintName )
end

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

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
		self:InitPhysics()
		
		self:ResetGrapple()
		self:Detach()
		
	else
	
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	
	self:DefineNWVar( "Float" , "AttachTime" )
	self:DefineNWVar( "Float" , "AttachStart" )
	self:DefineNWVar( "Vector" , "AttachedTo" )
	self:DefineNWVar( "Vector" , "GrappleNormal" )
	self:DefineNWVar( "Bool" , "IsAttached" )
	self:DefineNWVar( "Bool" , "AttachSoundPlayed" )
end


function ENT:Think()
	if not IsValid( self:GetControllingPlayer() ) then
		self:HandleSounds( false )
	end
	
	return BaseClass.Think( self )
end

function ENT:ResetGrapple()
	self:SetAttachTime( CurTime() )
	self:SetAttachStart( CurTime() )
	self:SetAttachedTo( vector_origin )
	self:SetGrappleNormal( vector_origin )
	self:SetIsAttached( false )
	self:SetAttachSoundPlayed( false )
end

function ENT:Detach( forced )
	self:SetIsAttached( false )
	self:SetAttachTime( CurTime() )
	self:SetAttachStart( CurTime() )
end

function ENT:HandleSounds( predicted )

end

function ENT:PredictedSetupMove( owner , mv , usercmd )
	
	if mv:KeyPressed( IN_GRENADE1 ) then
		
	end
end

function ENT:PredictedThink( owner , mv )
	self:HandleSounds( true )
end

function ENT:FireHook()

end

if SERVER then

	function ENT:OnAttach( ply )
	
	end
	
	function ENT:OnDrop( ply , forced )
	
	end
	
	function ENT:OnInitPhysics( physobj )

	end

	function ENT:OnRemovePhysics()

	end
	
else

	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
		end
	end

end