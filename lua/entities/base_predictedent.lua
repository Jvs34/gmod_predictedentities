AddCSLuaFile()

--[[
	This entity base is pretty much a streamlined version of my special action system ( that you might see used in scrapmatch )
	The advantages over that system is that these entities can be treated as normal entities when not equipped by a player, and as such, should
	allow for more freedom , such as being bundled in addons, editing variables with the right click
]]

DEFINE_BASECLASS( "base_entity" )
ENT.Spawnable = false
ENT.IsPredictedEnt = true
ENT.AttachesToPlayer = true	--whether this entity attaches to the player or not, when true this removes physics and draws the entity on the player

if SERVER then
	ENT.DropOnDeath = true
	ENT.ShowPickupNotice = false	--plays the pickup sound and shows the pickup message on the hud
else
	ENT.RenderGroup = RENDERGROUP_OPAQUE
end

ENT.Editable = true
ENT.InButton = 0	--set this to an unused IN_ enum ( using a raw number is fine, as long as it's below 32 bits ) and make sure it's not used by other predicted entities
					--if left 0 the user won't even see the key edit option

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
--actually, this'll stay here regardless, the editable thing garry added for the dt vars is quite neat

function ENT:DefineNWVar( dttype , dtname , editable , beautifulname , minval , maxval , customelement , filt )
	
	if not self.DefinedDTVars[dttype] then
		Error( "Wrong NWVar type " .. ( dttype or "nil" ) )
		return
	end

	local index = -1
	local maxindex = self.DefinedDTVars[dttype].Max

	for i = 0 , maxindex - 1 do
		
		--we either didn't find anything in this slot or we found the requested one again
		--in which case just override it again, someone might want to inherit and add an edit table or something
		if not self.DefinedDTVars[dttype][i] or self.DefinedDTVars[dttype][i] == dtname then
			index = i
			break
		end
	end

	if index == -1 then
		Error( "Not enough slots on "..dttype .. ",	could not add ".. dtname )
		return
	end

	self.DefinedDTVars[dttype][index] = dtname
	
	local edit = nil
	
	if editable and self.DefinedDTVars[dttype].EditableElement then
		edit = {
			KeyName = dtname:lower(),
			Edit = {
				title = beautifulname or dtname,	--doesn't it do this internally already?
				min = minval,
				max = maxval,
				type = customelement or self.DefinedDTVars[dttype].EditableElement,
				filter = filt,	--can be either a function( like the util.TraceLine filter ) or a table of class name
								--this is not used at all by garry's edit tools, but it might be useful for me
			}
		}
	end
	
	self:NetworkVar( dttype , index , dtname , edit )
end

function ENT:SetupDataTables()
	
	--eventually I'll create more editable elements based on garry's system
	
	self.DefinedDTVars = {
		Entity = {
			Max = GMOD_MAXDTVARS,
		--	EditableElement = "ChooseEnt", --unfortunately can't do this because there's no fromstring for entity
		},
		Float = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Float",
		},
		Int = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Int",
		--	EditableElement = "EditKey", --TODO: a copypaste of the one used by garry for the sandbox tools
		--	EditableElement = "ChooseEnt", --TODO: we're gonna have to set the entity index here
		},
		Bool = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Boolean",
		},
		Vector = {
			Max = GMOD_MAXDTVARS,
		--	EditableElement = "VectorOrigin",	--TODO: allow the player to choose a world position
		--	EditableElement = "VectorNormal",	--TODO: make players move a 3d arrow in a model panel?
		--	EditableElement = "VectorColor",	
		},
		Angle = {
			Max = GMOD_MAXDTVARS,
		--	EditableElement = "VectorNormalToAngle", --TODO: inherited from VectorNormal
		},
		String = {
			Max = 4, --as I said before, fuck strings
			EditableElement = "Generic",
		},
	}

	self:DefineNWVar( "Entity" , "ControllingPlayer" )
	self:DefineNWVar( "Bool" , "BeingHeld" )
	self:DefineNWVar( "String" , "SlotName" )
	self:DefineNWVar( "Float" , "NextFire" )
	
	--only allow the user to modify the button if the coder wants this entity to have an usable key
	
	if self.InButton == 0 then
		self:DefineNWVar( "Int" , "Key" )
	else
		self:DefineNWVar( "Int" , "Key" , true , "Button" , BUTTON_CODE_NONE + 1 , BUTTON_CODE_LAST , "EditKey" )
	end
