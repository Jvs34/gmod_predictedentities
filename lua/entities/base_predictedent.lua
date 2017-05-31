AddCSLuaFile()

--[[
	An entity base that allows you to create entity that can be equipped by the player as if they were weapons or powerups, but that can still 
	function when not picked up by a player
	
	For instance you could make a jetpack that flies off when the equipping player dies, or you can make a controllable plane but still allow
	full movement on the player
	
	This file is licensed under the MIT license, so go nuts.
]]

DEFINE_BASECLASS( "base_entity" )

ENT.UseNWVars = false

ENT.Spawnable = false
ENT.IsPredictedEnt = true
ENT.AttachesToPlayer = true	--whether this entity attaches to the player or not, when true this removes physics and draws the entity on the player

ENT.SaveButtonToCvar = false

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

ENT.HookAlways = 1 --hooks in here always run
ENT.HookEquipped = 2 --hooks in here are only added when the entity is equipped by user, and removed when unequipped
ENT.HookEquippedPrediction = 3 --like above, but on the client, only for the LocalPlayer() equipping this
ENT.HookCallback = 4 --these are callbacks handled with AddCallback, unfortunately we have no way to fully handle these

--example attachment info table, only used if AttachesToPlayer is true
--[[
ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}
]]

--[[
	This is a wrapper for NetworkVars/DTVars (same thing) so we can handle their slots properly for child classes instead
	of having to modify them manually everytime something changes in order
	
	This could be switched to NWVars2 (vinh vars) but then I would have to hack in support for right-click editing, since that's
	based on NetworkVars and some other getters
]]
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
	
	--this used to check if we could actually add the edit table, so we default it to nil to override it again
	--in case of a child class
	
	if editable then
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
	self:DefineNWVar( "Float" , "NextFire" ) --similar to primaryattack on a weapon
	
	--only allow the user to modify the button if the coder wants this entity to have an usable key
	
	self:DefineNWVar( "Int" , "Key" , true , "Button" , BUTTON_CODE_NONE + 1 , BUTTON_CODE_LAST , "EditKey" )
	self:DefineNWVar( "Bool" , "KeyPressed" )
end

function ENT:Initialize()

	self.HandledHooks = {
		[self.HookAlways] = {},
		[self.HookEquipped] = {},
		[self.HookEquippedPrediction] = {},
		[self.HookCallback] = {}
	}
	
	self.HookConditions = {
		[self.HookAlways] = function( ent ) 
			return true 
		end,
		[self.HookEquipped] = function( ent ) 
			return ent:IsCarried() 
		end,
		[self.HookEquippedPrediction] = function( ent ) 
			if SERVER then
				return ent:IsCarried() --self.HookConditions[self.HookEquipped]( self )
			else
				return ent:IsCarriedByLocalPlayer()
			end
		end,
		[self.HookCallback] = function( self ) 
			return nil --nil means don't handle me
		end,
	}
	
	--predicted hooks hooking with hookers and futurama memes
	self:InstallHook( "StartCommand" , self.HandlePredictedStartCommand , self.HookEquippedPrediction )
	self:InstallHook( "SetupMove" , self.HandlePredictedSetupMove , self.HookEquippedPrediction )
	self:InstallHook( "Move" , self.HandlePredictedMove , self.HookEquippedPrediction )
	self:InstallHook( "PlayerTick" , self.HandlePredictedThink , self.HookEquippedPrediction )
	self:InstallHook( "FinishMove" , self.HandlePredictedFinishMove , self.HookEquippedPrediction )
	self:InstallHook( "OnPlayerHitGround" , self.HandlePredictedHitGround , self.HookEquippedPrediction )
	self:InstallHook( "PlayerButtonDown" , self.HandlePlayerButtonDown , self.HookEquippedPrediction )
	self:InstallHook( "PlayerButtonUp" , self.HandlePlayerButtonUp , self.HookEquippedPrediction )
	
	
	self:InstallHook( "CalcMainActivity" , self.HandleCalcMainActivity , self.HookEquipped )
	self:InstallHook( "UpdateAnimation" , self.HandleUpdateAnimation , self.HookEquipped )
	self:InstallHook( "DoAnimationEvent" , self.HandleAnimationEvent , self.HookEquipped )
	
	
	if SERVER then
		self:InstallHook( "SetupPlayerVisibility" , self.HandleEntityVisibility , self.HookAlways )
		self:InstallHook( "EntityRemoved" , self.OnControllerRemoved , self.HookAlways )
		self:InstallHook( "PostPlayerDeath" , self.OnControllerDeath , self.HookAlways )	--using PostPlayerDeath as it's called on all kind of player deaths, even :KillSilent()
		self:InstallHook( "CanEditVariable" , self.HandleCanEditVariable , self.HookAlways )
		
		--just in case it has been spawned manually and the coder forgot
		if self:GetSlotName() == "" then
			ErrorNoHalt( self:GetClass() .. " was spawned without a slotname!!!!. Defaulting to classname\n" )
			self:SetSlotName( self:GetClass() )
		end
		
		self:SetUseType( SIMPLE_USE )
		self:SetKey( BUTTON_CODE_NONE )
	else
		self:InstallHook( "PreDrawEffects" , self.DrawFirstPersonInternal , self.HookEquipped )
		self:InstallHook( "PostDrawViewModel" , self.DrawViewModelInternal , self.HookEquipped )
		self:InstallHook( "PostPlayerDraw" , self.DrawOnPlayer , self.HookEquipped )
		
		self:InstallHook( "NotifyShouldTransmit" , self.HandleFullPacketUpdate , self.HookAlways )
		
		language.Add( self:GetClass() , self.PrintName )
		language.Add( "dropped_"..self:GetClass() , "Dropped "..self.PrintName )
	end
