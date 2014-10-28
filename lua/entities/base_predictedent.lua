AddCSLuaFile()
DEFINE_BASECLASS( "base_entity" )
ENT.Spawnable = false
ENT.IsPredictedEnt = true
ENT.AttachesToPlayer = true	--whether this entity attaches to the player or not, when true this removes physics and draws the entity on the player

if SERVER then
	ENT.ShowPickupNotice = false	--plays the pickup sound and shows the pickup message on the hud
else
	ENT.RenderGroup = RENDERGROUP_OPAQUE
end

--NOTE:	yes I'm using NWVars to network the entity on the player, I'm not happy to do that but soon garry's NWVars will
--be replaced with Vinh's , which will be as reliable as normal dt vars ( except for the lack of prediction, that will come later )

--example attachment info table, only used if AttachesToPlayer is true
--[[
ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}
]]

--temporary system because willox is tired of the whole id offsets shenanigans, and so am I
--should probably port this to the css weapon base as well
--this is all going to change once vinh is done with prediction on his new NWVars system, until then, this'll stay here

function ENT:DefineNWVar( dttype , dtname )
	if not self.DefinedDTVars[dttype] then
		Error( "Wrong NWVar type " .. ( dttype or "nil" ) )
		return
	end

	local index = -1
	local maxindex = self.DefinedDTVars[dttype].Max

	for i = 0 , maxindex - 1 do
		
		--we either didn't find anything in this slot or we found the requested one again
		--in which case just override again?
		if not self.DefinedDTVars[dttype][i] or self.DefinedDTVars[dttype][i] == dtname then
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
			Max = GMOD_MAXDTVARS,
		},
		Float = {
			Max = GMOD_MAXDTVARS,
		},
		Int = {
			Max = GMOD_MAXDTVARS,
		},
		Bool = {
			Max = GMOD_MAXDTVARS,
		},
		Vector = {
			Max = GMOD_MAXDTVARS,
		},
		Angle = {
			Max = GMOD_MAXDTVARS,
		},
		String = {
			Max = 4, --as I said before, fuck strings
		},
	}

	self:DefineNWVar( "Entity" , "ControllingPlayer" )
	self:DefineNWVar( "Bool" , "BeingHeld" )
	self:DefineNWVar( "String" , "SlotName" )
end

function ENT:Initialize()
	hook.Add( "StartCommand", self, self.HandlePredictedStartCommand )
	hook.Add( "SetupMove", self, self.HandlePredictedSetupMove )
	hook.Add( "Move", self, self.HandlePredictedMove )
	hook.Add( "PlayerTick", self, self.HandlePredictedThink )
	hook.Add( "FinishMove", self, self.HandlePredictedFinishMove )

	if SERVER then
		hook.Add( "EntityRemoved" , self , self.OnControllerRemoved )
		self:SetUseType( SIMPLE_USE ) --don't allow continuous use
	else
		hook.Add( "PostPlayerDraw" , self , self.DrawOnPlayer )
	end
end

function ENT:Think()
	if SERVER then
	
		--check if this guy is still my parent and owner, maybe something is forcibly unparenting us from him, if so, drop
		if self.AttachesToPlayer and IsValid( self:GetControllingPlayer() ) then
			local ply = self:GetControllingPlayer()
			if self:GetParent() ~= ply or self:GetOwner() ~= ply then
				self:Drop( true )
			end
		end
		
		--we have to network this ourselves since it's based on the physics object ( which is mainly serverside )
		--NOTE: this is not as expensive as it looks, it just checks for the FVPHYSICS_PLAYER_HELD flag on our physobj
		self:SetBeingHeld( self:IsPlayerHolding() )
	else
		--calling this in a non-predicted hook is perfectly fine, since we need the entity to enable prediction on its own
		--even when controlling players change

		--Ideally this would be handled on the callback of SetControllingPlayer clientside, but we don't have that yet
		self:HandlePrediction()
	end
	
	--set our think rate to be in line with the server tickrate
	--this may also affect animations clientside if they're ran in this hook, considering that also happens in normal source
	--I'd say that's an accurate replication of the issue
	
	self:NextThink( CurTime() + engine.TickInterval() )
	return true
end