end

function ENT:Initialize()
	self.HandledHooks = {}
	
	--predicted hooks hooking with hookers, but not blackjack
	self:InstallHook( "StartCommand" , self.HandlePredictedStartCommand )
	self:InstallHook( "SetupMove" , self.HandlePredictedSetupMove )
	self:InstallHook( "Move" , self.HandlePredictedMove )
	self:InstallHook( "PlayerTick" , self.HandlePredictedThink )
	self:InstallHook( "FinishMove" , self.HandlePredictedFinishMove )
	self:InstallHook( "OnPlayerHitGround" , self.HandlePredictedHitGround )
	
	if SERVER then
		self:InstallHook( "EntityRemoved" , self.OnControllerRemoved )
		self:InstallHook( "PostPlayerDeath" , self.OnControllerDeath )	--using PostPlayerDeath as it's called on all kind of player deaths, event :KillSilent()
		self:SetUseType( SIMPLE_USE ) --don't allow continuous use, 
	else
		self:InstallHook( "PostDrawViewModel" , self.DrawFirstPersonInternal )
		self:InstallHook( "PostPlayerDraw" , self.DrawOnPlayer )
		self:InstallHook( "NetworkEntityCreated" , self.HandleFullPacketUpdate )
	end
end

--I haven't tested this yet, but I believe this is needed mostly for clientside hooks, since IsValid might return false when we're out of PVS
--and when hook.Call tries to call on an invalid entity it removes the hook, so we need to reinstall them when that happens and the entity gets back in the PVS
--prediction and other shit like drawing on a player might fuck up since the hooks got removed

function ENT:InstallHook( hookname , handler , iscallback )
	if iscallback then
		self:AddCallback( hookname , handler )
	else
		self.HandledHooks[hookname] = handler
	end
end

function ENT:HandleHooks()

	--this is direct access to the hook table, but it's not slow at all
	local hooktable = hook.GetTable()
	
	for i , v in pairs( self.HandledHooks ) do
		if not hooktable[i] or not hooktable[i][self]then
			hook.Add( i , self , v )
		end
	end
end

function ENT:Think()

	self:HandleHooks()
	
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
		self:HandleDerma()
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
		
		self:SetLagCompensated( true )
		
		self:DoInitPhysics()
		self:OnInitPhysics( self:GetPhysicsObject() )
	end
	
	function ENT:DoInitPhysics()
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:PhysWake()
	end

	function ENT:RemovePhysics()
		if not IsValid( self:GetPhysicsObject() ) then
			return
		end
		
		if self.AttachesToPlayer then
			self:SetLagCompensated( false )--lag compensation works really lame with parenting due to vinh's fix to players being lag compensated in vehicles
		end
		
		self:OnRemovePhysics( self:GetPhysicsObject() )
		self:DoRemovePhysics()
	end
	
	function ENT:DoRemovePhysics()
		self:PhysicsDestroy()
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
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

	function ENT:Attach( activator , forced )
		
		--we were forced to attach to this player, so drop first to clear out values
		if forced then
			self:Drop( forced )
		end
	
		if not IsValid( activator ) or not activator:IsPlayer() then
			return false
		end
		
		if IsValid( self:GetControllingPlayer() ) or IsValid( activator:GetNWEntity( self:GetSlotName() ) ) then
			self:EmitPESound( "HL2Player.UseDeny" , 150 , nil , 1 , nil , nil , activator )
			return false
		end
		
		if self.AttachesToPlayer then
			self:RemovePhysics()
			self:SetParent( activator )
			self:SetOwner( activator )
			self:SetTransmitWithParent( true )
			self:SetNoDraw( true )
		end

		if self.ShowPickupNotice then
			self:EmitSound( "HL2Player.PickupWeapon" )
			
			if not activator:IsBot() then
				net.Start( "pe_pickup" )
					net.WriteString( self:GetClass() )
				net.Send( activator )
			end
		end
		
		activator:SetNWEntity( self:GetSlotName() , self )
		self:SetControllingPlayer( activator )
		
		self:OnAttach( self:GetControllingPlayer() , forced )
		return true
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
			self:GetControllingPlayer():SetNWEntity( self:GetSlotName() , NULL )
		end

		self:SetControllingPlayer( NULL )
		return true
	end
	
	--we want to get properly dropped when the player entity gets removed ( aka after a disconnect )
	--why not use the disconnect hook? no.
	
	function ENT:OnControllerRemoved( ent )
		if self:IsCarriedBy( ent ) then
			self:Drop( true )
		end
	end
	
	function ENT:OnControllerDeath( ply )
		if self.DropOnDeath and self:IsCarriedBy( ply ) then
			self:Drop( true )
		end
	end

