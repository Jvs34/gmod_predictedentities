AddCSLuaFile()
DEFINE_BASECLASS( "base_entity" )
ENT.Spawnable = false

ENT.SlotName = "mypredictedent"	--change this to "predicted_<myentityname>", using the classname is also just fine

--temporary system because willox is tired of the whole id offsets shenanigans, and so am I
--should probably port this to the css weapon base as well

ENT.DefinedDTVars = {
	Entity = { 
		MAX = GMOD_MAXDTVARS,
	},
	Float = { 
		MAX = GMOD_MAXDTVARS,
	},
	Int = { 
		MAX = GMOD_MAXDTVARS,
	},
	Bool = { 
		MAX = GMOD_MAXDTVARS,
	},
	Vector = { 
		MAX = GMOD_MAXDTVARS,
	},
	Angle = { 
		MAX = GMOD_MAXDTVARS,
	},
	String = { 
		MAX = 4,
	},
	
	--[[
	Entity = {
		[0] = "ControllingPlayer",
		[1] = "Target",
	}
	]]
}

function ENT:DefineNWVar( dttype , dtname )
	if not self.DefinedDTVars[dttype] then
		Error( "Wrong NWVar type " .. ( dttype or "nil" ) )
		return
	end
	
	local index = -1
	local maxindex = self.DefinedDTVars[dttype].MAX
	
	for i = 0 , maxindex - 1 do
		if not self.DefinedDTVars[dttype][i] then
			index = i
			break
		end
	end
	
	if index == -1 then
		Error( "Not enough slots on "..dttype )
		return
	end
	
	self.DefinedDTVars[dttype][index] = dtname
	
	self:NetworkVar( dttype , index , dtname )	--LAAAZY
end

function ENT:SetupDataTables()
	self:DefineNWVar( "Entity" , "ControllingPlayer" )
end

function ENT:Initialize()
	hook.Add( "StartCommand", self, self.HandlePredictedStartCommand )
	hook.Add( "SetupMove", self, self.HandlePredictedSetupMove )
	hook.Add( "Move", self, self.HandlePredictedMove )
	hook.Add( "PlayerTick", self, self.HandlePredictedThink )
	hook.Add( "FinishMove", self, self.HandlePredictedFinishMove )
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
	
	self:NextThink( CurTime() + engine.TickInterval() )
	return true
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

function ENT:HandlePredictedStartCommand( ply , cmd )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self.SlotName )
		if predictedent == self then
			self:StartCommand( ply , cmd )
		end
	end
end

function ENT:HandlePredictedSetupMove( ply , mv , cmd )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self.SlotName )
		if predictedent == self then
			self:PredictedSetupMove( ply , mv , cmd )
		end
	end
end

function ENT:HandlePredictedMove( ply , mv )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self.SlotName )
		if predictedent == self then
			self:PredictedMove( ply , mv )
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

function ENT:HandlePredictedFinishMove( ply , mv )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self.SlotName )
		if predictedent == self then
			self:PredictedFinishMove( ply , mv )
		end
	end
end

function ENT:PredictedStartCommand( ply , cmd )

end

function ENT:PredictedSetupMove( ply , mv , cmd )

end

function ENT:PredictedMove( ply , mv , cmd )

end

function ENT:PredictedThink( ply , mv )
	
end

function ENT:PredictedFinishMove( ply , mv , cmd )

end