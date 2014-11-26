AddCSLuaFile()

--[[
	An entity that allows you to fire a grapple hook and automatically reel to it by holding the button
	Like the jetpack, this works even when the player dies while using it.
	
	Right now the hook is fired once and then the hook has a simulated travel time from 0 up to 4 seconds,
	by calculating the time fraction I draw the fancy rope effects and it's pretty smooth
	once the traveltime expires the player is pulled and shit starts to happen
	
	What I want to do is actually simulate the hook like an actual projectile, but we'd need interpolation to draw smoothly
	The plus side would be that gravity can affect it, and we can simulate the return easily instead of the hacky mess I'm doing right now
]]

DEFINE_BASECLASS( "base_predictedent" )

ENT.Spawnable = true
ENT.PrintName = "Grappling hook Belt"

if CLIENT then
	language.Add( "sent_grapplehook_bpack" , ENT.PrintName )
	ENT.CableMaterial = Material( "cable/cable2" )
	ENT.WireFrame = Material( "models/wireframe" )
else
	ENT.ShowPickupNotice = true
end

ENT.MinBounds = Vector( -8.3 , -7.8 , 0 )
ENT.MaxBounds = Vector( 10 , 8 , 4.5 )

ENT.InButton = IN_GRENADE1
ENT.HookMaxTime = 4	--max time in seconds the hook needs to reach the maxrange
ENT.HookMaxRange = 10000
ENT.HookHullMins = Vector( -2 , -2 , -2 )
ENT.HookHullMaxs = ENT.HookHullMins * -1
ENT.HookCableSize = 0.5

--TODO: position ourselves on the player's belt
ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine1",
	OffsetVec = Vector( 0 , 2.5 , 0 ),
	OffsetAng = Angle( 0 , 90 , -90 ),
}

ENT.HookAttachmentInfo = {
	OffsetVec = Vector( 8.3 , 0 , 2.4 ),
	OffsetAng = angle_zero,
}

--[[
sound.Add( {
	name = "grapplehook.hit",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^vehicles/digger_grinder_loop1.wav"
})
]]

sound.Add( {
	name = "grapplehook.launch",
	channel = CHAN_WEAPON,
	volume = 1,
	level = 75,
	sound = "ambient/machines/catapult_throw.wav"
})

sound.Add( {
	name = "grapplehook.reelsound",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^vehicles/digger_grinder_loop1.wav"
})

sound.Add( {
	name = "grapplehook.shootrope",
	channel = CHAN_ITEM,
	volume = 0.7,
	level = 75,
	sound = "^weapons/tripwire/ropeshoot.wav",
})

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 36

	local ent = ents.Create( ClassName )
	ent:SetSlotName( ClassName )	--this is the best place to set the slot, don't modify it dynamically ingame
	ent:SetPos( SpawnPos )
	ent:Spawn()
	return ent

end

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/props_junk/wood_crate001a.mdl" )
		self:DrawShadow( false )
		
		self:SetPullMode( 1 )
		self:SetPullSpeed( 2000 )
		self:SetKey( KEY_G )	--the starting key to trigger us
		self:InitPhysics()
		
		self:SetDoReturn( false )
		self:SetNextFire( CurTime() + 1 )
		self:SetAttachTime( CurTime() )
		self:SetAttachStart( CurTime() )
		self:SetAttachedTo( vector_origin )
		self:SetGrappleNormal( vector_origin )
		self:SetIsAttached( false )
		self:SetAttachSoundPlayed( false )
		self:Detach()
	else
		self:CreateModels()
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )
	
	self:DefineNWVar( "Float" , "AttachTime" )
	self:DefineNWVar( "Float" , "AttachStart" )
	self:DefineNWVar( "Float" , "PullSpeed" , true , "Pull speed" , 0 , 3500 )
	self:DefineNWVar( "Float" , "GrappleFraction" )
	self:DefineNWVar( "Int" , "PullMode" , true , "Pull mode" , 1 , 4 )
	self:DefineNWVar( "Vector" , "AttachedTo" )
	
	self:DefineNWVar( "Vector" , "GrappleNormal" )
	
	self:DefineNWVar( "Bool" , "IsAttached" )
	self:DefineNWVar( "Bool" , "AttachSoundPlayed" )
	self:DefineNWVar( "Bool" , "DoReturn" , true , "Hook returns on detach" )
	self:DefineNWVar( "Entity" , "HookHelper" )
	