else

	function ENT:IsCarriedByLocalPlayer()
		return self:IsCarriedBy( LocalPlayer() )
	end
	
	function ENT:IsLocalPlayerUsingMySlot()
		local ent = LocalPlayer():GetNWEntity( self:GetSlotName() )
			
		if not IsValid( ent ) then
			return false
		end
			
		return ent ~= self
	end
	
	--when a full packet gets received by the client, this hook is called, so we need to reset the IsPredictable var because this shit sucks!
	--TODO: when the update gets pushed with the new behaviour, disable this
	
	function ENT:HandleFullPacketUpdate( ent )
		if ent == self then
			self.IsPredictable = false
		end
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
	
	--TODO: stop using the viewmodel draw hook and simply create a new 3d cam from renderscene
	--viewmodels don't draw without an associated weapon ( this is due to garryness, they always do in source )
	function ENT:DrawFirstPersonInternal( vm , ply , wpn )
		if self.AttachesToPlayer and self:IsCarriedBy( ply ) then
			self:DrawFirstPerson( ply , vm ) --this will be moved to the renderscene hook
			self:DrawOnViewModel( ply , vm , ply:GetHands() ) --this will stay here
		end
	end
	
	function ENT:DrawFirstPerson( ply , vm )
		
	end
	
	--mainly used to draw stuff like shields, gloves or whatever on the viewmodel hands
	
	function ENT:DrawOnViewModel( ply , vm , hands )
	
	end
	
	function ENT:DrawOnPlayer( ply )
		if self.AttachesToPlayer and self:IsCarriedBy( ply ) then
			self:DrawModel()
		end
	end

	function ENT:Draw( flags )
		self:DrawModel()
	end
	
	--UGLEH as sin
	function ENT:GetMainPanel()
		return PE_HUD or self.MainHUDPanel
	end
	
	function ENT:HandleDerma()
		--we only want to do these operations if the player does NOT have another entity in this slot
		if IsValid( self:GetMainPanel() ) and not self:IsLocalPlayerUsingMySlot() then
			if self:IsCarriedByLocalPlayer() then
				self:RegisterHUDInternal( self:GetMainPanel() )
			else
				self:RemoveHUDPanel( self:GetMainPanel() )
			end
		end
	end

	function ENT:RegisterHUDInternal( parentpanel )
		if parentpanel:HasSlot( self:GetSlotName() ) then
			return
		end
		
		local mypanel = vgui.Create( "DPredictedEnt" )
		mypanel:SetSlot( self:GetSlotName() )
		self:SetupCustomHUDElements( mypanel )
		parentpanel:AddPEPanel( mypanel )
	end
	
	function ENT:RemoveHUDPanel( panel )
		if not panel:HasSlot( self:GetSlotName() ) then
			return
		end
		
		panel:RemovePanelBySlot( self:GetSlotName() )
	end
	
	--use this to add custom elements to the entity button in the HUD
	
	function ENT:SetupCustomHUDElements( panel )
		
	end
end

function ENT:IsCarriedBy( ply )
	return IsValid( ply ) and ply == self:GetControllingPlayer() and self:GetControllingPlayer():GetNWEntity( self:GetSlotName() ) == self
end

