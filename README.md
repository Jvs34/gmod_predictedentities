gmod-predictedentities
======================

An entity base that you can use to create any sort of player usable addon, such as a jetpack, a shoulder strapped rocket launcher ( and more ) that can also function normally in the world.

It has support for custom keybindings and right click editing.



======================

##Inherited properties:

```
SHARED ENT.UseNWVars
```
Sets whether to use the old DTVars limit or disregard it, this is set automatically if the user is in the new gmod branch.



```
SHARED ENT.IsPredictedEnt
```
Utility variable



```
SHARED ENT.ShowPickupNotice 
```
Whether we should call HUDItemPickedUp clientside with this item class



```
SERVER ENT.DropOnDeath 
```
Whether to drop this entity on player's death



```
SHARED ENT.AttachesToPlayer 
```
We attach to a player, use ENT.AttachmentInfo for the positions



```
SHARED ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}
```
The table definition for the attachment



##Functions

```
SHARED ENT:DefineNWVar( dttype , dtname , editable , beautifulname , minval , maxval , customelement , filt )
```
From dtname and forward, the arguments are all optional if editable is false



```
SHARED ENT.<Get/Set>InButton( value )
```
The IN_* button to add to the usercmd when the user presses the prefered key ( can also be an unsigned int from 2 ^ 0 to 2 ^ 31 )



```
SHARED ENT:IsKeyDown( movedata )
```
Returns whether the controlling player is holding our ENT:GetInButton(), works best with a supplied movedata



```
SHARED ENT:IsCarried()
```
Returns whether we're carried at all



```
SHARED ENT:IsCarriedBy( ply )
```
Returns whether that ply is carrying us



```
CLIENT ENT:IsCarriedByLocalPlayer() 
```
Returns whether the LocalPlayer() is carrying us



```
CLIENT ENT:IsLocalPlayerUsingMySlot() 
```
Returns whether the LocalPlayer() is not using us on our slot



```
SHARED ENT:GetControllingPlayer() 
```
Returns the current player using us



```
SHARED ENT:GetBeingHeld() 
```
Returns if we're being held by the gravity gun or the physics gun or the +use pickup



```
SHARED ENT:GetSlotName() 
```
Returns the slot we're using on the player NWEntity slot



```
SHARED ENT:GetKey() 
```
The BUTTON enum for the key the user wants to user



```
SHARED ENT:<Set/Get>NextFire( value )
```
Convenient function defined in the base, pretty much the same as WEAPON:SetNextPrimaryAttack( CurTime() + 2 )



```
SHARED ENT:BackupMoveData( movedata ) 
```
Returns a backup of the movedata in a table



```
SHARED ENT:RestoreMoveData( movedata , saveddata ) 
```
Restores the backed up data from the table



##Hooks that you can override without calling to the base function

```
SERVER ENT:OnInitPhysics( physobj ) 
```
Called when the entity is first created or dropped ( if AttachesToPlayer is true )



```
SERVER ENT:OnRemovePhysics( physobj ) 
```
Called when the entity is picked up and AttachesToPlayer is true



```
SERVER ENT:DoInitPhysics()
```
Override this to implement your own physics boxes and whatever



```
SERVER ENT:DoRemovePhysics()
```
Override this to remove physics your own way? what



```
SERVER ENT:OnAttach( ply , forced ) 
```
Called when the player picks us up



```
SERVER ENT:OnDrop( ply , forced ) 
```
Called when we're dropped



```
CLIENT ENT:DrawFirstPerson( ply , vm )
```
Called on the renderscene pass



```
CLIENT ENT:DrawOnViewModel( ply , vm )
```
Called on the viewmodel pass



```
CLIENT ENT:Draw( flags ) 
```
Called on the opaque pass



```
CLIENT ENT:SetupCustomHUDElements( panel )
```
Called when our panel in the hud is initialized, we can then add stuff to it



```
SHARED ENT:PredictedStartCommand( ply , cmd )
```
Allows you to modify the player input before it's analyzed by the movement system, using it serverside allows you to control bots and catch cheaty bastards removing the client version



```
SHARED ENT:PredictedSetupMove( ply , mv , cmd )
```
Called when the usercmd has been analyzed and it's no longer useful, movement simulation starts here, return true to override the default movement



```
SHARED ENT:PredictedMove( ply , mv )
```
Middle of the movement simulation, half gravity has already been applied, return true to override the default movement



```
SHARED ENT:PredictedThink( ply , mv )
```
Called after Move and the movement system has done the walk checks



```
SHARED ENT:PredictedFinishMove( ply , mv )
```
Called after the movement simulation is done and has to set all the variables back to the player, return true to override default behaviour



```
SHARED ENT:PredictedHitGround( ply , inwater , onfloater , speed )
```
Called when the player hits the ground, called after Move, return true to disallow all the fall damage behaviour



```
SHARED ENT:HandleMainActivityOverride( ply , velocity )
```
Called when the player animates, return an activity ( can be -1 ) and a sequence ( can be -1 ) to override the default behaviour



```
SHARED ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
```
Called when the player animates, return true to override the default behaviour


