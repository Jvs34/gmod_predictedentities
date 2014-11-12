gmod-predictedentities
======================

An entity base that you can use to create any sort of player usable addon, such as a jetpack, a shoulder strapped rocket launcher ( and more ) that can also function normally in the world.

It has support for custom keybindings and right click editing.

======================

Inherited properties:

Static variables, not to be modified in real tmie

SHARED ENT.IsPredictedEnt

SERVER ENT.DropOnDeath whether to drop this entity on player's death

SHARED ENT.AttachesToPlayer we attach to a player, use ENT.AttachmentInfo for the positions

SHARED ENT.AttachmentInfo = {
								BoneName = "ValveBiped.Bip01_Spine2",
								OffsetVec = Vector( 3 , -5.6 , 0 ),
								OffsetAng = Angle( 180 , 90 , -90 ),
							}
SHARED ENT.InButton the IN_* button to add to the usercmd when the user presses the prefered key

Functions

SHARED ENT:DefineNWVar( dttype , dtname , editable , beautifulname , minval , maxval , customelement , filt ) from dtname and forward, the arguments are all optional if editable is false

SHARED ENT:IsKeyDown( movedata ) returns whether the controlling player is holding our ENT.InButton, works best with a supplied movedata

SHARED ENT:IsCarriedBy( ply ) returns whether that ply is carrying us

CLIENT ENT:IsCarriedByLocalPlayer() returns whether the LocalPlayer() is carrying us

CLIENT ENT:IsLocalPlayerUsingMySlot() returns whether the LocalPlayer() is not using us on our slot

SHARED ENT:GetControllingPlayer() returns the current player using us

SHARED ENT:GetBeingHeld() returns if we're being held by the gravity gun or the physics gun or the +use pickup

SHARED ENT:GetSlotName() returns the slot we're using on the player NWEntity slot

SHARED ENT:GetKey() the BUTTON enum for the key the user wants to user

SHARED ENT:<Set/Get>NextFire() convenient function defined in the base, pretty much the same as WEAPON:SetNextPrimaryAttack( CurTime() + 2 )

SHARED ENT:BackupMoveData( movedata ) returns a backup of the movedata in a table

SHARED ENT:RestoreMoveData( movedata , saveddata ) restores the backed up data from the table

Hooks

SERVER ENT:OnInitPhysics( physobj ) called when the entity is first created or dropped ( if AttachesToPlayer is true )

SERVER ENT:OnRemovePhysics( physobj ) called when the entity is picked up and AttachesToPlayer is true

SERVER ENT:OnAttach( ply , forced ) called when the player picks us up

SERVER ENT:OnDrop( ply , forced ) called when we're dropped

CLIENT ENT:DrawFirstPerson( ply , vm )	called on the renderscene pass

CLIENT ENT:DrawOnViewModel( ply , vm )	called on the viewmodel pass

CLIENT ENT:Draw( flags ) called on the opaque pass

CLIENT ENT:SetupCustomHUDElements( panel ) called when our panel in the hud is initialized, we can then add stuff to it

SHARED ENT:PredictedStartCommand( ply , cmd )

SHARED ENT:PredictedSetupMove( ply , mv , cmd )

SHARED ENT:PredictedMove( ply , mv )

SHARED ENT:PredictedThink( ply , mv )

SHARED ENT:PredictedFinishMove( ply , mv )

SHARED ENT:PredictedHitGround( ply , inwater , onfloater , speed )