if SERVER then

	function ENT:Use( activator )
		self:Attach( activator )
	end

	--these functions may actually not be correct, some entities may not want vphysics at all, and simply use the BBOX system
	function ENT:InitPhysics()
		if IsValid( self:GetPhysicsObject() ) then
			return
		end

		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:PhysWake()

		self:OnInitPhysics( self:GetPhysicsObject() )
	end

	function ENT:RemovePhysics()
		if not IsValid( self:GetPhysicsObject() ) then
			return
		end

		self:PhysicsDestroy()
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )

		self:OnRemovePhysics()
	end

	function ENT:OnAttach( ply )

	end

	function ENT:OnDrop( ply , fromuser )

	end

	--these two are not necessarely duplicates of the functions above because we may want to modify the mass
	--as soon as the physobj gets created, and that also happens in initialize

	function ENT:OnInitPhysics( physobj )

	end

	function ENT:OnRemovePhysics()

	end

	function ENT:Attach( activator )
	
		if not IsValid( activator ) or not activator:IsPlayer() then
			return
		end
		
		if IsValid( self:GetControllingPlayer() ) or IsValid( activator:GetNWEntity( self:GetSlotName() ) ) then
			self:EmitPESound( "HL2Player.UseDeny" , nil , nil , nil , nil , nil , true )
			return
		end
		
		if self.AttachesToPlayer then
			self:RemovePhysics()
			self:SetParent( activator )
			self:SetOwner( activator )
			self:SetTransmitWithParent( true )
			self:SetNoDraw( true )
		end

		if self.ShowPickupNotice then
			self:EmitPESound( "HL2Player.PickupWeapon" )
			
			net.Start( "pe_pickup" )
				net.WriteString( self:GetClass() )
			net.Send( activator )
		end
		
		activator:SetNWEntity( self:GetSlotName() , self )
		self:SetControllingPlayer( activator )
		self:OnAttach( self:GetControllingPlayer() )
		--add a new undo history to the player that allows him to drop this entity
		--TODO: completely scratch this bullshit when I implement hud elements ( that can also be clicked with the context menu )
		
		undo.Create( self:GetClass() )
			undo.SetPlayer( activator )
			undo.AddFunction( function( tab , ent )
				if IsValid( ent ) then
					if ent:GetControllingPlayer() == tab.Owner then
						ent:Drop( false )
					end
				end
			end, self )
			undo.SetCustomUndoText( "Dropped " .. ( self.PrintName or self:GetClass() ) )
		undo.Finish()
	end

	function ENT:Drop( forced )

		if self.AttachesToPlayer then
			self:SetParent( NULL )
			self:SetOwner( NULL )
			self:InitPhysics()
			self:SetTransmitWithParent( false )
			self:SetNoDraw( false )
		end

		self:OnDrop( self:GetControllingPlayer() , forced )
		
		if IsValid( self:GetControllingPlayer() ) then
			--TODO: remove the undo block, is this even possible without hacking around?
			self:GetControllingPlayer():SetNWEntity( self:GetSlotName() , NULL )
		end

		self:SetControllingPlayer( NULL )
	end

	function ENT:OnControllerRemoved( ent )
		if ent == self:GetControllingPlayer() then
			self:Drop( true )
		end
	end

else

	function ENT:IsCarriedByLocalPlayer()
		return LocalPlayer() == self:GetControllingPlayer()
	end
	
	--TODO: when the update gets pushed with the new behaviour, change this to self:SetPredictable( LocalPlayer() == self:GetControllingPlayer() )
	function ENT:HandlePrediction()
	
		--either the gravity gun or some other stuff is carrying me, don't do anything on prediction
		--because they might enable it to carry us around smoothly
		
		if self:GetBeingHeld() then
			return
		end
		
		local bool = self:IsCarriedByLocalPlayer()
		if self.IsPredictable ~= bool then
			self:SetPredictable( bool )
			self.IsPredictable = bool
		end
	end

	function ENT:DrawOnPlayer( ply )
		if self.AttachesToPlayer and IsValid( self:GetControllingPlayer() ) and self:GetControllingPlayer() == ply then
			self:DrawModel()
		end
	end

	function ENT:CanDraw()
		if self.AttachesToPlayer and self:IsCarriedByLocalPlayer() then
			return self:GetControllingPlayer():ShouldDrawLocalPlayer()
		else
			return true
		end
	end

	function ENT:Draw( flags )
		if self:CanDraw() then
			self:DrawModel()
		end
	end
	
	--NOTE: this should work in the case that we have multiple of the same entity but with different slots
	
	function ENT:RegisterHUDInternal( parentpanel )
		--the parentpanel is a DVerticalLayout or whatever, depending on the user settings on where to show it
		--so we just want to create a button with a custom image display, and we'll leave the rest to the child class
		local mypanel = parentpanel:Add( "DPredictedEnt" )
		mypanel:SetEntity( self )	--also allows the panel to autodelete itself when the entity is gone
		mypanel:SetSlot( self:GetSlotName() )
	end
	