end

--This is needed mostly for clientside hooks, since IsValid might return false when we're out of PVS with some bad lag
--and when hook.Call tries to call on an invalid entity it removes the hook, so we need to reinstall them when that happens and the entity gets back in the PVS
--prediction and other shit like drawing on a player might fuck up since the hooks got removed
--Now this also works for adding a callback

function ENT:InstallHook( hookname , handler , hooktype )
	
	if self.HandledHooks[hooktype] == nil then
		hooktype = self.HookAlways
	end

	self.HandledHooks[hooktype][hookname] = handler
	
	if hooktype == self.HookCallback then
		self:AddCallback( hookname , handler )
	end

end

function ENT:HandleHooks( cleanup )

	--this is direct access to the hook table, but it's not slow at all
	--or at least, it shouldn't be as long as you don't have any ulib shit or some other hook overrides
	local hooktable = hook.GetTable()
	
	
	
	for hookindex , handledshooktab in pairs( self.HandledHooks ) do
		local condition = self.HookConditions[hookindex]( self )
		
		if condition ~= nil then
			for i , v in pairs( handledshooktab ) do
				if condition and not cleanup then
					if not hooktable[i] or not hooktable[i][self] then
						hook.Add( i , self , v )
					end
				else
					if hooktable[i] and hooktable[i][self] then
						hook.Remove( i , self )
					end
				end
			end
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
		--the reason I'm networking this is that due to the gravity gun enabling prediction, it would screw with the manual
		--predictable logic of this entity, so when we try to activate prediction, we check if we're being carried by the gravity gun
		--to prevent disabling it
		
		--NOTE: this is not as expensive as it looks, it just checks for the FVPHYSICS_PLAYER_HELD flag on our physobj
		self:SetBeingHeld( self:IsPlayerHolding() )
	else
		--calling this in a non-predicted hook is perfectly fine, since we need the entity to enable prediction on its own
		--even when controlling players change

		--Ideally this would be handled on the callback of SetControllingPlayer clientside, but we don't have that yet
		self:HandlePrediction()
		self:HandleButtonBind()
		self:HandleContextMenuButton()
		self:InternalHandleLoopingSounds()
	end
	
	--set our think rate to be in line with the server tickrate
	--this may also affect animations clientside if they're ran in this hook, considering that also happens in normal source
	--I'd say that's an accurate replication of the issue
	
	--default behaviour for scripted entities is to think every 200 milliseconds
	--I suppose this should be configurable by child entities
	
	self:NextThink( CurTime() + engine.TickInterval() )
	return true
end