end


function ENT:Think()
	self:HandleHookHelper( false )
	
	if not self:IsCarried() then
		self:HandleDetach( false )
		self:HandleSounds( false )
	end
	
	return BaseClass.Think( self )
end

function ENT:Detach( forced )
	self:SetIsAttached( false )
	self:SetAttachTime( CurTime() )
	
	local returntime = self:GetDoReturn() and Lerp( self:GetGrappleFraction() , 0 , self.HookMaxTime ) or 0.5
	self:SetAttachStart( CurTime() + returntime )
	self:SetNextFire( CurTime() + returntime )
	self:SetAttachSoundPlayed( false )
end

function ENT:HandleHookHelper( predicted )
	
	if CLIENT then
		return
	end
	
	if IsValid( self:GetHookHelper() ) then
		return
	end
	
	local hh = ents.Create( "sent_grapplehook_hookhelper" )
	
	if not IsValid( hh ) then
		return
	end
	
	hh:SetParent( self )
	hh:Spawn()
	
	self:SetHookHelper( hh )
end

function ENT:HandleDetach( predicted , mv )
	
	if CLIENT and not predicted then
		return
	end
	
	--[[
	if self:GetDoReturn() and self:GetAttachedTo() ~= vector_origin then
		local atchpos = self:GetPos()
		
		if IsValid( self:GetControllingPlayer() ) then
			atchpos = self:GetControllingPlayer():EyePos()
		end
	
		local travelfraction = math.TimeFraction( self:GetAttachStart() , self:GetAttachTime() , CurTime() )

		local destpos = LerpVector( travelfraction , atchpos , self:GetAttachedTo() )
		
		local frac = ( destpos - atchpos ):Length() / self.HookMaxRange
		frac = math.Clamp( frac , 0 , 1 )
		self:SetHookTraveledFraction( frac )
	end
	]]
	
	if self:GetIsAttached() then 
		if self:ShouldStopPulling( mv ) then
			self:Detach()
			return
		end
	end
end

function ENT:IsRopeObstructed()
	--local result = self:DoHookTrace( true )
	return false
end

function ENT:IsHookReturning()
	return self:GetDoReturn() and self:GetAttachStart() >= CurTime() and self:GetAttachTime() <= CurTime() and not self:GetIsAttached() and self:GetAttachedTo() ~= vector_origin
end

function ENT:HandleSounds( predicted )
	if CLIENT and not predicted then
		self.LaunchSound = nil
		self.ReelSound = nil
		return
	end
	
	if not self.LaunchSound then
		self.LaunchSound = CreateSound( self , "grapplehook.shootrope" )
	end
	
	if not self.ReelSound then
		self.ReelSound = CreateSound( self , "grapplehook.reelsound" )
	end
	
	if self:GetIsAttached() then
		if self:GetAttachTime() < CurTime() then
			
			if not self:GetAttachSoundPlayed() then
				
				--play the hit sound only the controlling player and one on the world position
				
				if IsValid( self:GetControllingPlayer() ) then
					self:EmitPESound( "NPC_CombineMine.CloseHooks" , nil , nil , nil , CHAN_BODY , predicted , self:GetControllingPlayer() )
				end
				
				if IsFirstTimePredicted() then
					local e = EffectData()
					e:SetOrigin( self:GetAttachedTo() - self:GetDirection() * -1 )
					e:SetStart( self:GetAttachedTo() )
					e:SetSurfaceProp( 48 )	--idk, I just took it from flatgrass's wall
					e:SetDamageType( DMG_BULLET )
					e:SetHitBox( 0 )
					if CLIENT then
						e:SetEntity( game.GetWorld() )
					else
						e:SetEntIndex( 0 )
					end
					util.Effect( "Impact", e )
				end
				
				--[[
				--precache sound doesn't add the sound to the sound precache list, and thus EmitSound whines 
				if SERVER then
					EmitSound( "NPC_CombineMine.CloseHooks" , self:GetAttachedTo() , 0 , CHAN_AUTO , 0.7 , 75 , SND_NOFLAGS , 100 )
				end
				]]
				
				self:SetAttachSoundPlayed( true )
			end
			
			self.ReelSound:PlayEx( 0.3 , 200 )
			self.LaunchSound:Stop()
		else
			self.LaunchSound:PlayEx( 1 , 50 / self.HookCableSize )
		end
	else
		self.LaunchSound:Stop()
		self.ReelSound:Stop()
	end
