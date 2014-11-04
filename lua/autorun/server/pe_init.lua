--[[
	Boring stuff
]]

AddCSLuaFile( "autorun/client/pe_derma_hud.lua" )
AddCSLuaFile( "autorun/client/pe_derma_prop_editkey.lua" )
AddCSLuaFile( "autorun/client/pe_derma_ent.lua" )
--[[
AddCSLuaFile( "autorun/client/pe_derma_prop_vectornormal.lua" )
AddCSLuaFile( "autorun/client/pe_derma_prop_vectororigin.lua" )
]]

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