if SERVER then
	
	--for map inputs mostly, but other addons may also be using these inputs trough ent:Input or ent:Fire
	--more inputs might come in the future
	--of course child entities are free to call the baseclass function after their own to chain stuff
	
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
	
	function ENT:ChangeSlot( newslotname )
		local oldslotname = self:GetSlotName()
		
		if newslotname == oldslotname then
			return false
		end
		
		local ply = self:GetControllingPlayer()
		
		--if we have a controlling player and he has an entity in the new slot, abort
		if IsValid( ply ) and IsValid( self.GetOnPlayer( ply , newslotname ) ) then
			--this slot is already occupied!!!
			return false
		end
		
		if IsValid( ply ) then
			self.SetOnPlayer( ply , oldslotname , NULL )
			self.SetOnPlayer( ply , newslotname , self )
		end
		
		self:SetSlotName( newslotname )
		
		return true
	end
	
	--useful for swapping out two slots at the same time and knowing the other entity,
	--usually in an inventory system
	function ENT:SwapSlotWith( predent )
		local ply = self:GetControllingPlayer()
		
		if not self:IsCarriedBy( ply ) or not IsValid( predent ) or not predent.IsPredictedEnt 
		or not predent:IsCarriedBy( ply ) then
			return false
		end
		
		local myslot = self:GetSlotName()
		local otherslot = predent:GetSlotName()
		
		self.SetOnPlayer( ply , otherslot , self )
		self.SetOnPlayer( ply , myslot , predent )
		
		self:SetSlotName( otherslot )
		predent:SetSlotName( myslot )
		
		return true
	end
	
	--override this if you want your equip logic to be different
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
			
			--[[
			if self.DontTransmitToOthers then
				--force a recheck of the transmission, so UpdateTransmitState() is called right away
				self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
			else
				self:SetTransmitWithParent( true )
			end
			]]
			
			self:SetNoDraw( true )
			self:AddEFlags( EFL_NO_PHYSCANNON_INTERACTION )
		end

		self:SendItemMessage( activator , false )
		
		self.SetOnPlayer( activator , self:GetSlotName() , self )
		self:SetControllingPlayer( activator )
		
		--if the player has a customized key for this entity, use that instead
		--we do this here so that OnAttach can make use of it
		
		--this also allows us to prevent the key from another user to be written clientside and override ours
		if self.SaveButtonToCvar then
			local plykey = self:GetControllingPlayerConVarKey()
			
			if self:IsKeyAllowed( plykey ) and plykey ~= self:GetKey() then
				self:SetKey( plykey )
			end
		end
		
		--THIS IS VERY SUBJECTIVE
		self:SetKeyPressed( false ) --only reset the button press state when equipped
		
		self:OnAttach( activator , forced )
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
			
			--[[
			if self.DontTransmitToOthers then
				--force a recheck during a drop
				self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
			else
				self:SetTransmitWithParent( false )
			end
			]]
			
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
		
		--TODO: This will be removed and the ENT:UpdateTransmitState() below will be enabled once Willox is done with TRANSMIT_OWNERONLY
		if self.DontTransmitToOthers and not game.SinglePlayer() then
			
			local shouldpreventtransmit = false
			
			if self:IsCarried() then
				shouldpreventtransmit = not self:IsCarriedBy( ply , true )
			end
			
			self:SetPreventTransmit( ply , shouldpreventtransmit )
		end
	end
	
	--[[
	function ENT:UpdateTransmitState()
		
		
		if self.DontTransmitToOthers and self:IsCarried() then
			return TRANSMIT_OWNERONLY
		end
		
		
		--don't return anything, default behaviour
	end
	]]
	
