AddCSLuaFile()
DEFINE_BASECLASS( "base_entity" )
ENT.Spawnable = false

ENT.SlotName = "mypredictedent"	--change this to "predicted_<myentityname>", using the classname is also just fine

function ENT:SetupDataTables()
	self:NetworkVar( "Entity" , 0 , "ControllingPlayer" )
end

function ENT:Initialize()
	hook.Add( "PlayerTick", self, self.HandlePredictedThink )
	if SERVER then
		hook.Add( "EntityRemoved" , self , self.OnControllerRemoved )
	else
		self.IsPredictable = false
	end
end

function ENT:Think()
	if SERVER then
		--check if this guy is still my parent and owner, maybe something is forcibly unparenting us from him, if so, drop
		if IsValid( self:GetControllingPlayer() ) then
			local ply = self:GetControllingPlayer()
			if self:GetParent() ~= ply or self:GetOwner() ~= ply then
				self:Drop()
			end
		end
	else
		--calling this in a non-predicted hook is perfectly fine, since we need the entity to enable prediction on its own
		--even when controlling players change
		
		--Ideally this would be handled on the callback of SetControllingPlayer clientside, but we don't have that yet
		self:HandlePrediction()
	end
end

if SERVER then
	function ENT:Use( activator )
		if IsValid( activator ) and activator:IsPlayer() then
			
			if IsValid( self:GetControllingPlayer() ) then
				return
			end
			
			if IsValid( activator:GetNWEntity( self.SlotName ) ) then
				return
			end
			
			self:Attach( activator )
		end
	end

	function ENT:InitPhysics()
		if self:GetSolid() == SOLID_VPHYSICS then return end
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:PhysWake()
		
		self:OnInitPhysics()
	end

	function ENT:RemovePhysics()
		if self:GetSolid() == SOLID_NONE then return end
		self:PhysicsDestroy()
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		
		self:OnRemovePhysics()
	end

	function ENT:OnAttach( ply )
		
	end
	
	function ENT:OnDrop( ply )
		
	end
	
	--these two are not necessarely duplicates of the functions above because we may want to modify the mass as soon as the physobj gets created, and that also happens in initialize
		
	function ENT:OnInitPhysics()
	
	end
	
	function ENT:OnRemovePhysics()
	
	end
	
	function ENT:Attach( activator )
		self:RemovePhysics()
		self:SetParent( activator )
		self:SetOwner( activator )
		activator:SetNWEntity( self.SlotName , self )
		self:SetControllingPlayer( activator )
		self:OnAttach( self:GetControllingPlayer() )
		
		--add a new undo history to the player that allows him to drop this entity
		
		undo.Create( self:GetClass() )
			undo.SetPlayer( activator )
			undo.AddFunction( function( tab , ent )
				if IsValid( ent ) then
					if ent:GetControllingPlayer() == tab.Owner then
						ent:Drop()
					end
				end
			end, self )
			undo.SetCustomUndoText( "Dropped " .. self:GetClass() )
		undo.Finish()
	end
	
	function ENT:Drop()
		self:SetParent( NULL )
		self:SetOwner( NULL )
		self:InitPhysics()
		self:OnDrop( self:GetControllingPlayer() )
		if IsValid( self:GetControllingPlayer() ) then
			--TODO: remove the undo block, is this even possible without hacking around?
			self:GetControllingPlayer():SetNWEntity( self.SlotName , NULL )
		end
		self:SetControllingPlayer( NULL )
	end

	function ENT:OnControllerRemoved( ent )
		if ent == self:GetControllingPlayer() then
			self:Drop()
		end
	end

else

	function ENT:HandlePrediction()
		if LocalPlayer() == self:GetControllingPlayer() then
			self:SetPredictionEnabled( true )
		else
			self:SetPredictionEnabled( false )
		end
	end

	function ENT:SetPredictionEnabled( bool )
		if bool ~= self.IsPredictable then
			self:SetPredictable( bool )
			self.IsPredictable = bool
		end
	end
	
end

function ENT:HandlePredictedThink( ply , mv )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self.SlotName ) --or your prefered way to network it
		if predictedent == self then
			self:PredictedThink( ply , mv )
		end
	end
end


function ENT:PredictedThink( ply , mv )
	
end
