AddCSLuaFile()

--[[
	An entity base that allows you to create entity that can be equipped by the player as if they were weapons or powerups, but that can still 
	function when not picked up by a player
	
	For instance you could make a jetpack that flies off when the equipping player dies, or you can make a controllable plane but still allow
	full movement on the player
]]

DEFINE_BASECLASS( "base_entity" )

ENT.UseNWVars = false

ENT.Spawnable = false
ENT.IsPredictedEnt = true
ENT.AttachesToPlayer = true	--whether this entity attaches to the player or not, when true this removes physics and draws the entity on the player

if SERVER then
	ENT.DropOnDeath = true
	ENT.ShowPickupNotice = false	--plays the pickup sound and shows the pickup message on the hud
	ENT.DontTransmitToOthers = false --when true, don't transmit to anyone except the owner, this MIGHT conflict with addons that make use of SetPreventTransmit, so mind that!
	ENT.ShouldLagCompensate = true 	--automatically enables/disables lag compensation when physics are created and destroyed, might be annoying for some so disable this if you want
else
	ENT.RenderGroup = RENDERGROUP_OPAQUE
end

ENT.Editable = true

ENT.KeyAllowedKeyboard = 2 ^ 0
ENT.KeyAllowedMouse = 2 ^ 1
ENT.KeyAllowedJoystick = 2 ^ 2

ENT.KeyAllowedAll = bit.bor( ENT.KeyAllowedKeyboard , ENT.KeyAllowedMouse , ENT.KeyAllowedJoystick )

ENT.KeyAllowedFlags = ENT.KeyAllowedAll	--bitflag of the key types you want to use

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
	
	--only do this check for limited dtvars, once we switch to NWVars in :NetworkVar this check will go away
	if not self.UseNWVars then
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
	else
		index = dtname:lower()
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
			}
		}
	end

	self:NetworkVar( dttype , index , dtname , edit )
end

function ENT:SetupDataTables()

	--if the user is in the branch that has the NWVars change then automatically switch to this
	if self.CallNetworkProxies then
		self.UseNWVars = true
	end
	
	--eventually I'll create more editable elements based on garry's system
	
	self.DefinedDTVars = {
		Entity = {
			Max = GMOD_MAXDTVARS,
		},
		Float = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Float",
		},
		Int = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Int",
		},
		Bool = {
			Max = GMOD_MAXDTVARS,
			EditableElement = "Boolean",
		},
		Vector = {
			Max = GMOD_MAXDTVARS,
		},
		Angle = {
			Max = GMOD_MAXDTVARS,
		},
		String = {
			Max = 4,
			EditableElement = "Generic",
		},
	}
	
	self:DefineNWVar( "Entity" , "ControllingPlayer" )
	self:DefineNWVar( "Bool" , "BeingHeld" )
	self:DefineNWVar( "String" , "SlotName" )
	self:DefineNWVar( "Float" , "NextFire" )
	
	--only allow the user to modify the button if the coder wants this entity to have an usable key
	
	self:DefineNWVar( "Int" , "InButton" )
	self:DefineNWVar( "Int" , "Key" , true , "Button" , BUTTON_CODE_NONE + 1 , BUTTON_CODE_LAST , "EditKey" )
end