else

	function ENT:GetConVar()
	
		--the slotname changed, so we forget this cvar to let another one with the same slot use it
		--and we let the code below create/get one with our slotname
		if self.ConfigurableConVar and self.ConfigurableConVar:GetName() ~= self:GetConVarName() then
			self.ConfigurableConVar = nil
		end
		
		if not self.ConfigurableConVar then
			--internally this returns the original convar if it was already created, so it's not that big of a deal, this could be done in a better way however
			self.ConfigurableConVar = CreateConVar( self:GetConVarName() , self:GetKey() , FCVAR_ARCHIVE + FCVAR_USERINFO , "Configures the key for "..self:GetSlotName().. " , created by "..self:GetClass() )
		end
		
		return self.ConfigurableConVar
	end
	
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
	
	function ENT:HandleButtonBind()
		--did not disable the function call from Think as someone might want to override this
		
		if self.SaveButtonToCvar then
			--this is a one way server to client saving, the reason I do this is because the user should usually change the value from
			--client to server with the edit system, it still goes to the server, but not to the cvar first, so we save it from the client to the cvar
			
			--basically we just use the cvar as a way to save the button, but it does come at the cost of not being able to update the cvar and have it update on the
			--entity, this will probably change in the future
			local mykey = self:GetKey()
			
			--can't use GetControllingPlayerConVarKey as I also need to SetInt on it
			local cv = self:GetConVar()
			
			if cv then
				if ( mykey ~= cv:GetInt() and self:IsKeyAllowed( mykey ) ) --[[or not self:IsKeyAllowed( cv:GetInt() )]] then
					cv:SetInt( mykey )
				end
			end
		end
	end
	
	
	
	function ENT:CreateContextMenuButton( iconlayout )
		local button = iconlayout:Add( "DPredEnt" )
		button:SetSize( 80 , 80 )
		button:SetClassName( self.PrintName , self:GetSlotName() )
		button:SetMaterial( self.Folder .. ".png" )
		button:SetPredEnt( self )
		--SetClassName
	end
	
	function ENT:GetContextMenuButton( iconlayout )
		local contextbutton = nil
		
		for i = 0 , iconlayout:ChildCount() do
			
			local child = iconlayout:GetChild( i )
			
			if IsValid( child ) and child:GetName() == "DPredEnt" and child:GetSpawnName() == self:GetSlotName() and child:GetPredEnt() == self then
				contextbutton = child
				break
			end
			
		end
		
		return contextbutton
	end
	
	--forcefully removes it in case it fucks up
	function ENT:RemoveContextMenuButton( iconlayout , buttonpanel )
		if IsValid( buttonpanel ) then
			buttonpanel:Remove()
		end
	end
	
	function ENT:GetContextMenuLayout()
		if not IsValid( g_ContextMenu ) then
			return
		end
		
		local iconlayout = nil
		
		for i = 0 , g_ContextMenu:ChildCount() do
			
			local child = g_ContextMenu:GetChild( i )
			
			if IsValid( child ) and child:GetName() == "DIconLayout" then
				iconlayout = child
				break
			end
			
		end
		
		return iconlayout
	end
	
	function ENT:HandleContextMenuButton( docleanup )
	
		local iconlayout = self:GetContextMenuLayout()
		
		if not IsValid( iconlayout ) then
			return
		end
		
		local buttonpanel = self:GetContextMenuButton( iconlayout )
		
		if IsValid( buttonpanel ) and ( not self:IsCarriedByLocalPlayer() or docleanup )then
			self:RemoveContextMenuButton( iconlayout , buttonpanel )
			iconlayout:InvalidateLayout()
		end
		
		if not IsValid( buttonpanel ) and self:IsCarriedByLocalPlayer() then
			self:CreateContextMenuButton( iconlayout )
			iconlayout:InvalidateLayout()
		end
		
	end
	

	
	function ENT:DrawFirstPersonInternal()
		if self.AttachesToPlayer and self:IsCarriedByLocalPlayer( true ) and not self:ShouldDrawLocalPlayer( true ) then
			local fov = nil	--TODO: allow changing the FOV
			cam.Start3D( nil , nil , fov , nil , nil , nil , nil , 1 , -1 )	--znear is 1 and zfar is -1
				render.DepthRange( 0 , 0.1 )	--same depth hack valve uses in source!
					self:DrawFirstPerson( self:GetControllingPlayer() )
				render.DepthRange( 0 , 1 )		--they don't even set these back to the original values
			cam.End3D()
		end
	end
	
	--viewmodels don't draw without an associated weapon ( this is due to garryness, they always do in source )
	function ENT:DrawViewModelInternal( vm , ply , wpn )
		if self.AttachesToPlayer and self:IsCarriedBy( ply , true ) then
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
--the alternative would be to have these as global, which would be lamer
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

function ENT:IsKeyDown()
	return self:GetKeyPressed()
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

function ENT:GetConVarName()
	return "prdent_key_"..self:GetSlotName()
end

function ENT:GetControllingPlayerConVarKey()
	local defaultkey = BUTTON_CODE_NONE
	
	if self:IsCarried() then
		if SERVER then
			return self:GetControllingPlayer():GetInfoNum( self:GetConVarName() , defaultkey )
		else
			--the clientside implementation of GetInfoNum makes a GetConVar lookup everytime, so use the cached one instead
			local cv = self:GetConVar()
			
			if cv then
				return cv:GetInt()
			end
		end
	end
	
	return defaultkey
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
		self:PredictedStartCommand( ply , cmd )
	end
end

