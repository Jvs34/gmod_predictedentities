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
ENT.DropOnDeath = true

if SERVER then
	ENT.ShowPickupNotice = false	--plays the pickup sound and shows the pickup message on the hud
else
	ENT.RenderGroup = RENDERGROUP_OPAQUE
	ENT.MainPanel = nil
end

ENT.Editable = true
ENT.InButton = 0 --set this to an unused IN_ enum and make sure it's not used by other predicted entities

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

function ENT:DefineNWVar( dttype , dtname , editable , beautifulname , minval , maxval , customelement )
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
	
	local edit = nil
	
	if editable and self.DefinedDTVars[dttype].EditableElement then
		edit = {
			KeyName = dtname:lower(),
			Edit = {
				title = beautifulname or dtname,
				min = minval,
				max = maxval,
				type = customelement or self.DefinedDTVars[dttype].EditableElement,
			}
		}
	end
	
	self:NetworkVar( dttype , index , dtname , edit )
end

function ENT:SetupDataTables()
	
	--eventually I'll create more editable elements based on garry's system
	--also there's the problem that in some cases you might want the Vector to be editable with an actual world vector
	--and in others as a direction
	--and in some others as a color ( goddamn garry )
	
	self.DefinedDTVars = {
		Entity = {
			Max = GMOD_MAXDTVARS,
		--	EditableElement = "PickEnt",	--TODO: an element that uses the worldpicker shit or the same the context menu uses
		},
		Float = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Float",
		},
		Int = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Int",
		--	EditableElement = "EditKey", --TODO: a copypaste of the one used by garry for the tools
		},
		Bool = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Boolean",
		},
		Vector = {
			Max = GMOD_MAXDTVARS,
			--FUCK
		--	EditableElement = "VectorNormal",	--TODO
		--	EditableElement = "VectorOrigin",	--TODO
		--	EditableElement = "VectorColor",
		},
		Angle = {
			Max = GMOD_MAXDTVARS,
		--	EditableElement = "VectorNormal", --I guess?
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

	hook.Add( "StartCommand", self, self.HandlePredictedStartCommand )
	hook.Add( "SetupMove", self, self.HandlePredictedSetupMove )
	hook.Add( "Move", self, self.HandlePredictedMove )
	hook.Add( "PlayerTick", self, self.HandlePredictedThink )
	hook.Add( "FinishMove", self, self.HandlePredictedFinishMove )

	if SERVER then
		hook.Add( "EntityRemoved" , self , self.OnControllerRemoved )
		hook.Add( "PostPlayerDeath" , self , self.OnControllerDeath )	--using PostPlayerDeath as it's called on all kind of player deaths, event :KillSilent()
		self:SetUseType( SIMPLE_USE ) --don't allow continuous use
	else
		hook.Add( "PostDrawViewModel" , self , self.DrawFirstPersonInternal )
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

		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:PhysWake()
		self:SetLagCompensated( true )
		self:OnInitPhysics( self:GetPhysicsObject() )
	end

	function ENT:RemovePhysics()
		if not IsValid( self:GetPhysicsObject() ) then
			return
		end

		self:PhysicsDestroy()
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		self:SetLagCompensated( false )
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
			self:EmitPESound( "HL2Player.UseDeny" , nil , nil , nil , nil , nil , activator )
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
			self:EmitSound( "HL2Player.PickupWeapon" )
			
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
	
	function ENT:OnControllerDeath( ply )
		if self.DropOnDeath and IsValid( self:GetControllingPlayer() ) and self:GetControllingPlayer() == ply then
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
	
	--TODO: stop using the viewmodel draw hook and simply create a new 3d cam from renderscene
	--viewmodels don't draw without an associated weapon ( this is due to garryness, they always do in source )
	function ENT:DrawFirstPersonInternal( vm , ply , wpn )
		if self.AttachesToPlayer and self:IsCarriedByLocalPlayer() and self:GetControllingPlayer() == ply then
			self:DrawFirstPerson( ply , vm ) --this will be moved to the renderscene hook
			self:DrawOnViewModel( ply , vm ) -- this will stay here
		end
	end
	
	function ENT:DrawFirstPerson( ply , vm )
		
	end
	
	function ENT:DrawOnViewModel( ply , vm )
	
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
	
	function ENT:HandleDerma()
		if IsValid( self.MainPanel ) then
			
			if self:IsCarriedByLocalPlayer() then
			
				if not self.MainPanel:HasSlot( self:GetSlotName() ) then
					self:RegisterHUDInternal( self.MainPanel )
				end
			
			else
				
				if self.MainPanel:HasSlot( self:GetSlotName() ) then
					self.MainPanel:RemovePanelBySlot( self:GetSlotName() )
				end
			end
		end
	end

	--NOTE: this works on a slot basis, not entity class, so it works 
	function ENT:RegisterHUDInternal( parentpanel )
		--the parentpanel is a DVerticalLayout or whatever, depending on the user settings on where to show it
		--so we just want to create a button with a custom image display, and we'll leave the rest to the child class
		local mypanel = parentpanel:Add( "DPredictedEnt" )
		mypanel:SetSlot( self:GetSlotName() )	--automatically get the entity from the slot, if it's not valid then remove ourselves
		self:SetupCustomHUDElements( mypanel )
		return mypanel
	end
	
	--use this to add custom elements to the entity button in the HUD
	
	function ENT:SetupCustomHUDElements( panel )
		
	end
	
end

function ENT:IsKeyDown( mv )
	if self.InButton == 0 then
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
	if ply == self:GetControllingPlayer() then
		local predictedent = ply:GetNWEntity( self:GetSlotName() )
		if predictedent == self then
		
			--allows the user to have a fake keybind by manually checking his buttons instead of having the player bind a button to a command ( which most users don't even know anything about ).
			--he can configure this key at anytime by editing the entity ( if it allows it in the first place )
			
			if CLIENT and self.InButton > 0 then
				local mykey = self:GetKey()
				if not ( gui.IsGameUIVisible() or ply:IsTyping() ) then
					if mykey ~= BUTTON_CODE_NONE and mykey > BUTTON_CODE_NONE and mykey < BUTTON_CODE_COUNT then
						if input.IsButtonDown( mykey ) then
							cmd:SetButtons( bit.bor( cmd:GetButtons() , self.InButton ) )
						end
					end
				end
			end
			
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
	
	if SERVER then
		local plys = {}
		if IsValid( activator ) and not predicted then
			plys = activator
		else
			for i , v in pairs( player.GetHumans() ) do
				
				if predicted and v == self:GetControllingPlayer() then
					continue
				end
				
				plys[#plys] = v
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
		self:EmitSound( soundname , level , pitch , volume , chan )
	end
end

function ENT:OnRemove()
	if CLIENT then
		if IsValid( self.MainPanel ) then
			if self.MainPanel:HasSlot( self:GetSlotName() ) then
				self.MainPanel:RemovePanelBySlot( self:GetSlotName() )
			end
		end
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
		
		local soundname = net.ReadString() --yes I know that I can do util.addnetworkstring to cache it but I cba
		
		local level = net.ReadFloat()
		local pitch = net.ReadFloat()
		local volume = net.ReadFloat()
		local chan = net.ReadInt( 8 )
		
		ent:EmitPESound( soundname , level , pitch , volume , chan )
	end)
	
	--register a panel of type DPredictedEntManager , which will create a vertical or horizontal layout depending on cvars
	--it will also position itself where the user wants it to with convars
	
	
	--register a panel of type DPredictedEnt , which will show a rounded button with stencils, that
	--when pressed will execute drop_pe <slotname>
	--the button will call a callback when it's drawn , which can be overridden by a child class to show variables
	--such as fuel or whatever
	
	
	
end