function ENT:IsKeyDown( mv )

	if self.InButton <= 0 then
		return false
	end
	
	if IsValid( self:GetControllingPlayer() ) then
		if mv then
			return mv:KeyDown( self.InButton )
		end
		return self:GetControllingPlayer():KeyDown( self.InButton )
	end
	
	return false
end

function ENT:HandlePredictedStartCommand( ply , cmd )
	if self:IsCarriedBy( ply ) then
		--allows the user to have a fake keybind by manually checking his buttons instead of having the player bind a button to a command ( which most users don't even know anything about ).
		--he can configure this key at anytime by editing the entity ( if it allows it in the first place )
		if CLIENT and self.InButton > 0 then
			local mykey = self:GetKey()
			if not ( gui.IsGameUIVisible() or ply:IsTyping() ) then
				if mykey > BUTTON_CODE_NONE and mykey < BUTTON_CODE_COUNT then
					if input.IsButtonDown( mykey ) then
						cmd:SetButtons( bit.bor( cmd:GetButtons() , self.InButton ) )
					end
				end
			end
		end
		
		self:PredictedStartCommand( ply , cmd )
	end
end

function ENT:HandlePredictedSetupMove( ply , mv , cmd )
	if self:IsCarriedBy( ply ) then
		if self:PredictedSetupMove( ply , mv , cmd ) then
			return true
		end
	end
end

function ENT:HandlePredictedMove( ply , mv )
	if self:IsCarriedBy( ply ) then
		if self:PredictedMove( ply , mv ) then
			return true
		end
	end
end

function ENT:HandlePredictedThink( ply , mv )
	if self:IsCarriedBy( ply ) then
		self:PredictedThink( ply , mv )
	end
end

function ENT:HandlePredictedFinishMove( ply , mv )
	if self:IsCarriedBy( ply ) then
		if self:PredictedFinishMove( ply , mv ) then
			return true
		end
	end
end

function ENT:HandlePredictedHitGround( ply , inwater , onfloater , speed )
	if self:IsCarriedBy( ply ) then
		if self:PredictedHitGround( ply , inwater , onfloater , speed ) then
			return true
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

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )

end

--Allows for predicted movement simulation on non player entities, without disrupting the player movement itself
--FinishMove should be the best place for this, since even in case of fuckups, the rest of the movement should be fine

--[[
	function ENT:PredictedFinishMove( ply , mv )
		
		local sv = self:BackupMoveData( mv )
		
		--set the data you want on the movedata, such as the entity origin, speed, angles and stuff
		
		--run the entity traces
		
		--set the final position of the entity here with the same way garry does ( see drive.End or whatever it's called )
		
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

function ENT:EmitPESound( soundname , level , pitch , volume , chan , predicted , activator )
	
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
	
	if game.SinglePlayer() then
		predicted = false
	end
	
	if SERVER then
	
		local plys = {}
		if IsValid( activator ) and not predicted and not activator:IsBot() then
			plys = activator
		else
			for i , v in pairs( player.GetHumans() ) do
				
				if predicted and v == self:GetControllingPlayer() then
					continue
				end
				
				if not v:IsBot() then
					plys[#plys] = v
				end
			end
			
			if #plys == 0 then
				return
			end
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
		if ( IsFirstTimePredicted() and predicted ) or not predicted then
			self:EmitSound( soundname , level , pitch , volume , chan )
		end
	end
end

function ENT:OnRemove()
	if CLIENT then
		if IsValid( LocalPlayer() ) then
			if IsValid( self:GetMainPanel() ) and not self:IsLocalPlayerUsingMySlot() then
				self:RemoveHUDPanel( self:GetMainPanel() )
			end
		end
	end
end

--stuff that should be in an autorun file but that I can't be arsed to split up to

if CLIENT then
	
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
		
		local soundname = net.ReadString() --yes I know that I can do util.addnetworkstring to cache it but I cba
		
		local level = net.ReadFloat()
		local pitch = net.ReadFloat()
		local volume = net.ReadFloat()
		local chan = net.ReadInt( 8 )
		
		ent:EmitPESound( soundname , level , pitch , volume , chan , false )
	end)
end