function ENT:HandlePlayerButtonDown( ply , btn )
	if self:IsCarriedBy( ply ) then
		self:HandlePlayerButtonInternal( ply , btn , true )
	end
end

function ENT:HandlePlayerButtonUp( ply , btn )
	if self:IsCarriedBy( ply ) then
		self:HandlePlayerButtonInternal( ply , btn , false )
	end
end

function ENT:HandlePlayerButtonInternal( ply , btn , pressed )
	local mykey = self:GetKey()
	if self:IsKeyAllowed( mykey ) and btn == mykey then
		self:SetKeyPressed( pressed )
	end
	
	self:PredictedPlayerButtonPress( ply , btn , pressed )
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

function ENT:PredictedPlayerButtonPress( ply , btn , pressed )
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
	[TYPE_VECTOR] = vector_origin * 1,
	[TYPE_ANGLE] = angle_zero * 1,
	[TYPE_NUMBER] = 0,
	[TYPE_ENTITY] = NULL,
}

local methods = {}

--cache the methods we can actually use
for i , v in pairs( movedatameta ) do
	--see if this function has a pattern like "Get*" or whatever
	--then strip out "Get" and add it here
	local functionname = i
	if functionname:find( "^Get" ) then
		local functionnamestripped = functionname:gsub( "^Get" , "" )
		
		local setter = movedatameta["Set"..functionnamestripped]
		
		if setter then
			--add the stripped method to the table to reuse later
			methods[#methods + 1] = functionnamestripped
		end
	end
end

function ENT:BackupMoveData( mv )
	
	if not mv or not movedatameta then
		return
	end
	
	local sv = {}
	--save the movedata by name on the table, then go trough the metatable to get the setters and set values to empty ones
	
	for i , v in pairs( methods ) do
		--see if this function has a pattern like "Get*" or whatever
		--then strip out "Get" and add it here
		
		--we could've cached the functions as well, but just in case someone wants us to use the modified ones
		local getter = movedata["Get"..v]
		local setter = movedata["Set"..v]
		
		local backupvalue = getter( mv )
		
		sv[v] = backupvalue
		
		if emptyvalues[TypeID( backupvalue )] ~= nil then
			setter( mv , emptyvalues[TypeID( backupvalue )] )
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
	
	--I put this here because since the entity moves to the player bone matrix, it'll only be updated on the client
	--when the player is actally drawn, or his bones are setup again ( which happens before a draw anyway )
	--this also fixes sounds on the client playing at the last location the LocalPlayer() was drawn
	
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
		
		local plys = RecipientFilter()
		
		if IsValid( activator ) and not predicted and not activator:IsBot() then
			plys:AddPlayer( activator )
		else
			
			plys:AddPVS( self:GetPos() )
			
			if predicted and IsValid( self:GetControllingPlayer() ) then
				plys:RemovePlayer( self:GetControllingPlayer() )
			end

		end
					
		if plys:GetCount() == 0 then
			return
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
		if ( predicted and IsFirstTimePredicted() ) or not predicted then
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
	
	if CLIENT then
		self:HandleContextMenuButton( true )
	end
	
	self:HandleHooks( true ) --remove the hooks immediately instead of relying on garry's "remove if called again"
	

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

	local DBinderProperty = {}

	function DBinderProperty:Init()
	end

	function DBinderProperty:Setup( vars )

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
		--[[
		ctrl.SetValue = function( ctrl , val )
			ctrl:SetSelected( val )
			self:ValueChanged( val )
		end
		]]
		
		ctrl.OnChange = function( ctrl , val )
			self:ValueChanged( val )
		end
		

	end

	derma.DefineControl( "DProperty_EditKey" , "" , DBinderProperty , "DProperty_Generic" )
	
	local DPredEnt = {
		matOverlay_Normal = Material( "gui/ContentIcon-normal.png" ),
		matOverlay_Hovered = Material( "gui/ContentIcon-hovered.png" )
	}
	
	AccessorFunc( DPredEnt, "m_MaxBorder", "MaxBorder" )
	AccessorFunc( DPredEnt, "m_MaterialName", "MaterialName" )
	AccessorFunc( DPredEnt, "m_PredEnt", "PredEnt" )
	AccessorFunc( DPredEnt, "m_Border", "Border" )
	AccessorFunc( DPredEnt, "m_Color", "Color" )
	AccessorFunc( DPredEnt, "m_Type", "ContentType" )
	AccessorFunc( DPredEnt, "m_SpawnName", "SpawnName" )
	AccessorFunc( DPredEnt, "m_NPCWeapon", "NPCWeapon" )
	AccessorFunc( DPredEnt, "m_Image", "Image" )
	AccessorFunc( DPredEnt, "m_Label", "Label" )
	
	function DPredEnt:Init()
		
		local w , h = 128, 128
		self:SetSize( w , h )
		
		self:SetPaintBackground( false )
		
		self:SetText( "" )
		self:SetDoubleClickingEnabled( false )

		self:SetImage( self:Add( "DImage" ) )
		self:GetImage():SetVisible( false )

		self:SetLabel( self:Add( "DLabel" ) )
		self:GetLabel():Dock( BOTTOM )
		
		self:GetLabel():SetContentAlignment( 5 )
		
		self:GetLabel():SetTextColor( Color( 255, 255, 255, 255 ) )
		self:GetLabel():SetExpensiveShadow( 1, Color( 0, 0, 0, 200 ) )

		self:SetBorder( 0 )
		
		

	end
	


	function DPredEnt:PerformLayout( w , h )
		self:SetMaxBorder( w / 16 )
		self:GetImage():SetPos( w / 32 , w / 32 )
		self:GetImage():SetSize( w - w / 16 , h - w / 16 )
		self:GetLabel():SetTall( math.Round( w / 7 ) )
		self:GetLabel():DockMargin( math.Round( w / 32 ) , 0 , math.Round( w / 32 ) , math.Round( w / 21 ) )
	end
	
	
	function DPredEnt:SetClassName( name , class )

		self:SetTooltip( name )
		self:GetLabel():SetText( name )
		self:SetSpawnName( class )
	end

	function DPredEnt:SetMaterial( name )

		self:SetMaterialName( name )

		local mat = Material( name )

		-- Look for the old style material
		if not mat or mat:IsError() then

			name = name:Replace( "entities/", "VGUI/entities/" )
			name = name:Replace( ".png", "" )
			mat = Material( name )

		end

		-- Couldn't find any material.. just return
		if not mat or mat:IsError() then
			return
		end

		self:GetImage():SetMaterial( mat )

	end
	
	function DPredEnt:Think()
		if not IsValid( self:GetPredEnt() ) or not self:GetPredEnt().IsPredictedEnt  then
			self:Remove()
		end
	end
	
	function DPredEnt:DoRightClick()
		self:OpenMenu()
	end

	function DPredEnt:DoClick()
		RunConsoleCommand( "pe_drop" , self:GetSpawnName() or ""  )
	end

	function DPredEnt:OpenMenu()
		if IsValid( self:GetPredEnt() ) then
			properties.OpenEntityMenu( self:GetPredEnt() )
		end
	end

	function DPredEnt:OnDepressionChanged( b )
	end

	function DPredEnt:Paint( w, h )

		if self.Depressed and not self.Dragging then
			if self:GetBorder() ~= self:GetMaxBorder() then
				self:SetBorder( self:GetMaxBorder() )
				self:OnDepressionChanged( true )
			end
		else
			if self:GetBorder() ~= 0 then
				self:SetBorder( 0 )
				self:OnDepressionChanged( false )
			end
		end

		render.PushFilterMag( TEXFILTER.ANISOTROPIC )
		render.PushFilterMin( TEXFILTER.ANISOTROPIC )
		
		local bx , by , bw , bh = self:GetBorder(), self:GetBorder(), w - self:GetBorder() * 2 , h - self:GetBorder() * 2
		
		
		self:GetImage():PaintAt( bx + self:GetMaxBorder() / 2 , by + self:GetMaxBorder() / 2 , bw - self:GetMaxBorder() , bh - self:GetMaxBorder() )
		
		
	
		render.PopFilterMin()
		render.PopFilterMag()

		surface.SetDrawColor( 255, 255, 255, 255 )

		if not dragndrop.IsDragging() and ( self:IsHovered() or self.Depressed or self:IsChildHovered() ) then

			surface.SetMaterial( self.matOverlay_Hovered )
			self:GetLabel():Hide()

		else

			surface.SetMaterial( self.matOverlay_Normal )
			self:GetLabel():Show()

		end

		surface.DrawTexturedRect( bx , by , bw , bh )

	end
	
	derma.DefineControl( "DPredEnt" , "ContentIcon for Predicted entities in the context menu" , DPredEnt , "DButton" )
	
end
