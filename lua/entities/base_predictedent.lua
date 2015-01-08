AddCSLuaFile()

--[[
	This entity base is pretty much a streamlined version of my special action system ( that you might see used in scrapmatch )
	The advantages over that system is that these entities can be treated as normal entities when not equipped by a player, and as such, should
	allow for more freedom , such as being bundled in addons, editing variables with the right click
]]

DEFINE_BASECLASS( "base_entity" )

ENT.UseNWVars = false

ENT.Spawnable = false
ENT.IsPredictedEnt = true
ENT.AttachesToPlayer = true	--whether this entity attaches to the player or not, when true this removes physics and draws the entity on the player

if SERVER then
	ENT.DropOnDeath = true
	ENT.ShowPickupNotice = false	--plays the pickup sound and shows the pickup message on the hud
else
	ENT.RenderGroup = RENDERGROUP_OPAQUE
	
	ENT.SpawnIconInfo = {
		Pos = vector_origin,
		Ang = angle_zero,
	}
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
		index = dtname
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
	
	self:DefineNWVar( "Int" , "InButton" )
	self:DefineNWVar( "Int" , "Key" , true , "Button" , BUTTON_CODE_NONE + 1 , BUTTON_CODE_LAST , "EditKey" )
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
	
	self:InstallHook( "CalcMainActivity" , self.HandleCalcMainActivity )
	self:InstallHook( "UpdateAnimation" , self.HandleUpdateAnimation )
	self:InstallHook( "DoAnimationEvent" , self.HandleAnimationEvent )
	
	self:InstallHook( "CanEditVariable" , self.HandleCanEditVariable )
	
	
	if SERVER then
		self:InstallHook( "SetupPlayerVisibility" , self.HandleEntityVisibility )
		self:InstallHook( "EntityRemoved" , self.OnControllerRemoved )
		self:InstallHook( "PostPlayerDeath" , self.OnControllerDeath )	--using PostPlayerDeath as it's called on all kind of player deaths, even :KillSilent()
		self:SetUseType( SIMPLE_USE )
		self:SetInButton( 0 )--set this to an IN_ enum ( using a raw number is fine, as long as it's below 32 bits )
		self:SetKey( BUTTON_CODE_NONE )
	else
		self:InstallHook( "PostDrawViewModel" , self.DrawFirstPersonInternal )
		self:InstallHook( "PostPlayerDraw" , self.DrawOnPlayer )
		self:InstallHook( "NetworkEntityCreated" , self.HandleFullPacketUpdate )
		language.Add( self:GetClass() , self.PrintName )
		language.Add( "dropped_"..self:GetClass() , "Dropped "..self.PrintName )
		self.IsPredictable = false	--failsafe
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
		self:HandleDerma()
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
	
	--copied from env_skypaint, allows to have the DT vars set as if they were key values
	
	function ENT:KeyValue( key, value )

		if self:SetNetworkKeyValue( key, value ) then
			return
		end

	end
	
	function ENT:Use( activator, caller, useType, value )
		--TODO: support for stealing other people's entities by looking and then +use'ing them?
		self:Attach( activator )
	end

	function ENT:InitPhysics()
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

	function ENT:Attach( activator , forced )
		
		--we were forced to attach to this player, so drop first to clear out values
		if forced then
			self:Drop( forced )
		end
		
		if not IsValid( activator ) or not activator:IsPlayer() then
			return false
		end
		
		if self:IsCarriedBy( activator ) or self:IsCarried() or IsValid( activator:GetNWEntity( self:GetSlotName() ) ) then
			self:EmitPESound( "HL2Player.UseDeny" , 150 , nil , 1 , nil , nil , activator )
			return false
		end
		
		if not forced then
			local canattach = self:CanAttach( activator )
		
			--we can allow the coder to only stop the attach if it's not forced
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
		
		activator:SetNWEntity( self:GetSlotName() , self )
		self:SetControllingPlayer( activator )
		
		self:OnAttach( self:GetControllingPlayer() , forced )
		return true
	end

	function ENT:Drop( forced )
		if not forced then
			local candrop = self:CanDrop( self:GetControllingPlayer() )
		
			--we can allow the coder to only stop the drop if it's not forced
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
		
		if not forced then
			self:SendItemMessage( self:GetControllingPlayer() , true )
		end
		
		self:OnDrop( self:GetControllingPlayer() , forced )
		
		if self:IsCarried() then
			self:GetControllingPlayer():SetNWEntity( self:GetSlotName() , NULL )
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
			
			--TODO: different sound when dropping, crowbar's attack sound maybe?
			if not dropped then
				self:EmitSound( "HL2Player.PickupWeapon" )
			else
				self:EmitSound( "Weapon_Crowbar.Single" )
			end
			
			if not activator:IsBot() then
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
			local val = self:CanPlayerEditVariable( ply , key , val , editor )
			
			--call the editkey hook only if the other one didn't say anything in the matter for this
			if key == "Key" and val == nil then
				val = self:CanEditKey( ply , val , editor )
			end
			
			--we'll only override all the hooks if the answer is yes or no, nil keeps the default behaviour
			if val ~= nil then
				return val
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
	end

else

	function ENT:InternalHandleLoopingSounds( calledinprediction )
		--the calledinprediction variable makes it so HandleLoopingSounds is called from ENT:Think instead
		--and yes, this will never be set at all during singleplayer because there's no prediction
		
		--if this is set then there's no need to call iscarried checks below, we're always called when that happens
		if calledinprediction and not IsFirstTimePredicted() then
			return
		end
		
		if not self:IsCarried() or not self:IsCarriedByLocalPlayer() or ( self:IsCarriedByLocalPlayer() and calledinprediction )then
			self:HandleLoopingSounds()
		end
	end
	
	function ENT:HandleLoopingSounds()
		--override me
	end
	
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
	
		local carried = self:IsCarriedByLocalPlayer()
		
		--either the gravity gun or some other stuff is carrying me, don't do anything on prediction
		--because they might enable it to carry us around smoothly
		
		if self:GetBeingHeld() then
			--just in case
			carried = false
		end
		
		if self.IsPredictable ~= carried then
			self:SetPredictable( carried )
			self.IsPredictable = carried
		end
	end
	
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
	
	function ENT:HandleButtonBind( ply , cmd )
		
		--don't even bother if the InButton isn't set or the player is already pressing the button on his own
		--maybe someone wants the entity to be activated by an IN_ enum used by player movement or something
		
		if self:GetInButton() > 0 and bit.band( cmd:GetButtons() , self:GetInButton() ) == 0 then
			local mykey = self:GetKey()
			if not ( gui.IsGameUIVisible() or ply:IsTyping() ) then
				
				--these checks are clientside, so they're not really *SECURE* per say, but using PlayerButtonDown/Up is kind of unreliable too
				--plus the coder shouldn't really rely on this for security, but more of an utility
				if self:IsValidButton( mykey ) and input.IsButtonDown( mykey ) then
					
					if bit.band( self.KeyAllowedFlags , self.KeyAllowedKeyboard ) == 0 and self:IsKeyboardButton( mykey ) then
						return
					end
					
					if bit.band( self.KeyAllowedFlags , self.KeyAllowedMouse ) == 0 and self:IsMouseButton( mykey ) then
						return
					end
					
					if bit.band( self.KeyAllowedFlags , self.KeyAllowedJoystick ) == 0 and self:IsJoystickButton( mykey ) then
						return
					end
					
					cmd:SetButtons( bit.bor( cmd:GetButtons() , self:GetInButton() ) )
				end
			end
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
		self:DrawModel( flags )
	end
	
	function ENT:DrawSpawnIcon( flags )
		self.DrawingSpawnIcon = true
		
		local pos = vector_origin
		local ang = angle_zero
		
		if self.SpawnIconInfo then
			pos = self.SpawnIconInfo.Pos
			ang = self.SpawnIconInfo.Ang
		end
		
		self:SetPos( pos )
		self:SetAngles( ang )
		self:SetupBones()
		
		local tb = self:SpawnIconSetup( flags )
		
		self:DrawModel( flags )
		
		self:SpawnIconRestore( flags , tb )
		
		self.DrawingSpawnIcon = nil
	end
	
	function ENT:SpawnIconSetup( flags )
		--override me, return a table here with the shit you changed
	end
	
	function ENT:SpawnIconRestore( flags , tab )
		--override me, restore the shit you changed with the stuff in the table
	end
	
	--UGLEH as sin
	function ENT:GetMainPanel()
		return PE_HUD
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
		--override me
	end
end

function ENT:IsAttached()
	local ply = self:GetControllingPlayer()
	return self:GetOwner() == ply and self:GetParent() == ply
end

--LOOK I DON'T CARE, this check is lame as shit but I can't be arsed to add duplicated code
function ENT:IsCarried()
	return self:IsCarriedBy( self:GetControllingPlayer() )
end

function ENT:IsCarriedBy( ply )
	return IsValid( ply ) and ply == self:GetControllingPlayer() and self:GetControllingPlayer():GetNWEntity( self:GetSlotName() ) == self
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
--who knows, it might be renamed in the future!

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
	
	--abort if we're drawing the spawn icon
	if CLIENT and self.DrawingSpawnIcon then
		return
	end
		
	if CLIENT and self:IsCarriedByLocalPlayer() and not ply:ShouldDrawLocalPlayer() then
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
end