end

function ENT:PredictedSetupMove( owner , mv , usercmd )
	if self:IsKeyDown( mv ) then
		if self:GetNextFire() <= CurTime() then
			self:FireHook()
		end
	end
end

function ENT:PredictedMove( owner , mv )
	if self:CanPull( mv ) then
		
		owner:SetGroundEntity( NULL )
		
		if self:GetPullMode() == 2 then
			mv:SetVelocity( self:GetDirection() * self:GetPullSpeed() )
		elseif self:GetPullMode() == 3 then
			local currenthooklength = Lerp( self:GetGrappleFraction() , 0 , self.HookMaxRange )
			local curdistance = ( self:GetAttachedTo() - self:GetControllingPlayer():EyePos() ):Length()
			if curdistance > currenthooklength then
				mv:SetVelocity( mv:GetVelocity() + self:GetDirection() * mv:GetVelocity():Length() * 0.5 )
			end
		else
			mv:SetVelocity( mv:GetVelocity() + self:GetDirection() * self:GetPullSpeed() * FrameTime() )
		end
	end
end

function ENT:PredictedThink( owner , mv )
	self:HandleDetach( true , mv )
	self:HandleSounds( true )
end

function ENT:FireHook()
	if self:GetIsAttached() then
		return
	end
	
	self:SetNextFire( CurTime() + 0.1 )
	
	self:GetControllingPlayer():LagCompensation( true )
	
	local result = self:DoHookTrace()
	
	self:GetControllingPlayer():LagCompensation( false )
	
	if not result.HitSky and result.Hit and not result.HitNoDraw then
		local timetoreach = Lerp( result.Fraction , 0 , self.HookMaxTime )
		
		self:SetAttachedTo( result.HitPos )
		self:SetAttachTime( CurTime() + timetoreach )
		self:SetAttachStart( CurTime() )
		self:SetIsAttached( true )
		self:SetGrappleNormal( self:GetDirection() )
		self:SetGrappleFraction( result.Fraction )
		
		self:EmitPESound( "grapplehook.launch" , nil , nil , nil , CHAN_BODY , true )
	end

end

function ENT:GetDirection()
	if not self:IsCarried() then
		return ( self:GetAttachedTo() - self:GetPos() ):GetNormalized()
	end
	return ( self:GetAttachedTo() - self:GetControllingPlayer():EyePos() ):GetNormalized()
end

function ENT:DoHookTrace( checkdetach )
	--TODO: allow hooking to entities that never move, maybe trough the callback?
	local startpos = self:GetPos()
	local normal = self:GetUp()
	
	if checkdetach then
		normal = self:GetDirection()
	end
	
	local endpos = startpos + normal * self.HookMaxRange
	
	if IsValid( self:GetControllingPlayer() ) then
		if not checkdetach then
			normal = self:GetControllingPlayer():GetAimVector()
		end
		startpos = self:GetControllingPlayer():EyePos()
		endpos = startpos + normal * self.HookMaxRange
	end
	
	local tr = {
		--TODO: custom filter callback?
		filter = {
			self:GetControllingPlayer(),
			self,
		},
		mask = MASK_PLAYERSOLID_BRUSHONLY,	--anything that stops player movement stops the trace
		start = startpos,
		endpos = endpos,
		mins = self.HookHullMins,
		maxs = self.HookHullMaxs
	}
	return util.TraceHull( tr )