function ENT:Initialize()
	self.HandledHooks = {}
	
	--predicted hooks hooking with hookers, and blackjack, actually, screw the blackjack
	self:InstallHook( "StartCommand" , self.HandlePredictedStartCommand )
	self:InstallHook( "SetupMove" , self.HandlePredictedSetupMove )
	self:InstallHook( "Move" , self.HandlePredictedMove )
	self:InstallHook( "PlayerTick" , self.HandlePredictedThink )
	self:InstallHook( "FinishMove" , self.HandlePredictedFinishMove )
	self:InstallHook( "OnPlayerHitGround" , self.HandlePredictedHitGround )
	self:InstallHook( "CalcMainActivity" , self.HandleCalcMainActivity )
	self:InstallHook( "UpdateAnimation" , self.HandleUpdateAnimation )
	self:InstallHook( "DoAnimationEvent" , self.HandleAnimationEvent )
		
	if SERVER then
		self:InstallHook( "SetupPlayerVisibility" , self.HandleEntityVisibility )
		self:InstallHook( "EntityRemoved" , self.OnControllerRemoved )
		self:InstallHook( "PostPlayerDeath" , self.OnControllerDeath )	--using PostPlayerDeath as it's called on all kind of player deaths, even :KillSilent()
		self:InstallHook( "CanEditVariable" , self.HandleCanEditVariable )
		
		--just in case it has been spawned manually and the coder forgot
		if self:GetSlotName() == "" then
			ErrorNoHalt( self:GetClass() .. " was spawned without a slotname!!!!. Defaulting to classname\n" )
			self:SetSlotName( self:GetClass() )
		end
		
		self:SetUseType( SIMPLE_USE )
		self:SetInButton( 0 )	--set this to an IN_ enum ( using a raw number is fine, as long as it's below 32 bits )
		self:SetKey( BUTTON_CODE_NONE )
	else
		self:InstallHook( "PreDrawEffects" , self.DrawFirstPersonInternal )
		self:InstallHook( "PostDrawViewModel" , self.DrawViewModelInternal )
		self:InstallHook( "PostPlayerDraw" , self.DrawOnPlayer )
		self:InstallHook( "NotifyShouldTransmit" , self.HandleFullPacketUpdate )
		
		language.Add( self:GetClass() , self.PrintName )
		language.Add( "dropped_"..self:GetClass() , "Dropped "..self.PrintName )
	end
end

--This is needed mostly for clientside hooks, since IsValid might return false when we're out of PVS with some bad lag
--and when hook.Call tries to call on an invalid entity it removes the hook, so we need to reinstall them when that happens and the entity gets back in the PVS
--prediction and other shit like drawing on a player might fuck up since the hooks got removed
--Now this also works for adding a callback

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
		if not hooktable[i] or not hooktable[i][self] then
			hook.Add( i , self , v )
		end
	end
end

function ENT:Think()

	self:HandleHooks()
	
	if SERVER then
	
		--check if this guy is still my parent and owner, maybe something is forcibly unparenting us from him, if so, drop
		if self.AttachesToPlayer and self:IsCarried() then
			if not self:IsAttached() then
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
		self:InternalHandleLoopingSounds()
	end
	
	--set our think rate to be in line with the server tickrate
	--this may also affect animations clientside if they're ran in this hook, considering that also happens in normal source
	--I'd say that's an accurate replication of the issue
	
	--default behaviour for scripted entities is to think every 200 milliseconds
	
	self:NextThink( CurTime() + engine.TickInterval() )
	return true
end

if SERVER then
	
	--for map inputs mostly, but other addons may also be using these inputs trough ent:Input or ent:Fire
	--more inputs might come in the future
	
	function ENT:AcceptInput( inputName, activator, called, data )
		
		if inputName == "Drop" then
			self:Drop( true )
			return true
		end
		
		if inputName == "SetSlotName" then
			if self:IsCarried() or not data or #data <= 1 or data == self:GetSlotName() then
				return false
			end
			
			self:SetSlotName( data )
			return true
		end
		
	end
	--although we should probably do validity checks on them first, but considering this would *probably* be called from maps it should be ok
	--copied from env_skypaint, allows to have the DT vars set as if they were key values
	
	function ENT:KeyValue( key, value )

		if self:SetNetworkKeyValue( key, value ) then
			return
		end

	end
	
	function ENT:Use( activator, caller, useType, value )
		if not self:Attach( activator ) then
			self:EmitPESound( "HL2Player.UseDeny" , 150 , nil , 1 , nil , nil , activator )
		end
	end

	function ENT:InitPhysics()
		--don't actually initialize the physics if we're getting removed anyway
		if self:IsEFlagSet( EFL_KILLME ) then 
			return 
		end
		
		
		if self.ShouldLagCompensate then
			self:SetLagCompensated( true )
		end

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
		
		if self.AttachesToPlayer and self.ShouldLagCompensate then
			self:SetLagCompensated( false )	--entities that are attached to players will be moved back when the player is, so don't make them lag compensate on their own
		end
		
		self:OnRemovePhysics( self:GetPhysicsObject() )
		self:DoRemovePhysics()
	end
	
	function ENT:DoRemovePhysics()
		self:PhysicsDestroy()
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
	end
	
	function ENT:OnAttach( ply , forced )
		--override me
	end
	
	function ENT:CanAttach( ply )
		--override me
	end

	function ENT:OnDrop( ply , forced )
		--override me
	end
	
	function ENT:CanDrop( ply )
		--override me
	end

	--these two are not necessarely duplicates of the functions above because we may want to modify the mass
	--as soon as the physobj gets created, and that also happens in initialize

	function ENT:OnInitPhysics( physobj )
		--override me
	end

	function ENT:OnRemovePhysics( physobj )
		--override me
	end
	
	--being attached forcibly is usually something that happens when you want to spawn the player with this item, and you
	--don't want gamemode logic to interfere with it
	function ENT:Attach( activator , forced )
		
		--we were forced to attach to this player, so drop first to clear out some values
		if forced then
			self:Drop( forced )
		end
		
		if not IsValid( activator ) or not activator:IsPlayer() then
			return false
		end
		
		--we're carried in general OR that guy's using that slot already
		if self:IsCarried() or IsValid( self.GetOnPlayer( activator , self:GetSlotName() ) ) then
			return false
		end
		
		--we can allow the coder or gamemode to only stop the pickup if it's not forced
		if not forced then
			--simulate ourselves being a normal item pickup
			--the reason we're asking this first, is that first we want to make sure the gamemode is OK with us being able to pickup this entity
			local canattach = hook.Run( "PlayerCanPickupItem" , activator , self )
			
			--THEN we ask the coder if he really wants us to pickup his entity, in case it's out of "ammo", or some other restrictions
			local mycanattach = self:CanAttach( activator )
			if mycanattach == false then
				canattach = mycanattach
			end
			
			if canattach == false then
				return canattach
			end
		end
		
		if self.AttachesToPlayer then
			self:RemovePhysics()
			self:SetParent( activator )
			self:SetOwner( activator )
			self:SetTransmitWithParent( true )
			self:SetNoDraw( true )
			self:AddEFlags( EFL_NO_PHYSCANNON_INTERACTION )
		end

		self:SendItemMessage( activator , false )
		
		self.SetOnPlayer( self:GetControllingPlayer() , self:GetSlotName() , self )
		self:SetControllingPlayer( activator )
		
		self:OnAttach( self:GetControllingPlayer() , forced )
		return true
	end

	function ENT:Drop( forced )
		
		--we can allow the coder to only stop the drop if it's not forced
		if not forced then
			local candrop = self:CanDrop( self:GetControllingPlayer() )
		
			if candrop == false then
				return candrop
			end
		end
		
		if self.AttachesToPlayer then
			self:SetParent( NULL )
			self:SetOwner( NULL )
			self:InitPhysics()
			self:SetTransmitWithParent( false )
			self:SetNoDraw( false )
			self:RemoveEFlags( EFL_NO_PHYSCANNON_INTERACTION )
		end
		
		if not forced and self:IsCarried() then
			self:SendItemMessage( self:GetControllingPlayer() , true )
		end
		
		--only call OnDrop if we had a player controlling us, don't do it if we were just sweeping up some unclean values
		if self:IsCarried() then
			self:OnDrop( self:GetControllingPlayer() , forced )
			self.SetOnPlayer( self:GetControllingPlayer() , self:GetSlotName() , NULL )
		end

		self:SetControllingPlayer( NULL )
		return true
	end
	
	function ENT:SendItemMessage( activator , dropped )
		if dropped == nil then
			dropped = false
		end
		--GetShouldPlayPickupSound is actually a Lua table value that is then checked in c++, so it starts out as nil, wow garry
		if self.ShowPickupNotice and ( self:GetShouldPlayPickupSound() == nil or self:GetShouldPlayPickupSound() ) then
			
			if not dropped then
				self:EmitSound( "HL2Player.PickupWeapon" )
			else
				self:EmitSound( "Weapon_Crowbar.Single" )
			end
			
			if not activator:IsPlayer() or not activator:IsBot() then
				net.Start( "pe_pickup" )
					net.WriteString( self:GetClass() )
					net.WriteBit( dropped )
				net.Send( activator )
			end
		end
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
	
	--we're redoing this even though it's hooked up in sandbox because someone might want to use this in another gamemode ( such as ttt or whatever )
	function ENT:HandleCanEditVariable( ent , ply , key , val , editor )
		if ent == self then
			local allow = self:CanPlayerEditVariable( ply , key , val , editor )
			
			if key == "Key" then
				local btn = tonumber( val )
				if btn and not self:IsKeyAllowed( btn ) then
					allow = false
				end
			end
			
			--call the editkey hook only if the other one didn't say anything in the matter for this
			if key == "Key" and allow == nil then
				allow = self:CanEditKey( ply , val , editor )
			end
			
			--we'll only override all the hooks if the answer is yes or no, nil keeps the default behaviour
			if allow ~= nil then
				return allow
			end
		end
	end
	
	--our key can only be modified by the carrying player or by anyone if it's not carried at all
	function ENT:CanEditKey( ply , val , editor )
		--you could override me if you want to, you could leave your friends behind
		return self:IsCarriedBy( ply ) or not self:IsCarried()
	end
	
	function ENT:CanPlayerEditVariable( ply , key , val , editor )
		--override me
	end
	
	--we add this entity's position to the visibility position, but only if it doesn't attach to the player
	function ENT:HandleEntityVisibility( ply , viewent )
		if self:IsCarriedBy( ply ) and not self.AttachesToPlayer and self ~= viewent then --viewents already add themselves to the pvs
			AddOriginToPVS( self:GetPos() )
		end
		
		--HOW CONVENIENT!!! this hook is called before the client computes what he can see
		--so we can simply use this before this entity gets recomputed for transmission
		if self.DontTransmitToOthers and not game.SinglePlayer() then
			
			local shouldpreventtransmit = false
			
			if self:IsCarried() then
				shouldpreventtransmit = not self:IsCarriedBy( ply , true )
			end
			
			self:SetPreventTransmit( ply , shouldpreventtransmit )
		end
	end

else

	function ENT:InternalHandleLoopingSounds( calledinprediction )
		--the calledinprediction variable makes it so HandleLoopingSounds is called from ENT:Think instead
		--and yes, this will never be set at all during singleplayer because there's no prediction
		
		--if this is set then there's no need to call iscarried checks below, we're always called when that happens
		if calledinprediction and not IsFirstTimePredicted() then
			return
		end
		
		if game.SinglePlayer() or not self:IsCarried() or not self:IsCarriedByLocalPlayer() or ( self:IsCarriedByLocalPlayer() and calledinprediction ) then
			self:HandleLoopingSounds()
		end
	end
	
	function ENT:HandleLoopingSounds()
		--override me
	end
	
	function ENT:IsCarriedByLocalPlayer( checkspectator )
		
		--moved this logic to IsCarriedBy
		--[[
		if checkspectator then
			if LocalPlayer():GetObserverMode() ~= OBS_MODE_NONE then
				return self:IsCarriedBy( LocalPlayer():GetObserverTarget() )
			end
		end
		]]
		
		return self:IsCarriedBy( LocalPlayer() , checkspectator )
	end
	
	function ENT:ShouldDrawLocalPlayer( checkspectator )
		if checkspectator then
			if LocalPlayer():GetObserverMode() == OBS_MODE_IN_EYE and IsValid( LocalPlayer():GetObserverTarget() ) then
				if LocalPlayer():GetObserverTarget():IsPlayer() then
					return LocalPlayer():GetObserverTarget():ShouldDrawLocalPlayer() --assuming this even works, otherwise just return false
				end
				return false
			end
		end
		return LocalPlayer():ShouldDrawLocalPlayer()
	end
	
	--immediately make this entity predicted again, if it's equipped by this localplayer
	function ENT:HandleFullPacketUpdate( ent , shouldtransmit )
		if ent == self and shouldtransmit then
			self:HandlePrediction()
		end
	end
	
	function ENT:HandlePrediction()
	
		local carried = self:IsCarriedByLocalPlayer()
		
		--either the gravity gun or some other stuff is carrying me, don't do anything on prediction
		--because they might enable it to carry us around smoothly
		--also don't enable prediction in singleplayer
			
		if self:GetBeingHeld() or game.SinglePlayer() then
			return
		end
				
		if self:GetPredictable() ~= carried then
			self:SetPredictable( carried )
		end
	end
	
	function ENT:HandleButtonBind( ply , cmd )
		
		--don't even bother if the InButton isn't set or the player is already pressing the button on his own
		--maybe someone wants the entity to be activated by an IN_ enum used by player movement or something
		
		if self:GetInButton() > 0 and bit.band( cmd:GetButtons() , self:GetInButton() ) == 0 then
			local mykey = self:GetKey()
			if not ( gui.IsGameUIVisible() or ply:IsTyping() ) then
				
				--these checks are clientside, so they're not really *SECURE* per say, but using PlayerButtonDown/Up is kind of unreliable too ( for prediction at least )
				--plus the coder shouldn't really rely on this for security, but more of an utility
				if self:IsValidButton( mykey ) and input.IsButtonDown( mykey ) then
					if self:IsKeyAllowed( mykey ) then
						cmd:SetButtons( bit.bor( cmd:GetButtons() , self:GetInButton() ) )
					end
				end
			end
		end
	end
	
	function ENT:DrawFirstPersonInternal()
		if self.AttachesToPlayer and self:IsCarriedByLocalPlayer( true ) and not self:ShouldDrawLocalPlayer( true ) then
			cam.Start3D( nil , nil , nil , nil , nil , nil , nil , 1 , -1 )	--znear is 1 and zfar is -1
				render.DepthRange( 0 , 0.1 )	--same depth hack valve uses in source!
					self:DrawFirstPerson( self:GetControllingPlayer() )
				render.DepthRange( 0 , 1 )		--they don't even set these back to the original values
			cam.End3D()
		end
	end
	
	--viewmodels don't draw without an associated weapon ( this is due to garryness, they always do in source )
	--TODO: spectator support
	function ENT:DrawViewModelInternal( vm , ply , wpn )
		if self.AttachesToPlayer and self:IsCarriedBy( ply ) then
			self:DrawOnViewModel( ply , vm , ply:GetHands() ) --this will stay here
		end
	end
	
	function ENT:DrawFirstPerson( ply )
		--override me
	end
	
	--mainly used to draw stuff like shields, gloves or whatever on the viewmodel hands
	
	function ENT:DrawOnViewModel( ply , vm , hands )
		--override me
	end
	
	--the flags aren't passed yet, maybe in a future update
	
	function ENT:DrawOnPlayer( ply , flags )
		if self.AttachesToPlayer and self:IsCarriedBy( ply ) then
			self:DrawModel( flags )
		end
	end

	function ENT:Draw( flags )
		local pos , ang = self:GetCustomParentOrigin()
		--even though the calcabsoluteposition hook should already prevent this, it doesn't on other players
		--might as well not give it the benefit of the doubt in the first place
		if pos and ang then
			self:SetPos( pos )
			self:SetAngles( ang )
			self:SetupBones()
		end
		
		self:DrawModel( flags )
	end
	
end

--these are here to "unify" our two calls to SetNWEntity and GetNWEntity
--these might be called from pe_drop and some other stuff, so we can't rely on the entity itself being present, as lame as that is
function ENT.SetOnPlayer( ply , slot , ent )
	ply:SetNW2Entity( slot , ent )
end

function ENT.GetOnPlayer( ply , slot )
	return ply:GetNW2Entity( slot )
end

function ENT:IsAttached()
	local ply = self:GetControllingPlayer()
	return self:GetOwner() == ply and self:GetParent() == ply
end

--LOOK I DON'T CARE, this check is lame as shit but I can't be arsed to add duplicated code
function ENT:IsCarried()
	return self:IsCarriedBy( self:GetControllingPlayer() )
end

function ENT:IsCarriedBy( ply , checkspectator )
	
	if checkspectator and ply:GetObserverMode() ~= OBS_MODE_NONE then
		return self:IsCarriedBy( ply:GetObserverTarget() )
	end
	
	return IsValid( ply ) and ply == self:GetControllingPlayer() and self.GetOnPlayer( self:GetControllingPlayer() , self:GetSlotName() ) == self
end

function ENT:IsKeyDown( mv )

	if self:GetInButton() <= 0 then
		return false
	end
	
	if self:IsCarried() then
		if mv then
			return mv:KeyDown( self:GetInButton() )
		end
		return self:GetControllingPlayer():KeyDown( self:GetInButton() )
	end
	
	return false
end

function ENT:WasKeyPressed( mv )

	if self:GetInButton() <= 0 then
		return false
	end
	
	if self:IsCarried() then
		if mv then
			return mv:KeyPressed( self:GetInButton() )
		end
		return self:GetControllingPlayer():KeyPressed( self:GetInButton() )
	end
	
	return false
end

--these functions should totally not be tied to this SENT, but I don't want to go out of my way to add them to an util file
function ENT:IsValidButton( btn )
	return btn > BUTTON_CODE_NONE and btn < BUTTON_CODE_COUNT
end

function ENT:IsKeyboardButton( btn )
	return btn > KEY_FIRST and btn < KEY_COUNT
end

function ENT:IsMouseButton( btn )
	return btn >= MOUSE_FIRST and btn < MOUSE_LAST
end

function ENT:IsJoystickButton( btn )
	return btn >= JOYSTICK_FIRST and btn < JOYSTICK_LAST
end

function ENT:IsKeyAllowed( btn )
	if bit.band( self.KeyAllowedFlags , self.KeyAllowedKeyboard ) == 0 and self:IsKeyboardButton( btn ) then
		return false
	end
	
	if bit.band( self.KeyAllowedFlags , self.KeyAllowedMouse ) == 0 and self:IsMouseButton( btn ) then
		return false
	end
	
	if bit.band( self.KeyAllowedFlags , self.KeyAllowedJoystick ) == 0 and self:IsJoystickButton( btn ) then
		return false
	end
	
	return self:IsValidButton( btn )
end

function ENT:HandleCalcMainActivity( ply , velocity )
	if self:IsCarriedBy( ply ) then
		local calcideal , calcseqovr = self:HandleMainActivityOverride( ply , velocity )
		if calcideal and calcseqovr then
			return calcideal , calcseqovr
		end
	end
end

function ENT:HandleUpdateAnimation( ply, velocity, maxseqgroundspeed )
	if self:IsCarriedBy( ply ) then
		if self:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed ) then
			return true
		end
	end