end

function ENT:HandlePredictedStartCommand( ply , cmd )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self:GetSlotName() )
		if predictedent == self then
			self:PredictedStartCommand( ply , cmd )
		end
	end
end

function ENT:HandlePredictedSetupMove( ply , mv , cmd )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self:GetSlotName() )
		if predictedent == self then
			self:PredictedSetupMove( ply , mv , cmd )
		end
	end
end

function ENT:HandlePredictedMove( ply , mv )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self:GetSlotName() )
		if predictedent == self then
			self:PredictedMove( ply , mv )
		end
	end
end

function ENT:HandlePredictedThink( ply , mv )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self:GetSlotName() )
		if predictedent == self then
			self:PredictedThink( ply , mv )
		end
	end
end

function ENT:HandlePredictedFinishMove( ply , mv )
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self:GetSlotName() )
		if predictedent == self then
			self:PredictedFinishMove( ply , mv )
		end
	end
end

function ENT:PredictedStartCommand( ply , cmd )

end

function ENT:PredictedSetupMove( ply , mv , cmd )

end

function ENT:PredictedMove( ply , mv )

end

function ENT:PredictedThink( ply , mv )

end

function ENT:PredictedFinishMove( ply , mv )

end


--Allows for predicted movement simulation on non player entities, without disrupting the player movement itself
--FinishMove should be the best place for this, since even in case of fuckups, the rest of the movement should be fine

--[[
	function ENT:PredictedFinishMove( ply , mv )
		
		local sv = self:BackupMoveData( mv )
		
		--set the data you want on the movedata, such as the entity origin, speed, angles and stuff
		
		--run the entity traces
		
		--set the final position of the entity here with the same way garry does ( setnetworkedposition or whatever )
		
		--restore the movedata on the player as if nothing happened
		
		self:RestoreMoveData( mv , sv )
		
	
	end


]]

local movedatameta = FindMetaTable( "CMoveData" )

local emptyvalues = {
	[TYPE_VECTOR] = vector_origin,
	[TYPE_ANGLE] = angle_zero,
	[TYPE_NUMBER] = 0,
}

function ENT:BackupMoveData( mv )
	
	if not mv then
		return
	end
	
	local sv = {}
	--save the movedata by name on the table, then go trough the metatable to get the setters and set values to empty ones
	sv.Origin =	mv:GetOrigin()
	sv.Velocity = mv:GetVelocity()
	sv.Angles = mv:GetAngles()
	sv.OldAngles = mv:GetOldAngles()
	sv.AbsMoveAngles = mv:GetAbsMoveAngles()
	sv.MoveAngles = mv:GetMoveAngles()
	sv.MaxSpeed = mv:GetMaxSpeed()
	sv.MaxClientSpeed = mv:GetMaxClientSpeed()
	sv.Buttons = mv:GetButtons()
	sv.OldButtons = mv:GetOldButtons()
	sv.ImpulseCommand = mv:GetImpulseCommand()
	sv.ForwardSpeed = mv:GetForwardSpeed()
	sv.SideSpeed = mv:GetSideSpeed()
	sv.UpSpeed = mv:GetUpSpeed()
	sv.ConstraintRadius = mv:GetConstraintRadius()
	
	for i , v in pairs( sv ) do
		local setter = movedatameta["Set"..i]
		if setter then
			setter( mv , emptyvalues[type( v )] * 1 )
		end
	end
	
	return sv
end