end

function ENT:ShouldStopPulling( mv )
	if not self:IsCarried() then
		return false
	end
	
	return not self:IsKeyDown( mv )
end

function ENT:CanPull( mv )
	return self:GetIsAttached() and self:GetAttachTime() < CurTime() and not self:ShouldStopPulling( mv )
end

function ENT:OnRemove()
	if CLIENT then
		self:RemoveModels()
	else
		if IsValid( self:GetHookHelper() ) then
			self:GetHookHelper():Remove()
		end
	end
	
	self:StopSound( "grapplehook.reelsound" )
	self:StopSound( "grapplehook.shootrope" )
	
	BaseClass.OnRemove( self )
end

function ENT:GetHookAttachment()
	return LocalToWorld( self.HookAttachmentInfo.OffsetVec , self.HookAttachmentInfo.OffsetAng , self:GetPos() , self:GetAngles() )
end

if SERVER then

	function ENT:OnAttach( ply )
	end
	
	function ENT:OnDrop( ply , forced )
		--like for the jetpack, we still let the entity function as usual when the user dies
		if not ply:Alive() then
			return
		end
		
		self:Detach( not forced )
	end
	
	function ENT:DoInitPhysics()
		self:PhysicsInitBox( self.MinBounds , self.MaxBounds )
		self:SetCollisionBounds( self.MinBounds , self.MaxBounds )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:PhysWake()
	end
	
	function ENT:OnInitPhysics( physobj )
		self:StartMotionController()
		physobj:SetMass( 120 )
	end

	function ENT:OnRemovePhysics()
		self:StopMotionController()
	end
	
	function ENT:PhysicsSimulate( physobj , delta )
		
		if self:GetIsAttached() and not self:GetBeingHeld() and self:CanPull() then
			physobj:Wake()
			local force = self:GetDirection() * self:GetPullSpeed()
			local angular = vector_origin
			
			return angular , force * physobj:GetMass() , SIM_GLOBAL_FORCE
		end
	end
	