end

function ENT:HandleAnimationEvent( ply, event, data )
	if self:IsCarriedBy( ply ) then
		if self:HandleAnimationEventOverride( ply , event , data ) then
			return ACT_INVALID
		end
	end
end

function ENT:HandleMainActivityOverride( ply , velocity )
	--override me
end

function ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
	--override me
end

function ENT:HandleAnimationEventOverride( ply , event , data )
	--override me
end

function ENT:HandlePredictedStartCommand( ply , cmd )
	if self:IsCarriedBy( ply ) then
	
		--allows the user to have a fake keybind by manually checking his buttons instead of having the player bind a button to a command ( which most users don't even know anything about ).
		--he can configure this key at anytime by editing the entity ( if it allows it in the first place )
		
		--startcommand is also called clientside in singleplayer, so this is fine
		if CLIENT then
			self:HandleButtonBind( ply , cmd )
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
		if CLIENT then
			self:InternalHandleLoopingSounds( true )
		end
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
	--override me
end

function ENT:PredictedSetupMove( ply , mv , cmd )
	--override me
end

function ENT:PredictedMove( ply , mv )
	--override me
end

function ENT:PredictedThink( ply , mv )
	--override me
end

function ENT:PredictedFinishMove( ply , mv )
	--override me
end

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
	--override me
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
	
	if not mv or not movedatameta then
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
		if setter and emptyvalues[TypeID( v )] ~= nil then
			setter( mv , emptyvalues[TypeID( v )] * 1 )
		end
	end
	
	return sv
end

function ENT:RestoreMoveData( mv , sv )
	if not mv or not sv or not movedatameta then
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
	
	--duplicated check, but people might call this manually in the entity draw hook, so gotta do this
	if not self:IsCarriedBy( ply ) then
		return
	end
	
	--Jvs:	I put this here because since the entity moves to the player bone matrix, it'll only be updated on the client
	--		when the player is actally drawn, or his bones are setup again ( which happens before a draw anyway )
	--		this also fixes sounds on the client playing at the last location the LocalPlayer() was drawn
	
	if CLIENT and self:IsCarriedByLocalPlayer( true ) and not self:ShouldDrawLocalPlayer( true ) then
		ply:SetupBones()
	end

	local boneid = ply:LookupBone( self.AttachmentInfo.BoneName )

	if not boneid then
		return
	end

	local matrix = ply:GetBoneMatrix( boneid )

	if not matrix then
		return
	end

	return LocalToWorld( self.AttachmentInfo.OffsetVec , self.AttachmentInfo.OffsetAng , matrix:GetTranslation() , matrix:GetAngles() )
end

--if we're attached to a player, use custom origin from the function above
--this is called shared, yes it's more expensive than source's normal parenting but it's worth it

function ENT:CalcAbsolutePosition( pos , ang )
	if self.AttachesToPlayer and self:IsCarried() then
		return self:GetCustomParentOrigin()
	end
end

function ENT:EmitPESound( soundname , level , pitch , volume , chan , predicted , activator , worldpos )
	
	--must've been called manually by some ent:Fire or ent:Input functions
	if IsValid( activator ) and not activator:IsPlayer() then
		activator = NULL
	end
	
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
	
	if not worldpos then
		worldpos = vector_origin
	end
	
	if SERVER then
	
		local plys = {}
		if IsValid( activator ) and not predicted and not activator:IsBot() then
			plys = activator
		else
			for i , v in ipairs( player.GetHumans() ) do
				
				if predicted and self:IsCarriedBy( v ) then
					continue
				end
				
				plys[#plys + 1] = v
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
			net.WriteUInt( chan , 8 )
			net.WriteVector( worldpos )
		net.Send( plys )
		
	else
		if ( IsFirstTimePredicted() and predicted ) or not predicted then
			if worldpos and worldpos ~= vector_origin then
				sound.Play( soundname, worldpos, level, pitch , volume )
			else
				self:EmitSound( soundname , level , pitch , volume , chan )
			end
		end
	end
end

function ENT:OnRemove()
	--if we're being forcibly removed, make sure we're also dropped properly, in case the entity needs to do
	--some stuff on the player before it expires
	if SERVER and self:IsCarried() then
		self:Drop( true )
	end
end

--stuff that should be in an autorun file but that I can't be arsed to split up to

if SERVER then

	util.AddNetworkString( "pe_pickup" )
	util.AddNetworkString( "pe_playsound" )
	
	--save the function before ENT gets removed during registration
	local GetPredictedEntityOnPlayer = ENT.GetOnPlayer
	
	concommand.Add( "pe_drop" , function( ply , cmd , args , fullstr )
		
		if not IsValid( ply ) then
			return
		end
		
		local nwslot = args[1]
		
		if not nwslot then
			return
		end
		
		local slotent = GetPredictedEntityOnPlayer( ply , nwslot )--ply:GetNWEntity( nwslot )
		
		--user tried to drop an invalid or an entity which is not a predicted entity, or doesn't have a slot assigned
		
		if not IsValid( slotent ) or not slotent.IsPredictedEnt or slotent:GetSlotName() == "" then
			return
		end
		
		slotent:Drop( false )
		
	end)
	
else
	
	--tells the hud to show the player the entity pickup
	language.Add( "invalid_entity" , "Invalid Entity" )
	language.Add( "dropped_invalid_entity" , "Dropped Invalid Entity" )
	
	net.Receive( "pe_pickup" , function( len )
		local str = net.ReadString() or "invalid_entity"
		local dropped = tobool( net.ReadBit() )
		
		if dropped then
			str = "dropped_" .. str
		end
		
		gamemode.Call( "HUDItemPickedUp" , str )
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
		local chan = net.ReadUInt( 8 )
		local pos = net.ReadVector()
		
		ent:EmitPESound( soundname , level , pitch , volume , chan , false , NULL , pos )
	end)
	
	--[[
		A DProperty that allows the user to set a preferred key using the same DBinder used in sandbox's tools
	]]

	local PANEL = {}

	function PANEL:Init()
	end

	function PANEL:Setup( vars )

		self:Clear()
		
		local ctrl = self:Add( "DBinder" )
		ctrl:Dock( FILL )
		
		self.IsEditing = function( self )
			return ctrl.Trapping
		end
		
		self.SetValue = function ( self , val )
			ctrl:SetSelected( tonumber( val ) )	--use this instead of setValue to possibly avoid feedback loops
		end
		
		--DBinder doesn't have an onchange callback, so we must do this little hack to add it
		ctrl.SetValue = function( ctrl , val )
			ctrl:SetSelected( val )
			self:ValueChanged( val )
		end

	end

	derma.DefineControl( "DProperty_EditKey" , "" , PANEL , "DProperty_Generic" )
end