function ENT:RestoreMoveData( mv , sv )
	--shouldn't be possible
	if not mv or not sv then
		return
	end
	
	--restore the values from the table, prevents duplicated code by using the setters from the metatable directly
	for i , v in pairs( sv ) do
		local setter = movedatameta["Set"..i]
		if setter then
			setter( mv , v )
		end
	end
end

--attaches the entity to the player depending on the attachmentinfo table
--you can override this safely as long as you keep the part with ply:SetupBones()
--although you generally should just use the attachment info table instead

function ENT:GetCustomParentOrigin()

	if not self.AttachmentInfo then
		return
	end
	
	local ply = self:GetControllingPlayer()
	
	if not IsValid( ply ) then
		return
	end
	
	--Jvs:	I put this here because since the entity moves to the player bone matrix, it'll only be updated on the client
	--		when the player is actally drawn, or his bones are setup again ( which happens before a draw anyway )
	--		this also fixes sounds on the client playing at the last location the LocalPlayer() was drawn

	if CLIENT and self:IsCarriedByLocalPlayer() and not ply:ShouldDrawLocalPlayer() then
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
	if self.AttachesToPlayer and IsValid( self:GetControllingPlayer() ) then
		return self:GetCustomParentOrigin()
	end
end

function ENT:EmitPESound( soundname , level , pitch , volume , chan , predicted , onlytolocalplayer )
	if not level then
		level = 75
	end
	
	if not pitch then
		pitch = 100
	end
	
	if not volume then
		volume = 1
	end
	
	if not chan then
		chan = CHAN_AUTO
	end
	
	if SERVER then
		local plys = {}
		if onlytolocalplayer then
			plys = self:GetControllingPlayer()
		else
			for i , v in pairs( player.GetHumans() ) do
				if ( predicted and v ~= self:GetControllingPlayer() ) or not predicted then
					plys[#plys] = v
				end
			end
		end
		
		if ( type( plys ) == "Player" and not IsValid( plys ) ) or #plys == 0 then
			return
		end
		
		net.Start( "pe_playsound" )
			net.WriteEntity( self )
			net.WriteString( soundname )
			net.WriteFloat( level )
			net.WriteFloat( pitch )
			net.WriteFloat( volume )
			net.WriteInt( chan , 8 )
		net.Send( plys )
			
	else
		self:EmitSound( soundname , level , pitch , volume , chan )
	end
end

--stuff that should be in an autorun file but that I can't be arsed to split up to

if SERVER then
	
	util.AddNetworkString( "pe_pickup" )
	util.AddNetworkString( "pe_playsound" )
	
	--can be either called manually or from the derma when the user uses the context menu
	
	concommand.Add( "pe_drop" , function( ply , cmd , args , fullstr )
		
		if not IsValid( ply ) then
			return
		end
		
		local nwslot = args[1]
		
		if not nwslot then
			return
		end
		
		local slotent = ply:GetNWEntity( nwslot )
		
		--user tried to drop an invalid or an entity which is not a predicted entity, or doesn't have a slot assigned
		
		if not IsValid( slotent ) or not slotent.IsPredictedEnt or slotent:GetSlotName() == "" then
			return
		end
		
		slotent:Drop( false )
		
	end)
else
	
	--tells the hud to show the player the entity pickup
	language.Add( "invalid_entity" , "Invalid Entity" )
	
	net.Receive( "pe_pickup" , function( len )
		local str = net.ReadString()
		if str then
			gamemode.Call( "HUDItemPickedUp" , str )
		end
	end)
	
	net.Receive( "pe_playsound" , function( len )
		local ent = net.ReadEntity()
		
		if not IsValid( ent ) or not ent.EmitPESound then
			return
		end
		
		local soundname = net.ReadString() --yes I know that I can do util.addnetworkstring to
		
		local level = net.ReadFloat()
		local pitch = net.ReadFloat()
		local volume = net.ReadFloat()
		local chan = net.ReadInt( 8 )
		
		ent:EmitPESound( soundname , level , pitch , volume , chan )
	end)
	
	
	--register a panel of type DPredictedEnt , which will show a rounded button with stencils, that
	--when pressed will execute drop_pe <slotname>
	--the button will call a callback when it's drawn , which can be overridden by a child class to show variables
	--such as fuel or whatever
	
end