else
	
	function ENT:CreateModels()
		--create all the models, use EnableMatrix to setup the offsets because it's easier and faster than doing that everytime
		self.CSModels = {}
		
		local bodybasematrix = Matrix()
		bodybasematrix:Scale( Vector( 0.25 , 0.25 , 0.5 ) )
		
		self.CSModels["bodybase"] = ClientsideModel( "models/props_lab/teleportring.mdl" )
		self.CSModels["bodybase"]:SetNoDraw( true )
		self.CSModels["bodybase"]:EnableMatrix( "RenderMultiply" , bodybasematrix )
		
		local backbasematrix = Matrix()
		backbasematrix:Scale( Vector( 0.25 , 0.25 , 0.5 ) )
		backbasematrix:SetAngles( Angle( 0 , 180 , 0 ) )
		
		self.CSModels["backbodybase"] = ClientsideModel( "models/props_lab/teleportring.mdl" )
		self.CSModels["backbodybase"]:SetNoDraw( true )
		self.CSModels["backbodybase"]:EnableMatrix( "RenderMultiply" , backbasematrix )
				
		local hookmatrix = Matrix()
		hookmatrix:SetAngles( Angle( 90 , 0 , 0 ) )
		hookmatrix:Scale( Vector( 1 , 1 , 0.1 ) / 4 )
		
		self.CSModels.Hook = {}
		self.CSModels.Hook["hook"] = ClientsideModel( "models/props_lab/jar01b.mdl" )
		self.CSModels.Hook["hook"]:SetNoDraw( true )
		self.CSModels.Hook["hook"]:EnableMatrix( "RenderMultiply" , hookmatrix )
		
		--yes this is lame, yes I don't care
		
		local hookgibmatrixleft = Matrix()
		hookgibmatrixleft:SetScale( Vector( 1 , 1 , 5 ) / 6 )
		hookgibmatrixleft:SetAngles( Angle( -45 + 90 , 0 , 90 ) )
		hookgibmatrixleft:SetTranslation( Vector( 0.5 , 0 , -1 ) )
		self.CSModels.Hook["hookgibleft"] = ClientsideModel( "models/Gibs/manhack_gib05.mdl" )
		self.CSModels.Hook["hookgibleft"]:SetNoDraw( true )
		self.CSModels.Hook["hookgibleft"]:EnableMatrix( "RenderMultiply" , hookgibmatrixleft )

		local hookgibmatrixright = Matrix()
		hookgibmatrixright:SetScale( Vector( 1 , 1 , 5 ) / 6 )
		hookgibmatrixright:SetAngles( Angle( 0 , -45 , 0 ) )
		hookgibmatrixright:SetTranslation( Vector( 0.5 , -1 , 0 ) )
		self.CSModels.Hook["hookgibright"] = ClientsideModel( "models/Gibs/manhack_gib05.mdl" )
		self.CSModels.Hook["hookgibright"]:SetNoDraw( true )
		self.CSModels.Hook["hookgibright"]:EnableMatrix( "RenderMultiply" , hookgibmatrixright )
		
		local hookgibmatrixup = Matrix()
		hookgibmatrixup:SetScale( Vector( 1 , 1 , 5 ) / 6 )
		hookgibmatrixup:SetAngles( Angle( -45 , 0 , -90 ) )
		hookgibmatrixup:SetTranslation( Vector( 0.5, 0 , 1 ) )
		self.CSModels.Hook["hookgibup"] = ClientsideModel( "models/Gibs/manhack_gib05.mdl" )
		self.CSModels.Hook["hookgibup"]:SetNoDraw( true )
		self.CSModels.Hook["hookgibup"]:EnableMatrix( "RenderMultiply" , hookgibmatrixup )
		
		local hookgibmatrixdown = Matrix()
		hookgibmatrixdown:SetScale( Vector( 1 , 1 , 5 ) / 6 )
		hookgibmatrixdown:SetAngles( Angle( 0 , 90 - 45 , 180 ) )
		hookgibmatrixdown:SetTranslation( Vector( 0.5, 1 , 0 ) )
		self.CSModels.Hook["hookgibdown"] = ClientsideModel( "models/Gibs/manhack_gib05.mdl" )
		self.CSModels.Hook["hookgibdown"]:SetNoDraw( true )
		self.CSModels.Hook["hookgibdown"]:EnableMatrix( "RenderMultiply" , hookgibmatrixdown )
	end
	
	function ENT:RemoveModels()
		--really can't be arsed to make a DeepRemove function
		for i , v in pairs( self.CSModels ) do
			if IsValid( v ) then
				v:Remove()
			end
		end
		
		for i , v in pairs( self.CSModels.Hook ) do
			if IsValid( v ) then
				v:Remove()
			end
		end
	end
	
	--draws the rope and grapple
	
	function ENT:DrawGrapple( flags )
		
		local cablesize = self.HookCableSize
		
		local startgrapplepos , startgrappleang = self:GetHookAttachment()
		
		local endgrapplepos = vector_origin
		local endgrappleang = angle_zero
		
		if self:IsCarriedByLocalPlayer() and not self:GetControllingPlayer():ShouldDrawLocalPlayer() then
			local eyepos = self:GetControllingPlayer():EyePos()
			local aimvecang = self:GetControllingPlayer():EyeAngles()
			startgrapplepos = eyepos + aimvecang:Up() * - 30
		end
		
		if self:GetIsAttached() or self:IsHookReturning() then
			endgrappleang = self:GetGrappleNormal():Angle()
			
			local dosway = false
			local travelfraction = 0
			
			if self:GetAttachTime() >= CurTime() or self:IsHookReturning() then
				
				dosway = self:IsCarriedByLocalPlayer()
				
				travelfraction = math.TimeFraction( self:GetAttachStart() , self:GetAttachTime() , CurTime() )
				
				endgrapplepos = LerpVector( travelfraction , startgrapplepos , self:GetAttachedTo() )
				
			else
			
				endgrapplepos = self:GetAttachedTo()
				
			end
			
			render.SetMaterial( self.CableMaterial )
			
			--only do this expensive rendering when carried by the local player
			
			if dosway and not self:IsHookReturning() then
				
				local swayamount = Lerp( travelfraction , 4 * cablesize , 0 )	--bigger cable = bigger sway
				
				local lengthfraction = ( endgrapplepos - startgrapplepos ):Length() / self.HookMaxRange
				
				local ang = ( endgrapplepos - startgrapplepos ):Angle()
				local swayres = math.floor( Lerp( lengthfraction , 64 , 16 ) )	--number of segments to use for the swayamount
				
				render.StartBeam( swayres + 2 )
				
					render.AddBeam( startgrapplepos , cablesize , 2 , color_white )
					
					for i = 1 , swayres do
						
						local frac = i / ( swayres - 1 )
						
						local curendpos = Lerp( frac , startgrapplepos , endgrapplepos )
						
						local t = UnPredictedCurTime() * 25 + 50 * frac
						
						local swayvec = Vector( 0 , 0 , 0 )
						
						--TODO: individual checks for when returning and shooting?
						
						swayvec:Add( ang:Right() * math.sin( t ) * swayamount )
						
						swayvec:Add( ang:Up() * math.cos( t ) * swayamount )
						
						render.AddBeam( curendpos + swayvec , cablesize , 3 , color_white )
						
					end
					
					render.AddBeam( endgrapplepos , cablesize , 3 , color_white )
					
				render.EndBeam()
				
			else
				
				render.StartBeam( 2 )
					render.AddBeam( startgrapplepos , cablesize , 2 , color_white )
					render.AddBeam( endgrapplepos , cablesize , 3 , color_white )
				render.EndBeam()
				
			end
			
			self:DrawHook( endgrapplepos , endgrappleang , flags )
			
		end
	end
	
	--draws the hook at the given position
	function ENT:DrawHook( pos , ang , flags )
		
		if not self.CSModels then
			return
		end
		
		for i , v in pairs( self.CSModels.Hook ) do
			if IsValid( v ) then
				v:SetupBones()
				v:SetPos( pos )
				v:SetAngles( ang )
				v:DrawModel( flags )
			end
		end
		
		--[[
		render.SetMaterial( self.WireFrame )
		render.DrawBox( pos, ang, self.HookHullMins, self.HookHullMaxs, color_white, true )
		]]
	end
	
	function ENT:Draw( flags )
		local pos , ang = self:GetCustomParentOrigin()
		
		--even though the calcabsoluteposition hook should already prevent this, it doesn't on other players
		--might as well not give it the benefit of the doubt in the first place
		if pos and ang then
			self:SetPos( pos )
			self:SetAngles( ang )
			self:SetupBones()	--seems to be needed since we're never technically drawing the model
		end
		
		self:DrawCSModel( self:GetPos() , self:GetAngles() , flags )
		
		if not self:GetIsAttached() and not self:IsHookReturning() then
			local hpos , hang = self:GetHookAttachment()
			self:DrawHook( hpos , hang )
		end
	end
	
	function ENT:DrawCSModel( pos , ang , flags )
		for i , v in pairs( self.CSModels ) do
			if IsValid( v ) then	--we may encounter nested tables but it doesn't matter because they don't have .IsValid
				v:SetupBones()
				v:SetPos( pos )
				v:SetAngles( ang )
				v:DrawModel( flags )
			end
		end
		
		--[[
		render.SetMaterial( self.WireFrame )
		render.DrawBox( pos, ang, self.MinBounds , self.MaxBounds, color_white, true )
		]]
	end
	
	function ENT:DrawFirstPerson( ply , vm )
	
	end

end