AddCSLuaFile()
DEFINE_BASECLASS( "base_entity" )
ENT.Spawnable = false

ENT.SlotName = "mypredictedent"	--change this to "predicted_<myentityname>", using the classname is also just fine
ENT.AttachesToPlayer = true	--whether this entity attaches to the player or not, you'll have to handle positioning on the player on your own, see sent_jetpack
ENT.RenderGroup = RENDERGROUP_OPAQUE

--temporary system because willox is tired of the whole id offsets shenanigans, and so am I
--should probably port this to the css weapon base as well

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
	
	self.DefinedDTVars = {
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
	}

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
		self:SetUseType( SIMPLE_USE )
	else
		hook.Add( "PostPlayerDraw" , self , self.DrawOnPlayer )
	end
end

function ENT:Think()
	if SERVER then
		--check if this guy is still my parent and owner, maybe something is forcibly unparenting us from him, if so, drop
		if self.AttachesToPlayer then
			if IsValid( self:GetControllingPlayer() ) then
				local ply = self:GetControllingPlayer()
				if self:GetParent() ~= ply or self:GetOwner() ~= ply then
					self:Drop()
				end
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
		
		self:OnInitPhysics( self:GetPhysicsObject() )
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
	
	--these two are not necessarely duplicates of the functions above because we may want to modify the mass 
	--as soon as the physobj gets created, and that also happens in initialize
		
	function ENT:OnInitPhysics( physobj )
	
	end
	
	function ENT:OnRemovePhysics()
	
	end
	
	function ENT:Attach( activator )
		if self.AttachesToPlayer then
			self:RemovePhysics()
			self:SetParent( activator )
			self:SetOwner( activator )
			self:SetTransmitWithParent( true )
		end
		
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
			undo.SetCustomUndoText( "Dropped " .. ( self.PrintName or self:GetClass() ) )
		undo.Finish()
	end
	
	function ENT:Drop()
		
		if self.AttachesToPlayer then
			self:SetParent( NULL )
			self:SetOwner( NULL )
			self:InitPhysics()
			self:SetTransmitWithParent( false )
		end
		
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
		local bool = LocalPlayer() == self:GetControllingPlayer()
		if self.IsPredictable ~= bool then
			self:SetPredictable( bool )
			self.IsPredictable = bool
		end
	end
	
	function ENT:DrawOnPlayer( ply )
		if self.AttachesToPlayer then
			if IsValid( self:GetControllingPlayer() ) and self:GetControllingPlayer() == ply then
				self:DrawModel()
			end
		end
	end
	
	function ENT:CanDraw()
		if not self.AttachesToPlayer then 
			return true 
		end
		
		if self:GetControllingPlayer() == LocalPlayer() then
			return LocalPlayer():ShouldDrawLocalPlayer()
		else
			return true
		end
	end
	
	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
		end
	end
end

function ENT:HandlePredictedStartCommand( ply , cmd )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self.SlotName )
		if predictedent == self then
			self:PredictedStartCommand( ply , cmd )
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

function ENT:GetCustomParentOrigin( ply )
	
	if not self.AttachmentInfo then
		return
	end
	
	--Jvs:	I put this here because since the entity moves to the player bone matrix, it'll only be updated on the client
	--		when the player is actally drawn, or his bones are setup again ( which happens before a draw anyway )
	--		this also fixes sounds on the client playing at the last location the LocalPlayer() was drawn
	
	if CLIENT and ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then
		ply:SetupBones()
	end
	
	local boneid = ply:LookupBone( self.AttachmentInfo.BoneName )
	
	if not boneid then 
		return 
	end
	
	local matrix = self:GetControllingPlayer():GetBoneMatrix( boneid )
	
	if not matrix then 
		return
	end
	
	return LocalToWorld( self.AttachmentInfo.OffsetVec , self.AttachmentInfo.OffsetAng , matrix:GetTranslation() , matrix:GetAngles() )
end

--if we're attached to a player, use custom origin from the function above
--this is called shared, yes it's more expensive than source's normal parenting but it's worth it

function ENT:CalcAbsolutePosition( pos , ang )
	if self.AttachesToPlayer then
		if IsValid( self:GetControllingPlayer() ) then
			return self:GetCustomParentOrigin( self:GetControllingPlayer() )
		end
	end
end