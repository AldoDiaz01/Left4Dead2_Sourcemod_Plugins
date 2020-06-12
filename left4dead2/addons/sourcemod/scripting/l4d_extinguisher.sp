#define PLUGIN_VERSION		"1.8.3"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Extinguisher and Flamethrower
*	Author	:	SilverShot
*	Descrp	:	Usable Extinguishers.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=160232

========================================================================================
	Change Log:

1.8.3 (18-Aug-2013)
	- Fixed the Extinguisher being active when using a mounted gun. - Thanks to "Herbie" for reporting.

1.8.2 (21-Jul-2013)
	- Removed Sort_Random work-around. This was fixed in SourceMod 1.4.7, all should update or spawning issues will occur.

1.8.1 (07-Oct-2012)
	- Fixed the Extinguisher blocking players +USE by adding a single line of code - Thanks to "Machine".

1.8 (10-Jul-2012)
	- Fixed hurting players behind you.

1.7 (25-May-2012)
	- Added cvar "l4d_extinguisher_vomit" to remove the boomer vomit effect from players on the first spray.
	- Fixed the Extinguisher type not causing damage when combo cvar was set to 0.
	- Fixed Louis and Zoey effects spraying in the wrong direction in L4D2.

1.6 (21-May-2012)
	- Added German translations - Thanks to "Dont Fear The Reaper".

1.6 (10-May-2012)
	- Added cvar "l4d_extinguisher_time" to control how long players have to shoot when standing in fire before removing it.
	- Fixed the fires not being removed properly.
	- Fixed the extinguisher not appearing after throwing held objects.
	- Fixed refuel hints displaying in L4D1, refilling with gascans cannot work in L4D1.
	- Small changes.

1.5 (30-Mar-2012)
	- Added cvar "l4d_extinguisher_modes_off" to control which game modes the plugin works in.
	- Added cvar "l4d_extinguisher_modes_tog" same as above, but only works for L4D2.
	- Changed cvar "l4d_extinguisher_hint" added options 3 and 4.
	- Fixed errors the last update caused when Exintguishers were broken by things such as molotovs.
	- Fixed hookevent errors in L4D1, refilling with gascans cannot work in L4D1.
	- Fixed not being able to use pistols when incapped and being revived.
	- Fixed the extinguisher not showing in first person view when equipped after being snared or incapped.
	- Fixed a bug where deleting Extinguishers would also delete "type" entries.
	- Made it easier to extinguish fires by increasing the range which is detected.
	- Optimized the plugin by only creating PreThink hooks when Extinguishers/Gascans are equipped.
	- Optimized the plugin by not detecting the creation of prop_physics models.
	- Stopped setting freezerspray glow on common infected which already have a glow enabled.

1.4 (01-Dec-2011)
	- Fixed players getting stuck when an Extinguisher is broken and they are picking it up.

1.3 (01-Dec-2011)
	- Added Extinguishers to these maps: Crash Course, Death Toll, Dead Air, Blood Harvest, Cold Stream.
	- Added Russian translations - Thanks to "disawar1".
	- Added cvar l4d_extinguisher_incap so the Extinguisher can be used when incapacitated.
	- Added a new translation to notify players they can use the Extinguisher while incapped, if enabled.
	- Added a new translation when the Extinguisher is empty notifying players they can refuel with gas cans.
	- Fixed being able to use the Extinguisher while ridden by a jockey.
	- Fixed l4d_extinguisher_max cvar, limiting how many extinguishers can be used simultaneously.
	- Fixed the Extinguisher attachment position on Zoey.
	- Hides the Extinguisher from a players personal view when not equipped.
	- Made the translation files a requirement for the plugin to work error free.
	- Removed slot cvar. Picking up Extinguishers with pistols uses that slot. Other items default to the primary slot.

1.2 (01-Jul-2011)
	- Added refueling of dropped extinguishers.
	- Added new translations for the above.

1.1 (28-Jun-2011)
	- Fixed the type cvar not setting correctly when combo cvar was enabled.
	- Removed bad spawns from the data config.

1.0 (26-Jun-2011)
	- Initial Release.

======================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "DJ_WEST" For Chainsaw Refueling code showing usage of point_prop_use_target.
	http://forums.alliedmods.net/showthread.php?t=121983

======================================================================================*/

#pragma semicolon				1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define CVAR_FLAGS				FCVAR_PLUGIN|FCVAR_NOTIFY
#define CONFIG_SPAWNS			"data/l4d_extinguisher.cfg"
#define MAX_ALLOWED				32

#define ATTACHMENT_BONE			"weapon_bone"
#define ATTACHMENT_EYES			"eyes"
#define ATTACHMENT_PRIMARY		"primary"
#define ATTACHMENT_ARM			"armR_T"

#define MODEL_EXTINGUISHER		"models/props/cs_office/Fire_Extinguisher.mdl"
#define MODEL_BOUNDING			"models/props/cs_militia/silo_01.mdl"
#define PARTICLE_RAND			"molotov_explosion_child_burst"
#define PARTICLE_FIRE1			"fire_jet_01_flame"
#define PARTICLE_FIRE2			"fire_small_02"
#define PARTICLE_SPRAY			"extinguisher_spray"
#define PARTICLE_BLAST1			"impact_steam_short"
#define PARTICLE_BLAST2			"charger_wall_impact_b"
#define SOUND_FIRE_L4D1			"ambient/Spacial_Loops/CarFire_Loop.wav"
#define SOUND_FIRE_L4D2			"ambient/fire/interior_fire02_stereo.wav"
#define SOUND_SPRAY				"ambient/gas/cannister_loop.wav"
#define SOUND_BLAST				"weapons/molotov/fire_ignite_4.wav"


static	Handle:g_hCvarAllow, Handle:g_hCvarBreak, Handle:g_hCvarCheck, Handle:g_hCvarCombo, Handle:g_hCvarDamage, Handle:g_hCvarFreq, Handle:g_hCvarFriend,
		Handle:g_hCvarFuel, Handle:g_hCvarGrab, Handle:g_hCvarHint, Handle: g_hCvarIncap, Handle:g_hCvarGlowB, Handle:g_hCvarGlowE, Handle:g_hCvarGlowF,
		Handle:g_hCvarGlowS, Handle:g_hCvarGlowRan, Handle:g_hCvarFlame, Handle:g_hCvarMax, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog,
		Handle:g_hCvarPush, Handle:g_hCvarPushFuel, Handle:g_hCvarPushTime, Handle:g_hCvarRandom, Handle:g_hCvarRange, Handle:g_hCvarRemove, Handle:g_hCvarSpray,
		Handle:g_hCvarTime, Handle:g_hCvarTimed, Handle:g_hCvarTimeOut, Handle:g_hCvarType, Handle:g_hCvarView, Handle:g_hCvarVomit, Handle:g_hCvarWeapon,

		bool:g_bCvarAllow, g_iCvarBreak, g_iCvarCheck, g_iCvarCombo, g_iCvarDamage, g_iCvarFlame, Float:g_fCvarFreq, g_iCvarFriend, g_iCvarFuel, g_iCvarGrab,
		g_iCvarHint, g_iCvarGlowB, g_iCvarGlowE, g_iCvarGlowF, g_iCvarGlowS, g_iCvarGlowRan, g_iCvarIncap, g_iCvarMax, g_iCvarPush, g_iCvarPushFuel,
		Float:g_fCvarPushTime, g_iCvarRandom, g_iCvarRemove, Float:g_fCvarRange, g_iCvarSpray, g_iCvarTime, Float:g_fCvarTimed, Float:g_fCvarTimeout,
		g_iCvarType, g_iCvarView, g_iCvarVomit, String:g_sCvarWeapon[32];

static	bool:g_bLeft4Dead2, g_iLoadStatus, g_iPlayerSpawn, g_iRoundStart, g_iSpawnCount, bool:g_bGlow, g_iOffsetGlow,
		Handle:g_hTimerTrace, Handle:g_hMPGameMode, Handle:g_hSdkVomit,
		g_iWallExt[MAX_ALLOWED][3],		// Wall extinguishers: [0] = prop_physics, [1] = func_button, [2] = Type.
		g_iDropped[MAX_ALLOWED][4],		// Dropped extinguishers: [0] = prop_physics, [1] = func_button, [2] = Fuel, [3] = Type.
		g_iSpawned[MAX_ALLOWED][4],		// Spawned extinguishers: [0] = prop_physics, [1] = func_button, [2] = Fuel, [3] = Type.
		g_iInferno[MAX_ALLOWED][3],		// Del molotov/fireworks: [0] = trigger_multiple, [1] = inferno / fire_cracker_blast / insect_swarm, [2] = Count
		g_iPlayerData[MAXPLAYERS+1][6],	// [0] = prop_dynamic, [1] = info_particle, [2] = Light, [3] = Fuel, [4] = Type, [5] Blocked use.
		g_iRefuel[MAXPLAYERS+1][3],		// [0] = Gascan Index, [1] = point_prop_use_target, [2] = g_iDropped extinguisher index.
		g_iGunSlot[MAXPLAYERS+1],		// [0] = Primary Slot, [1] = Melee, [2] = Melee slot when incapped (returns to 0 after).
		g_iHooked[MAXPLAYERS+1],		// SDKHooks PreThink 0=Off/1=On.
		Handle:g_hTimeout[MAXPLAYERS+1],
		Handle:g_hTimepre[MAXPLAYERS+1];


enum (<<=1)
{
	ENUM_WALLEXT = 1,
	ENUM_DROPPED,
	ENUM_SPAWNED,
	ENUM_BLOCKED,
	ENUM_INCAPPED,
	ENUM_INREVIVE
}
enum (<<=1)
{
	ENUM_EXTINGUISHER = 1,
	ENUM_FLAMETHROWER,
	ENUM_FREEZERSPRAY,
	ENUM_BLASTPUSHBACK
}
enum ()
{
	TYPE_EXTINGUISHER = 1,
	TYPE_FLAMETHROWER,
	TYPE_FREEZERSPRAY,
	TYPE_BLASTPUSHBACK
}

enum ()
{
	INDEX_PROP,
	INDEX_PART,
	INDEX_LIGHT,
	INDEX_FUEL,
	INDEX_TYPE,
	INDEX_BLOCK
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D & L4D2] Extinguisher and Flamethrower",
	author = "SilverShot",
	description = "Usable Extinguishers.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=160232"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if( strcmp(sGameName, "left4dead", false) == 0 ) g_bLeft4Dead2 = false;
	else if( strcmp(sGameName, "left4dead2", false) == 0 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	// SDK Calls
	new Handle:hGameConf = LoadGameConfigFile("l4d_extinguisher");
	if( hGameConf == INVALID_HANDLE )
		SetFailState("Failed to load gamedata: l4d_extinguisher.txt");

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CTerrorPlayer::OnITExpired") == false )
		SetFailState("Failed to find signature: CTerrorPlayer::OnITExpired");

	g_hSdkVomit = EndPrepSDKCall();

	if( g_hSdkVomit == INVALID_HANDLE )
		SetFailState("Failed to create SDKCall: CTerrorPlayer::OnITExpired");


	// Translations
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "translations/extinguisher.phrases.txt");
	if( !FileExists(sPath) )
		SetFailState("Required translation file is missing: 'translations/extinguisher.phrases.txt'");

	LoadTranslations("extinguisher.phrases");
	LoadTranslations("common.phrases");

	// Cvars
	g_hCvarAllow = CreateConVar(		"l4d_extinguisher_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarBreak = CreateConVar(		"l4d_extinguisher_break",		"2",			"0=No break, 1=Valve default breaks when damaged, 2=Breaks and cannot be used, 3=Same as 2 but special infected can't break.", CVAR_FLAGS);
	g_hCvarCheck = CreateConVar(		"l4d_extinguisher_check",		"0",			"Players must have the l4d_extinguisher_weapon to equip and use Extinguishers.", CVAR_FLAGS);
	g_hCvarCombo = CreateConVar(		"l4d_extinguisher_combo",		"255 255 255",	"0=Off. Otherwise all Extinguisher functions in one. Sets the Extinguisher glow color. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS);
	g_hCvarDamage = CreateConVar(		"l4d_extinguisher_damage",		"1",			"How much damage the Extinguisher does per touch when fired. Triggered according to frequency cvar.", CVAR_FLAGS);
	g_hCvarFlame = CreateConVar(		"l4d_extinguisher_flame",		"2",			"Flamethrower particles and glow. 0=Flame type A, 1=Flame type B, 2=Type A + Light, 3=Type B + Light.", CVAR_FLAGS);
	g_hCvarFreq = CreateConVar(			"l4d_extinguisher_frequency",	"0.1",			"How often the damage trace fires, igniting entities etc.", CVAR_FLAGS);
	g_hCvarFriend = CreateConVar(		"l4d_extinguisher_friendly",	"1",			"0=Off, 1=Friendly fire, allow survivors to hurt each other, 2=Only hurt survivors from the Blast type.", CVAR_FLAGS);
	g_hCvarFuel = CreateConVar(			"l4d_extinguisher_fuel",		"1000",			"0=Infinite, How much fuel each Extinguisher has. Consumption is based on how often the PreThink fires.", CVAR_FLAGS);
	g_hCvarGlowRan = CreateConVar(		"l4d_extinguisher_glow",		"150",			"0=Glow Off. Any other value sets the range at which extinguishers glow.", CVAR_FLAGS);
	g_hCvarGlowB = CreateConVar(		"l4d_extinguisher_glow_blast",	"255 255 0",	"0=Valve default. Any other value sets glow color for blast pushback.", CVAR_FLAGS);
	g_hCvarGlowE = CreateConVar(		"l4d_extinguisher_glow_extin",	"0 255 0",		"0=Valve default. Any other value sets glow color for extinguishers.", CVAR_FLAGS);
	g_hCvarGlowF = CreateConVar(		"l4d_extinguisher_glow_flame",	"255 0 0",		"0=Valve default. Any other value sets glow color for flamethrowers.", CVAR_FLAGS);
	g_hCvarGlowS = CreateConVar(		"l4d_extinguisher_glow_spray",	"0 150 255",	"0=Valve default. Any other value sets glow color for freezer sprays.", CVAR_FLAGS);
	g_hCvarGrab = CreateConVar(			"l4d_extinguisher_grab",		"32",			"0=Off, How many pre-existing extinguishers on maps can this plugin cater for.", CVAR_FLAGS);
	g_hCvarHint = CreateConVar(			"l4d_extinguisher_hint",		"1",			"0=Off, 1=Display hints from translation file, 2=Not when Broken, 3=Not when Refueled, 4=Not when Broken or Refueled.", CVAR_FLAGS);
	g_hCvarIncap = CreateConVar(		"l4d_extinguisher_incap",		"1",			"0=Off, 1=Allow the Extinguisher to be used when incapacitated.", CVAR_FLAGS);
	g_hCvarMax = CreateConVar(			"l4d_extinguisher_max",			"0",			"Maximum number of players allowed to have the Extinguisher at once.", CVAR_FLAGS);
	g_hCvarModes =	CreateConVar(		"l4d_extinguisher_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d_extinguisher_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarModesTog = CreateConVar(	"l4d_extinguisher_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarPush =	CreateConVar(		"l4d_extinguisher_push",		"400",			"When hit by the blast type, push players/infected by this much force.", CVAR_FLAGS );
	g_hCvarPushFuel = CreateConVar(		"l4d_extinguisher_push_fuel",	"50",			"0=Infinite, How much fuel to take away when using the blast pushback type.", CVAR_FLAGS);
	g_hCvarPushTime = CreateConVar(		"l4d_extinguisher_push_time",	"0.5",			"How long after using the blast pushback type before it can be used again.", CVAR_FLAGS);
	g_hCvarRandom = CreateConVar(		"l4d_extinguisher_random",		"1",			"0=Off, -1=All, any other value sets how many randomly auto spawn from the config.", CVAR_FLAGS);
	g_hCvarRange = CreateConVar(		"l4d_extinguisher_range",		"150",			"How far the Extinguisher can affect entities.", CVAR_FLAGS);
	g_hCvarRemove = CreateConVar(		"l4d_extinguisher_remove",		"0",			"0=Off, 1=Remove extinguishers after being broken, 2=Remove when out of fuel, 3=Remove when broken or out of fuel.", CVAR_FLAGS);
	g_hCvarSpray = CreateConVar(		"l4d_extinguisher_spray",		"7",			"What can be extinguished with the Extinguisher type? 1=Molotovs/Barrels, 2=Firework Explosions, 4=Spitter Acid, 7=All.", CVAR_FLAGS);
	g_hCvarTime = CreateConVar(			"l4d_extinguisher_time",		"8",			"How long players have to shoot the Extinguisher type when standing in a fire before it can be removed.", CVAR_FLAGS);
	g_hCvarTimed = CreateConVar(		"l4d_extinguisher_timed",		"1.0",			"How long does it take to pick up extinguishers.", CVAR_FLAGS);
	g_hCvarTimeOut = CreateConVar(		"l4d_extinguisher_timeout",		"0.2",			"How long after using the Extinguisher till you can use it again.", CVAR_FLAGS);
	g_hCvarType = CreateConVar(			"l4d_extinguisher_type",		"15",			"Which types are allowed: 1=Extinguisher, 2=Flamethrower, 4=Freezer spray, 8=Blast, 15=All.", CVAR_FLAGS);
	g_hCvarView = CreateConVar(			"l4d_extinguisher_view",		"1",			"When clients hold the Extinguisher: 0=Show it, 1=Show it and hide their weapon, 2=Show their weapon and hide Extinguisher, 3=Same as 2 but others can see the Extinguisher.", CVAR_FLAGS);
	g_hCvarVomit = CreateConVar(		"l4d_extinguisher_vomit",		"5",			"Remove the boomer vomit effect from players on the first spray. 0=Off, 1=Extinguisher, 2=Flamethrower, 4=Blast type, 7=All.", CVAR_FLAGS);
	g_hCvarWeapon = CreateConVar(		"l4d_extinguisher_weapon",		"",				"\"\"=All (must set l4d_extinguisher_check to 0). Weapon entity name to replace and use for the Extinguisher.", CVAR_FLAGS);
	CreateConVar(						"l4d_extinguisher_version",		PLUGIN_VERSION,	"Extinguisher plugin version.", CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_extinguisher");

	g_hMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hMPGameMode,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	if( g_bLeft4Dead2 )
		HookConVarChange(g_hCvarModesTog,	ConVarChanged_Allow);
	HookConVarChange(g_hCvarBreak,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarCheck,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarCombo,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarDamage,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarFlame,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarFreq,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarFriend,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarFuel,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarGlowB,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarGlowE,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarGlowF,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarGlowS,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarGlowRan,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarGrab,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarHint,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarIncap,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarMax,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarPush,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarPushFuel,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarPushTime,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarRandom,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarRange,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarRemove,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarSpray,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarTime,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarTimed,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarTimeOut,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarType,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarView,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarVomit,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarWeapon,			ConVarChanged_Cvars);

	RegConsoleCmd(	"sm_dropext",	CmdDrop,						"Drops an equipped extinguisher. Admins usage: sm_dropext <#userid|name>. No arguments = self.");
	RegAdminCmd(	"sm_giveext",	CmdGive,		ADMFLAG_ROOT,	"Gives extinguisher. Usage: sm_giveext <1|2|3|4> (give to self, where 1=Extinguisher, 2=Flamethrower, 3=Freezerspray, 4=Blast Pushback) or <#userid|name> <type: 1|2|3|4>");
	RegAdminCmd(	"sm_spawnext",	CmdSpawn,		ADMFLAG_ROOT,	"Spawns an extinguisher at your crosshair location. Usage: sm_spawnext <1|2|3|4> (1=Extinguisher, 2=Flamethrower, 3=Freezerspray, 4=Blast Pushback)");
	RegAdminCmd(	"sm_extwep",	CmdExtWep,		ADMFLAG_ROOT,	"Gives the l4d_extinguisher_weapon to the target player(s). Usage: sm_extwep <#userid|name>. No arguments = self.");
	RegAdminCmd(	"sm_extsave",	CmdExtSave,		ADMFLAG_ROOT,	"Spawns a extinguisher at your crosshair and saves to config. Usage: sm_extsave <1|2|4|8> 1=Extinguisher, 2=Flamethrower, 4=Freezerspray, 8=Blast Pushback, 15=Any.");
	RegAdminCmd(	"sm_extang",	CmdExtAng,		ADMFLAG_ROOT,	"Set angle of extinguisher behind crosshair. Only works on sm_extsave extinguishers.");
	RegAdminCmd(	"sm_extpos",	CmdExtPos,		ADMFLAG_ROOT,	"Set position of extinguisher behind crosshair. Only works on sm_extsave extinguishers.");
	RegAdminCmd(	"sm_extset",	CmdExtSet,		ADMFLAG_ROOT,	"Save to the config the ang/pos of extinguisher behind crosshair if spawned with sm_extsave.");
	RegAdminCmd(	"sm_extdel",	CmdExtDelete,	ADMFLAG_ROOT,	"Removes the extinguisher your crosshair is pointing at.");
	RegAdminCmd(	"sm_extclear",	CmdExtClear,	ADMFLAG_ROOT,	"Removes all extinguishers from the current map (except those equipped by players).");
	RegAdminCmd(	"sm_extwipe",	CmdExtWipe,		ADMFLAG_ROOT,	"Removes all extinguishers from the current map and deletes them from the config.");
	RegAdminCmd(	"sm_extlist",	CmdExtList,		ADMFLAG_ROOT,	"Display a list extinguisher positions and the number of extinguishers.");

	if( g_bLeft4Dead2 )
	{
		RegAdminCmd("sm_extglow",	CmdExtGlow,		ADMFLAG_ROOT,	"Toggle to enable glow on all extinguishers to see where they are placed.");
		g_iOffsetGlow = FindSendPropOffs("prop_physics", "m_nGlowRange");
	}
}

public OnPluginEnd()
{
	ResetPlugin();
}

ResetPlugin()
{
	KillEnts();

	for( new i = 1; i <= MaxClients; i++ )
	{
		g_iHooked[i] = 0;

		new entity = g_iRefuel[i][1];
		if( IsValidEntRef(entity) )
			AcceptEntityInput(entity, "Kill");

		if( IsClientInGame(i) )
		{
			KillAttachments(i, true);

			if( g_iHooked[i] )
			{
				g_iHooked[i] = 0;
				SDKUnhook(i, SDKHook_PreThink, OnPreThink);
			}
		}
	}

	g_iLoadStatus = 0;
}

public OnMapStart()
{
	PrecacheModel(MODEL_EXTINGUISHER, true);
	PrecacheModel(MODEL_BOUNDING, true);

	PrecacheParticle(PARTICLE_RAND);
	PrecacheParticle(PARTICLE_FIRE1);
	PrecacheParticle(PARTICLE_FIRE2);
	PrecacheParticle(PARTICLE_SPRAY);
	PrecacheParticle(PARTICLE_BLAST1);
	if( g_bLeft4Dead2 )
		PrecacheParticle(PARTICLE_BLAST2);

	PrecacheSound(SOUND_SPRAY, true);
	PrecacheSound(SOUND_BLAST, true);
	if( g_bLeft4Dead2 )
		PrecacheSound(SOUND_FIRE_L4D2, true);
	else
		PrecacheSound(SOUND_FIRE_L4D1, true);
}

public OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iLoadStatus = 0;
	ResetPlugin();
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public OnConfigsExecuted()
{
	GetCvars();
	IsAllowed();
}

public ConVarChanged_Cvars(Handle:convar, const String:oldValue[], const String:newValue[])
	GetCvars();

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
	IsAllowed();

GetCvars()
{
	g_iCvarBreak = GetConVarInt(g_hCvarBreak);
	g_iCvarCheck = GetConVarInt(g_hCvarCheck);
	g_iCvarCombo = GetColor(g_hCvarCombo);
	g_iCvarDamage = GetConVarInt(g_hCvarDamage);
	g_iCvarFlame = GetConVarInt(g_hCvarFlame);
	g_fCvarFreq = GetConVarFloat(g_hCvarFreq);
	g_iCvarFriend = GetConVarBool(g_hCvarFriend);
	g_iCvarFuel = GetConVarInt(g_hCvarFuel);
	g_iCvarGlowB = GetColor(g_hCvarGlowB);
	g_iCvarGlowE = GetColor(g_hCvarGlowE);
	g_iCvarGlowF = GetColor(g_hCvarGlowF);
	g_iCvarGlowS = GetColor(g_hCvarGlowS);
	g_iCvarGlowRan = GetConVarInt(g_hCvarGlowRan);
	g_iCvarGrab = GetConVarInt(g_hCvarGrab);
	g_iCvarHint = GetConVarInt(g_hCvarHint);
	g_iCvarIncap = GetConVarBool(g_hCvarIncap);
	g_iCvarMax = GetConVarInt(g_hCvarMax);
	g_iCvarPush = GetConVarInt(g_hCvarPush);
	g_iCvarPushFuel = GetConVarInt(g_hCvarPushFuel);
	g_fCvarPushTime = GetConVarFloat(g_hCvarPushTime);
	g_iCvarRandom = GetConVarInt(g_hCvarRandom);
	g_fCvarRange = GetConVarFloat(g_hCvarRange);
	g_iCvarRemove = GetConVarInt(g_hCvarRemove);
	g_iCvarSpray = GetConVarInt(g_hCvarSpray);
	g_iCvarTime = GetConVarInt(g_hCvarTime);
	g_fCvarTimed = GetConVarFloat(g_hCvarTimed);
	g_fCvarTimeout = GetConVarFloat(g_hCvarTimeOut);
	g_iCvarType = GetConVarInt(g_hCvarType);
	g_iCvarView = GetConVarInt(g_hCvarView);
	g_iCvarVomit = GetConVarInt(g_hCvarVomit);
	GetConVarString(g_hCvarWeapon, g_sCvarWeapon, sizeof g_sCvarWeapon);
}

GetColor(Handle:cvar)
{
	decl String:sTemp[12], String:sColors[3][4];
	GetConVarString(cvar, sTemp, sizeof(sTemp));
	ExplodeString(sTemp, " ", sColors, 3, 4);

	new color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		LateLoad();
		HookEvents();
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		ResetPlugin();
		UnhookEvents();
	}

}

static g_iCurrentMode;

bool:IsAllowedGameMode()
{
	if( g_hMPGameMode == INVALID_HANDLE )
		return false;

	if( g_bLeft4Dead2 )
	{
		new iCvarModesTog = GetConVarInt(g_hCvarModesTog);
		if( iCvarModesTog != 0 )
		{
			g_iCurrentMode = 0;

			new entity = CreateEntityByName("info_gamemode");
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			AcceptEntityInput(entity, "PostSpawnActivate");
			AcceptEntityInput(entity, "Kill");

			if( g_iCurrentMode == 0 )
				return false;

			if( !(iCvarModesTog & g_iCurrentMode) )
				return false;
		}
	}

	decl String:sGameModes[64], String:sGameMode[64];
	GetConVarString(g_hMPGameMode, sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	GetConVarString(g_hCvarModes, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	GetConVarString(g_hCvarModesOff, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public OnGamemode(const String:output[], caller, activator, Float:delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}

LateLoad()
{
	LoadExtinguishers();

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			new weapon = GetEntProp(i, Prop_Send, "m_holdingObject");
			if( weapon != -1 )
			{
				decl String:sTemp[32];
				GetEdictClassname(weapon, sTemp, sizeof(sTemp));

				if( strcmp(sTemp, "gascan") == 0 )
				{
					SDKHook(i, SDKHook_PreThink, OnPreThink);
				}
			}
		}
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
HookEvents()
{
	HookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end",					Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("player_death",				Event_Remove);
	HookEvent("player_disconnect",			Event_Remove);
	HookEvent("player_team",				Event_Team);
	HookEvent("player_bot_replace",			Event_Swap_Bot);
	HookEvent("bot_player_replace",			Event_Swap_User);
	HookEvent("player_spawn",				Event_PlayerSpawn);
	HookEvent("revive_success",				Event_ReviveSuccess);
	HookEvent("revive_begin",				Event_ReviveStart);
	HookEvent("revive_end",					Event_ReviveEnd);
	HookEvent("player_incapacitated",		Event_BlockIncap);
	HookEvent("player_ledge_grab",			Event_BlockLedge);
	HookEvent("lunge_pounce",				Event_BlockStart);
	HookEvent("pounce_end",					Event_BlockEnd);
	HookEvent("tongue_grab",				Event_BlockStart);
	HookEvent("tongue_release",				Event_BlockEnd);

	if( g_bLeft4Dead2 )
	{
		HookEvent("charger_pummel_start",		Event_BlockStart);
		HookEvent("charger_carry_start",		Event_BlockStart);
		HookEvent("charger_carry_end",			Event_BlockEnd);
		HookEvent("charger_pummel_end",			Event_BlockEnd);
		HookEvent("jockey_ride",				Event_BlockStart);
		HookEvent("jockey_ride_end",			Event_BlockEnd);
		HookEvent("gascan_pour_completed",		Event_GascanPoured);
		HookEvent("item_pickup",				Event_GascanPickup);
		HookEvent("weapon_drop",				Event_GascanDropped);
	}
}

UnhookEvents()
{
	UnhookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
	UnhookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
	UnhookEvent("player_death",				Event_Remove);
	UnhookEvent("player_disconnect",		Event_Remove);
	UnhookEvent("player_team",				Event_Team);
	UnhookEvent("player_bot_replace",		Event_Swap_Bot);
	UnhookEvent("bot_player_replace",		Event_Swap_User);
	UnhookEvent("player_spawn",				Event_PlayerSpawn);
	UnhookEvent("revive_success",			Event_ReviveSuccess);
	UnhookEvent("revive_begin",				Event_ReviveStart);
	UnhookEvent("revive_end",				Event_ReviveEnd);
	UnhookEvent("player_incapacitated",		Event_BlockIncap);
	UnhookEvent("player_ledge_grab",		Event_BlockLedge);
	UnhookEvent("lunge_pounce",				Event_BlockStart);
	UnhookEvent("tongue_grab",				Event_BlockStart);
	UnhookEvent("pounce_end",				Event_BlockEnd);
	UnhookEvent("tongue_release",			Event_BlockEnd);

	if( g_bLeft4Dead2 )
	{
		UnhookEvent("charger_pummel_start",		Event_BlockStart);
		UnhookEvent("charger_carry_start",		Event_BlockStart);
		UnhookEvent("charger_carry_end",		Event_BlockEnd);
		UnhookEvent("charger_pummel_end",		Event_BlockEnd);
		UnhookEvent("jockey_ride",				Event_BlockStart);
		UnhookEvent("jockey_ride_end",			Event_BlockEnd);
		UnhookEvent("gascan_pour_completed",	Event_GascanPoured);
		UnhookEvent("item_pickup",				Event_GascanPickup);
		UnhookEvent("weapon_drop",				Event_GascanDropped);
	}
}

public Event_Remove(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client && IsClientInGame(client) )
		{
			new team = GetClientTeam(client);
			if( team == 2 )
				DropExtinguisher(client);
		}
	}
}

public Event_Team(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
		{
			new team = GetClientTeam(client);
			if( team != 2 )
				DropExtinguisher(client);
		}
	}
}

public Event_Swap_Bot(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));

	g_iPlayerData[bot][INDEX_FUEL] = g_iPlayerData[client][INDEX_FUEL];
	g_iPlayerData[bot][INDEX_TYPE] = g_iPlayerData[client][INDEX_TYPE];

	if( IsValidEntRef(g_iPlayerData[client][INDEX_PROP]) )
	{
		KillAttachments(client, true);
		GiveExtinguisher(bot);
	}
}

public Event_Swap_User(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));

	g_iPlayerData[client][INDEX_FUEL] = g_iPlayerData[bot][INDEX_FUEL];
	g_iPlayerData[client][INDEX_TYPE] = g_iPlayerData[bot][INDEX_TYPE];

	if( IsValidEntRef(g_iPlayerData[bot][INDEX_PROP]) )
	{
		KillAttachments(bot, true);
		GiveExtinguisher(client);
	}
}

public Event_ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
			g_iPlayerData[client][INDEX_BLOCK] &= ~ENUM_INREVIVE;
	}

	new userid = GetEventInt(event, "subject");
	client = GetClientOfUserId(userid);
	if( client )
	{
		g_iPlayerData[client][INDEX_BLOCK] = 0;

		if( g_iGunSlot[client] == 2 ) // Incapped extinguisher usage enabled, switch from melee slot to primary, as they had.
			g_iGunSlot[client] = 0;
		else if( g_iGunSlot[client] == 3 )
			g_iGunSlot[client] = 1;

		MoveExtinguisher(client, false);
		CreateTimer(0.1, tmrReviveSuccess, userid);
	}
}

public Action:tmrReviveSuccess(Handle:timer, any:client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new iValidWeapon = HasWeapon(client, iWeapon);
		if( iValidWeapon )
		{
			MoveExtinguisher(client, true);

			if( g_hTimeout[client] != INVALID_HANDLE )
				CloseHandle(g_hTimeout[client]);
			g_hTimeout[client] = CreateTimer(0.5, tmrTimeout, client);
		}
		else
		{
			MoveExtinguisher(client, false);
		}
	}
}

public Event_ReviveStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
		{
			g_iPlayerData[client][INDEX_BLOCK] |= ENUM_INREVIVE;
			MoveExtinguisher(client, false);
		}
	}

	client = GetEventInt(event, "subject");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
		{
			g_iPlayerData[client][INDEX_BLOCK] |= ENUM_INREVIVE;
			MoveExtinguisher(client, false);

			if( g_iCvarIncap )
			{
				if( g_iGunSlot[client] == 2 )
					g_iGunSlot[client] = 0;
				else if( g_iGunSlot[client] == 1 )
					g_iGunSlot[client] = 3;

				new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if( iWeapon > 0 )
					SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() - 0.2);
			}
		}
	}
}

public Event_ReviveEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
			g_iPlayerData[client][INDEX_BLOCK] &= ~ENUM_INREVIVE;
	}

	client = GetEventInt(event, "subject");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
		{
			g_iPlayerData[client][INDEX_BLOCK] &= ~ENUM_INREVIVE;

			if( g_iCvarIncap )
			{
				if( g_iGunSlot[client] == 0 )
					g_iGunSlot[client] = 2;
				else if( g_iGunSlot[client] == 3 )
					g_iGunSlot[client] = 1;

				MoveExtinguisher(client, true);
			}
			else
				MoveExtinguisher(client, false);
		}
	}
}

public Event_BlockIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( client )
	{
		if( !g_iCvarIncap )
		{
			MoveExtinguisher(client, false);
			new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			new iValidWeapon = HasWeapon(client, iWeapon);
			if( iValidWeapon )
				SetEntPropFloat(iValidWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.2);
		}
		else
		{
			MoveExtinguisher(client, true);

			if( g_iGunSlot[client] == 0 ) // 0 = Primary slot, temporarily move to pistol slot.
				g_iGunSlot[client] = 2;

			if( g_iCvarHint && IsValidEntRef(g_iPlayerData[client][INDEX_PROP]) )
			{
				new iType = g_iPlayerData[client][INDEX_TYPE];
				if( IsClientInGame(client) )
				{
					if( g_iCvarCombo || iType == TYPE_EXTINGUISHER )
						CPrintToChat(client, "%t%t", "Ext_ChatTagExtinguisher", "Ext_Incapped");
					else if( iType == TYPE_FLAMETHROWER )
						CPrintToChat(client, "%t%t", "Ext_ChatTagFlamethrower", "Ext_Incapped");
					else if( iType == TYPE_FREEZERSPRAY )
						CPrintToChat(client, "%t%t", "Ext_ChatTagFreezerspray", "Ext_Incapped");
					else
						CPrintToChat(client, "%t%t", "Ext_ChatTagBlastpushback", "Ext_Incapped");
				}
			}
		}
	}
}

public Event_BlockLedge(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( client )
	{
		if( g_iGunSlot[client] == 2 ) // Was in temporarily pistol slot, move to primary slot.
			g_iGunSlot[client] = 0;
		else if( g_iGunSlot[client] == 3 )
			g_iGunSlot[client] = 1;

		g_iPlayerData[client][INDEX_BLOCK] |= ENUM_INCAPPED;
		MoveExtinguisher(client, false);
	}
}

public Event_BlockStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	if( client )
	{
		g_iPlayerData[client][INDEX_BLOCK] |= ENUM_BLOCKED;
		MoveExtinguisher(client, false);
	}
}

public Event_BlockEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "victim");
	new client = GetClientOfUserId(userid);
	if( client )
	{
		g_iPlayerData[client][INDEX_BLOCK] &= ~ENUM_BLOCKED;

		CreateTimer(0.1, tmrReviveSuccess, userid);
	}
}

public Event_GascanPoured(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);

	new entity = g_iRefuel[client][1];
	g_iRefuel[client][1] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "Kill");

	new index = g_iRefuel[client][2] -1;
	if( index != -1 && IsValidEntRef(g_iDropped[index][0]) )
	{
		g_iDropped[index][2] = g_iCvarFuel;

		if( g_iCvarHint == 1 || g_iCvarHint == 2 )
		{
			new iType = g_iDropped[index][3];
			for( new i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) )
				{
					if( g_iCvarCombo || iType == TYPE_EXTINGUISHER )
						CPrintToChat(i, "%T%T", "Ext_ChatTagExtinguisher", i, "Ext_Refueled", i);
					else if( iType == TYPE_FLAMETHROWER )
						CPrintToChat(i, "%T%T", "Ext_ChatTagFlamethrower", i, "Ext_Refueled", i);
					else if( iType == TYPE_FREEZERSPRAY )
						CPrintToChat(i, "%T%T", "Ext_ChatTagFreezerspray", i, "Ext_Refueled", i);
					else
						CPrintToChat(i, "%T%T", "Ext_ChatTagBlastpushback", i, "Ext_Refueled", i);
				}
			}
		}
	}
}

public Event_GascanPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:sTemp[8];
	GetEventString(event, "item", sTemp, sizeof(sTemp));
	if( strcmp(sTemp, "gascan") == 0 )
	{
		new userid = GetEventInt(event, "userid");
		new client = GetClientOfUserId(userid);

		if( g_iHooked[client] == 0 )
		{
			g_iHooked[client] = 1;
			SDKHook(client, SDKHook_PreThink, OnPreThink);
		}

		new entity = g_iRefuel[client][1];

		if( IsValidEntRef(entity) )
			AcceptEntityInput(entity, "Kill");

		entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( entity != 0 && entity != -1 )
			g_iRefuel[client][0] = EntIndexToEntRef(entity);
		else
			g_iRefuel[client][0] = 0;

		MoveExtinguisher(client, false);
	}
}

public Event_GascanDropped(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);

	if( client )
	{
		decl String:sTemp[8];
		GetEventString(event, "item", sTemp, sizeof(sTemp));
		if( strcmp(sTemp, "gascan") == 0 )
		{
			new entity = g_iRefuel[client][1];
			g_iRefuel[client][1] = 0;

			if( IsValidEntRef(entity) )
				AcceptEntityInput(entity, "Kill");

			g_iRefuel[client][0] = 0;

			if( g_hTimeout[client] != INVALID_HANDLE )
				CloseHandle(g_hTimeout[client]);
			g_hTimeout[client] = CreateTimer(0.5, tmrTimeout, client);
		}

		CreateTimer(0.0, tmrReviveSuccess, userid);
	}
}



// ====================================================================================================
//					START EVENTS - LOAD EXTINGUISHERS
// ====================================================================================================
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bGlow = false;

	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(1.0, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iLoadStatus = 0;
	ResetPlugin();
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "userid");
	if( client )
	{
		client = GetClientOfUserId(client);
		if( client )
		{
			g_iPlayerData[client][INDEX_BLOCK] = 0;

			if( g_iGunSlot[client] == 2 ) // Incapped extinguisher usage enabled, switch from melee slot to primary, as they had.
				g_iGunSlot[client] = 0;
			else if( g_iGunSlot[client] == 3 )
				g_iGunSlot[client] = 1;
		}
	}

	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(1.0, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action:tmrStart(Handle:timer)
{
	LoadExtinguishers();
}

LoadExtinguishers()
{
	if( g_iLoadStatus == 1 ) return;
	g_iSpawnCount = 0;

	if( g_iCvarGrab )
	{
		new entity = -1;
		while( g_iSpawnCount < g_iCvarGrab && (entity = FindEntityByClassname(entity, "prop_physics")) != INVALID_ENT_REFERENCE )
			CreateButton(entity, ENUM_WALLEXT);
	}

	g_iLoadStatus = 1;

	if( !g_iCvarRandom )
		return;

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		return;

	// Load config
	new Handle:hFile = CreateKeyValues("extinguishers");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CloseHandle(hFile);
		return;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !KvJumpToKey(hFile, sMap) )
	{
		CloseHandle(hFile);
		return;
	}

	// Retrieve how many extinguishers to display
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount == 0 )
	{
		CloseHandle(hFile);
		return;
	}

	// Spawn only a select few extinguishers?
	new iType, index, i, iRandom = g_iCvarRandom;
	new iIndexes[MAX_ALLOWED+1];
	if( iCount > MAX_ALLOWED )
		iCount = MAX_ALLOWED;

	// Spawn all saved extinguishers or create random
	if( iRandom > iCount)
		iRandom = iCount;
	if( iRandom != -1 )
	{
		for( i = 1; i <= iCount; i++ )
			iIndexes[i-1] = i;

		SortIntegers(iIndexes, iCount, Sort_Random);
		iCount = iRandom;
	}

	// Get the extinguisher origins and spawn
	decl String:sTemp[10], Float:vPos[3], Float:vAng[3];
	for( i = 1; i <= iCount; i++ )
	{
		if( iRandom != -1 ) index = iIndexes[i-1];
		else index = i;

		Format(sTemp, sizeof(sTemp), "angle_%d", index);
		KvGetVector(hFile, sTemp, vAng);
		Format(sTemp, sizeof(sTemp), "origin_%d", index);
		KvGetVector(hFile, sTemp, vPos);
		Format(sTemp, sizeof(sTemp), "types_%d", index);
		iType = KvGetNum(hFile, sTemp, g_iCvarType);

		if( vPos[0] == 0.0 && vPos[0] == 0.0 && vPos[0] == 0.0 ) // Should never happen.
			LogError("Error: 0,0,0 origin. Iteration=%d. Index=%d. Count=%d.", i, index, iCount);
		else
			CreateExtinguisher(vPos, vAng, GetRandomType(iType), ENUM_SPAWNED);
	}

	CloseHandle(hFile);
}

CreateExtinguisher(Float:vPos[3], Float:vAng[3], iType, iEnum)
{
	new entity;

	for( new i = 0; i < MAX_ALLOWED; i++ )
	{
		if( (iEnum == ENUM_SPAWNED && !IsValidEntRef(g_iSpawned[i][0])) || (iEnum == ENUM_DROPPED && !IsValidEntRef(g_iDropped[i][0])) )
		{
			entity = CreateEntityByName("prop_physics");
			DispatchKeyValue(entity, "model", MODEL_EXTINGUISHER);
			TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
			DispatchSpawn(entity);
			SetEntityMoveType(entity, MOVETYPE_NONE);
			SetEntProp(entity, Prop_Data, "m_CollisionGroup", 1);
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);

			if( iEnum == ENUM_SPAWNED )
			{
				g_iSpawned[i][0] = EntIndexToEntRef(entity);
				g_iSpawned[i][2] = g_iCvarFuel;
				CreateButton(entity, ENUM_SPAWNED, iType);
			}
			else 
			{
				g_iDropped[i][0] = EntIndexToEntRef(entity);
				g_iDropped[i][2] = g_iCvarFuel;
				CreateButton(entity, ENUM_DROPPED, iType);
			}

			break;
		}
	}
	return entity;
}



// ====================================================================================================
//					COMMANDS - sm_dropext, sm_giveext, sm_spawnext, sm_extwep
// ====================================================================================================
public Action:CmdDrop(client, args)
{
	if( g_bCvarAllow )
	{
		if( args == 0 )
		{
			DropExtinguisher(client);
		}
		else
		{
			if( CheckCommandAccess(client, "", ADMFLAG_ROOT, true) )
			{
				decl String:target_name[MAX_TARGET_LENGTH], String:arg1[32];
				new target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

				GetCmdArg(1, arg1, sizeof(arg1));
			 
				if ((target_count = ProcessTargetString(
						arg1,
						client,
						target_list,
						MAXPLAYERS,
						COMMAND_FILTER_ALIVE,
						target_name,
						sizeof(target_name),
						tn_is_ml)) <= 0)
				{
					ReplyToTargetError(client, target_count);
					return Plugin_Handled;
				}
			 
				for (new i = 0; i < target_count; i++)
					DropExtinguisher(target_list[i]);
			}
		}
	}
	return Plugin_Handled;
}

public Action:CmdGive(client, args)
{
	if( g_bCvarAllow )
	{
		if( args == 0 )
		{
			g_iPlayerData[client][INDEX_FUEL] = g_iCvarFuel;
			g_iPlayerData[client][INDEX_TYPE] = GetRandomType(g_iCvarType);
			GiveExtinguisher(client);
		}
		else
		{
			decl String:arg1[32];
			GetCmdArg(1, arg1, sizeof(arg1));

			if( args == 1 && strlen(arg1) == 1 )
			{
				g_iPlayerData[client][INDEX_FUEL] = g_iCvarFuel;
				g_iPlayerData[client][INDEX_TYPE] = StringToInt(arg1);
				GiveExtinguisher(client);
				return Plugin_Handled;
			}

			new target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
			decl String:target_name[MAX_TARGET_LENGTH];

			if ((target_count = ProcessTargetString(
				arg1,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_ALIVE,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);
				return Plugin_Handled;
			}

			new target;
			for (new i = 0; i < target_count; i++)
			{
				target = target_list[i];
				if( GetClientTeam(target) == 2 )
				{
					g_iPlayerData[target][INDEX_FUEL] = g_iCvarFuel;
					if( args == 1 )
						g_iPlayerData[target][INDEX_TYPE] = GetRandomType(g_iCvarType);
					else
					{
						GetCmdArg(2, arg1, sizeof(arg1));
						g_iPlayerData[target][INDEX_TYPE] = StringToInt(arg1);
					}
					GiveExtinguisher(target);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:CmdSpawn(client, args)
{
	if( g_bCvarAllow )
	{
		if( args == 0 )
		{
			decl Float:vPos[3], Float:vAng[3];
			SetTeleportEndPoint(client, vPos, vAng);
			new entity = CreateExtinguisher(vPos, vAng, 0, ENUM_DROPPED);
			SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
		}
		else
		{
			decl String:arg1[4], Float:vPos[3], Float:vAng[3];
			GetCmdArg(1, arg1, sizeof(arg1));

			SetTeleportEndPoint(client, vPos, vAng);
			new entity = CreateExtinguisher(vPos, vAng, StringToInt(arg1), ENUM_DROPPED);
			SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
		}
	}
	return Plugin_Handled;
}

public Action:CmdExtWep(client, args)
{
	if( g_bCvarAllow )
	{
		if( strcmp(g_sCvarWeapon, "") == 0 )
		{
			ReplyToCommand(client, "[Extinguisher] Cannot give weapon, l4d_extinguisher_weapon string is empty!");
			return Plugin_Handled;
		}

		if( args == 0 && client && IsClientInGame(client) && IsPlayerAlive(client) )
			GiveWeapon(client);
		else
		{
			decl String:arg1[32];
			GetCmdArg(1, arg1, sizeof(arg1));

			new target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
			decl String:target_name[MAX_TARGET_LENGTH];

			if ((target_count = ProcessTargetString(
				arg1,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_ALIVE,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);
				return Plugin_Handled;
			}

			new target;
			for (new i = 0; i < target_count; i++)
			{
				target = target_list[i];
				GiveWeapon(target);
			}
		}
	}
	return Plugin_Handled;
}

GiveWeapon(client)
{
	if( GetClientTeam(client == 2 ) )
	{
		new bits = GetUserFlagBits(client);
		new flags = GetCommandFlags("give");
		SetUserFlagBits(client, ADMFLAG_ROOT);
		SetCommandFlags("give", flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "give %s", g_sCvarWeapon);
		SetUserFlagBits(client, bits);
		SetCommandFlags("give", flags);
	}
}



// ====================================================================================================
//					COMMANDS - SAVE, DELETE, CLEAR, WIPE, ANG, POS, LIST, GLOW
// ====================================================================================================
//					sm_extsave
// ====================================================================================================
public Action:CmdExtSave(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Extinguisher] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
		return Plugin_Handled;
	}

	// Load config
	new Handle:hFile = CreateKeyValues("extinguishers");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CPrintToChat(client, "%tError: Cannot read the extinguisher config, assuming empty file. (\x05%s\x01).", "Ext_ChatTagExtinguisher", sPath);
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if( !KvJumpToKey(hFile, sMap, true) )
	{
		CPrintToChat(client, "%tError: Failed to add map to extinguisher spawn config.", "Ext_ChatTagExtinguisher");
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Retrieve how many extinguishers are saved
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount >= MAX_ALLOWED )
	{
		CPrintToChat(client, "%tError: Cannot add anymore extinguishers. Used: (\x05%d/%d\x01).", "Ext_ChatTagExtinguisher", iCount, MAX_ALLOWED);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Set player position as extinguisher spawn location
	new Float:vPos[3], Float:vAng[3];
	if( !SetTeleportEndPoint(client, vPos, vAng) )
	{
		CPrintToChat(client, "%tCannot place extinguisher, please try again.", "Ext_ChatTagExtinguisher");
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Save count
	iCount++;
	KvSetNum(hFile, "num", iCount);

	// Save angle / origin
	decl String:sTemp[10];
	Format(sTemp, sizeof(sTemp), "angle_%d", iCount);
	KvSetVector(hFile, sTemp, vAng);
	Format(sTemp, sizeof(sTemp), "origin_%d", iCount);
	KvSetVector(hFile, sTemp, vPos);

	if( args == 1 )
	{
		decl String:sBuff[4];
		GetCmdArg(1, sBuff, sizeof(sBuff));
		new iType = StringToInt(sBuff);
		Format(sTemp, sizeof(sTemp), "types_%d", iCount);
		KvSetNum(hFile, sTemp, iType);
		CreateExtinguisher(vPos, vAng, GetRandomType(iType), ENUM_SPAWNED);
	}
	else
		CreateExtinguisher(vPos, vAng, 0, ENUM_SPAWNED);

	// Save cfg
	KvRewind(hFile);
	KeyValuesToFile(hFile, sPath);
	CloseHandle(hFile);

	// Create extinguisher
	CPrintToChat(client, "%t(\x05%d/%d\x01) - Saved at pos:[\x05%f %f %f\x01] ang:[\x05%f %f %f\x01]", "Ext_ChatTagExtinguisher", iCount, MAX_ALLOWED, vPos[0], vPos[1], vPos[2], vAng[0], vAng[1], vAng[2]);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_extdel
// ====================================================================================================
public Action:CmdExtDelete(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Extinguisher] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}

	decl Float:vPos[3], Float:vEntPos[3];
	new bool:delete, aim;
	aim = GetClientAimTarget(client, false);

	if( aim != -1 )
	{
		aim = EntIndexToEntRef(aim);
		for( new i = 0; i < MAX_ALLOWED; i++ )
		{
			if( aim == g_iSpawned[i][0] || aim == g_iSpawned[i][1] )
			{
				GetEntPropVector(g_iSpawned[i][0], Prop_Send, "m_vecOrigin", vEntPos);
				AcceptEntityInput(g_iSpawned[i][0], "Kill");
				AcceptEntityInput(g_iSpawned[i][1], "Kill");
				g_iSpawned[i][0] = 0;
				g_iSpawned[i][1] = 0;
				delete = true;
				break;
			}
			else if( aim == g_iDropped[i][0] || aim == g_iDropped[i][1] )
			{
				GetEntPropVector(g_iDropped[i][0], Prop_Send, "m_vecOrigin", vEntPos);
				AcceptEntityInput(g_iDropped[i][0], "Kill");
				AcceptEntityInput(g_iDropped[i][1], "Kill");
				g_iDropped[i][0] = 0;
				g_iDropped[i][1] = 0;
				CPrintToChat(client, "%tDropped Extinguisher removed.", "Ext_ChatTagExtinguisher");
				return Plugin_Handled;
			}
			if( delete ) break;
		}
	}

	if( !delete )
	{
		CPrintToChat(client, "%tError: Cannot find the extinguisher you tried to delete.", "Ext_ChatTagExtinguisher");
		return Plugin_Handled;
	}

	// Load config
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%tWarning: Cannot find the extinguisher config (\x05%s\x01).", "Ext_ChatTagExtinguisher", CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	new Handle:hFile = CreateKeyValues("extinguishers");
	if( !FileToKeyValues(hFile, sPath) )
	{
		PrintToChat(client, "%tWarning: Cannot load the extinguisher config (\x05%s\x01).", "Ext_ChatTagExtinguisher", sPath);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !KvJumpToKey(hFile, sMap) )
	{
		PrintToChat(client, "%tWarning: Current map not in the extinguisher config.", "Ext_ChatTagExtinguisher");
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Retrieve how many extinguishers
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount == 0 )
	{
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	new bool:bMove, iNum1;
	decl String:sTemp[10], Float:vAng[3];

	// Move the other entries down
	for( new i = 1; i <= iCount; i++ )
	{
		Format(sTemp, sizeof(sTemp), "origin_%d", i);
		KvGetVector(hFile, sTemp, vPos);

		if( !bMove )
		{
			if( GetVectorDistance(vPos, vEntPos) <= 1.0 )
			{
				KvDeleteKey(hFile, sTemp);
				Format(sTemp, sizeof(sTemp), "angle_%d", i);
				KvDeleteKey(hFile, sTemp);
				Format(sTemp, sizeof(sTemp), "types_%d", i);
				KvDeleteKey(hFile, sTemp);
				bMove = true;
			}
			else if ( i == iCount ) // No extinguishers... exit
			{
				PrintToChat(client, "%tWarning: Cannot find the extinguisher inside the config.", "Ext_ChatTagExtinguisher");
				CloseHandle(hFile);
				return Plugin_Handled;
			}
		}
		else
		{
			// Retrieve data and delete
			KvDeleteKey(hFile, sTemp);
			Format(sTemp, sizeof(sTemp), "angle_%d", i);
			KvGetVector(hFile, sTemp, vAng);
			KvDeleteKey(hFile, sTemp);
			Format(sTemp, sizeof(sTemp), "types_%d", i);

			iNum1 = KvGetNum(hFile, sTemp, -1);
			if( iNum1 != -1 )
				KvDeleteKey(hFile, sTemp);

			// Save data to previous id
			Format(sTemp, sizeof(sTemp), "angle_%d", i-1);
			KvSetVector(hFile, sTemp, vAng);
			Format(sTemp, sizeof(sTemp), "origin_%d", i-1);
			KvSetVector(hFile, sTemp, vPos);
			if( iNum1 != -1 )
			{
				Format(sTemp, sizeof(sTemp), "types_%d", i-1);
				KvSetNum(hFile, sTemp, iNum1);
			}
		}
	}

	iCount--;
	KvSetNum(hFile, "num", iCount);

	// Save to file
	KvRewind(hFile);
	KeyValuesToFile(hFile, sPath);
	CloseHandle(hFile);

	CPrintToChat(client, "%t(\x05%d/%d\x01) - Extinguisher removed from config.", "Ext_ChatTagExtinguisher", iCount, MAX_ALLOWED);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_extclear
// ====================================================================================================
public Action:CmdExtClear(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	KillEnts();
	CPrintToChat(client, "%tAll extinguishers removed from the map.", "Ext_ChatTagExtinguisher");
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_extwipe
// ====================================================================================================
public Action:CmdExtWipe(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Extinguisher] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		CPrintToChat(client, "%tError: Cannot find the extinguisher config (\x05%s\x01).", "Ext_ChatTagExtinguisher", sPath);
		return Plugin_Handled;
	}

	// Load config
	new Handle:hFile = CreateKeyValues("extinguishers");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CPrintToChat(client, "%tError: Cannot load the extinguisher config (\x05%s\x01).", "Ext_ChatTagExtinguisher", sPath);
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !KvJumpToKey(hFile, sMap, false) )
	{
		CPrintToChat(client, "%tError: Current map not in the extinguisher config.", "Ext_ChatTagExtinguisher");
		CloseHandle(hFile);
		return Plugin_Handled;
	}

	KvDeleteThis(hFile);

	// Save to file
	KvRewind(hFile);
	KeyValuesToFile(hFile, sPath);
	CloseHandle(hFile);

	KillEnts();
	CPrintToChat(client, "%t(0/%d) - All extinguishers removed from config, add new extinguishers with \x05sm_extsave\x01.", "Ext_ChatTagExtinguisher", MAX_ALLOWED);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_extang
// ====================================================================================================
public Action:CmdExtAng(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	ShowAngMenu(client);
	return Plugin_Handled;
}

ShowAngMenu(client)
{
	new Handle:menu = CreateMenu(AngMenuHandler);

	AddMenuItem(menu, "", "X + 5.0");
	AddMenuItem(menu, "", "Y + 5.0");
	AddMenuItem(menu, "", "Z + 5.0");
	AddMenuItem(menu, "", "");
	AddMenuItem(menu, "", "X - 5.0");
	AddMenuItem(menu, "", "Y - 5.0");
	AddMenuItem(menu, "", "Z - 5.0");

	SetMenuTitle(menu, "Set Angle");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AngMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
		CloseHandle(menu);
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowAngMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		ShowAngMenu(client);

		new aim = GetClientAimTarget(client, false);
		if( aim != -1 )
		{
			new Float:vAng[3], entity;

			for( new i = 0; i < MAX_ALLOWED; i++ )
			{
				entity = g_iSpawned[i][0];

				if( entity && EntRefToEntIndex(entity) == aim  )
				{
					GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
					if( index == 0 ) vAng[0] += 5.0;
					else if( index == 1 ) vAng[1] += 5.0;
					else if( index == 2 ) vAng[2] += 5.0;
					else if( index == 4 ) vAng[0] -= 5.0;
					else if( index == 5 ) vAng[1] -= 5.0;
					else if( index == 6 ) vAng[2] -= 5.0;
					TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);
					CPrintToChat(client, "%tNew angles: %f %f %f", "Ext_ChatTagExtinguisher", vAng[0], vAng[1], vAng[2]);
					break;
				}
			}
		}
	}
}

// ====================================================================================================
//					sm_extpos
// ====================================================================================================
public Action:CmdExtPos(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	ShowPosMenu(client);
	return Plugin_Handled;
}

ShowPosMenu(client)
{
	new Handle:menu = CreateMenu(PosMenuHandler);

	AddMenuItem(menu, "", "X + 0.5");
	AddMenuItem(menu, "", "Y + 0.5");
	AddMenuItem(menu, "", "Z + 0.5");
	AddMenuItem(menu, "", "");
	AddMenuItem(menu, "", "X - 0.5");
	AddMenuItem(menu, "", "Y - 0.5");
	AddMenuItem(menu, "", "Z - 0.5");

	SetMenuTitle(menu, "Set Position");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public PosMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
		CloseHandle(menu);
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowPosMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		ShowPosMenu(client);

		new aim = GetClientAimTarget(client, false);
		if( aim != -1 )
		{
			new Float:vPos[3], entity;
			for( new i = 0; i < MAX_ALLOWED; i++ )
			{
				entity = g_iSpawned[i][0];

				if( entity && EntRefToEntIndex(entity) == aim  )
				{
					GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
					if( index == 0 ) vPos[0] += 0.5;
					else if( index == 1 ) vPos[1] += 0.5;
					else if( index == 2 ) vPos[2] += 0.5;
					else if( index == 4 ) vPos[0] -= 0.5;
					else if( index == 5 ) vPos[1] -= 0.5;
					else if( index == 6 ) vPos[2] -= 0.5;
					TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
					CPrintToChat(client, "%tNew origin: %f %f %f", "Ext_ChatTagExtinguisher", vPos[0], vPos[1], vPos[2]);
					break;
				}
			}
		}
	}
}

// ====================================================================================================
//					sm_extset
// ====================================================================================================
public Action:CmdExtSet(client, args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Extinguisher] Commands may only be used in-game on a dedicated server..");
		return Plugin_Handled;
	}

	new aim = GetClientAimTarget(client, false);
	if( aim != -1 )
	{
		decl String:sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
		if( !FileExists(sPath) )
		{
			CPrintToChat(client, "%tError: Cannot find the extinguisher config (\x05%s\x01).", "Ext_ChatTagExtinguisher", sPath);
			return Plugin_Handled;
		}

		new Handle:hFile = CreateKeyValues("extinguishers");
		if( !FileToKeyValues(hFile, sPath) )
		{
			CPrintToChat(client, "%tError: Cannot read the extinguisher config (\x05%s\x01).", "Ext_ChatTagExtinguisher", sPath);
			CloseHandle(hFile);
			return Plugin_Handled;
		}

		// Check for current map in the config
		decl String:sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));
		if( !KvJumpToKey(hFile, sTemp, true) )
		{
			CPrintToChat(client, "%tError: Cannot find the current map in the config.", "Ext_ChatTagExtinguisher");
			CloseHandle(hFile);
			return Plugin_Handled;
		}

		decl Float:vPos[3], Float:vAng[3];
		new entity;

		for( new i = 0; i < MAX_ALLOWED; i++ )
		{
			entity = g_iSpawned[i][0];

			if( entity && EntRefToEntIndex(entity) == aim  )
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
				GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

				Format(sTemp, sizeof(sTemp), "angle_%d", i+1);
				KvSetVector(hFile, sTemp, vAng);
				Format(sTemp, sizeof(sTemp), "origin_%d", i+1);
				KvSetVector(hFile, sTemp, vPos);

				if( args == 1 )
				{
					decl String:sArg1[4];
					GetCmdArg(1, sArg1, sizeof(sArg1));
					Format(sTemp, sizeof(sTemp), "types_%d", i+1);
					KvSetNum(hFile, sTemp, StringToInt(sArg1));
				}

				KvRewind(hFile);
				KeyValuesToFile(hFile, sPath);
				CloseHandle(hFile);

				if( args == 1 )
					CPrintToChat(client, "%tSaved angles, origin and type to the config.", "Ext_ChatTagExtinguisher");
				else
					CPrintToChat(client, "%tSaved angles and origin to the config.", "Ext_ChatTagExtinguisher");
				return Plugin_Handled;
			}
		}

		CloseHandle(hFile);
	}
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_extlist, sm_extglow
// ====================================================================================================
public Action:CmdExtList(client, args)
{
	decl Float:vPos[3];
	new i, u, entity, count;

	for( u = 0; u < 3; u++ )
	{
		if( u == 0 )
		{
			if( client == 0 )
				ReplyToCommand(client, "[Extinguisher] Part of the Map:");
			else
				CPrintToChat(client, "%tPart of the Map:", "Ext_ChatTagExtinguisher");
		}
		else if( u == 1 )
		{
			if( client == 0 )
				ReplyToCommand(client, "[Extinguisher] Dropped by Players:");
			else
				CPrintToChat(client, "%tDropped by Players:", "Ext_ChatTagExtinguisher");
		}
		else if( u == 2 )
		{
			if( client == 0 )
				ReplyToCommand(client, "[Extinguisher] Spawned by Plugin:");
			else
				CPrintToChat(client, "%tSpawned by Plugin:", "Ext_ChatTagExtinguisher");
		}
		for( i = 0; i < MAX_ALLOWED; i++ )
		{
			if( u == 0 )
				entity = g_iWallExt[i][0];
			else if( u == 1 )
				entity = g_iDropped[i][0];
			else if( u == 2 )
				entity = g_iSpawned[i][0];

			if( IsValidEntRef(entity) )
			{
				count++;
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
				if( client == 0 )
					ReplyToCommand(client, "[Extinguisher] %d) %f %f %f", i+1, vPos[0], vPos[1], vPos[2]);
				else
					CPrintToChat(client, "%t%d) %f %f %f", "Ext_ChatTagExtinguisher", i+1, vPos[0], vPos[1], vPos[2]);
			}
		}

		if( client == 0 )
			ReplyToCommand(client, "[Extinguisher] --------------------");
		else
			CPrintToChat(client, "%t--------------------", "Ext_ChatTagExtinguisher");
	}

	if( client == 0 )
		ReplyToCommand(client, "[Extinguisher] Total: %d.", count);
	else
		CPrintToChat(client, "%tTotal: %d/%d.", "Ext_ChatTagExtinguisher", count, MAX_ALLOWED);
	return Plugin_Handled;
}

public Action:CmdExtGlow(client, args)
{
	new i, u, entity;
	g_bGlow = !g_bGlow;

	for( u = 0; u < 3; u++ )
	{
		for( i = 0; i < MAX_ALLOWED; i++ )
		{
			if( u == 0 )
				entity = g_iWallExt[i][0];
			else if( u == 1 )
				entity = g_iDropped[i][0];
			else if( u == 2 )
				entity = g_iSpawned[i][0];

			if( IsValidEntRef(entity) )
			{
				SetEntProp(entity, Prop_Send, "m_nGlowRange", g_bGlow ? 0 : g_iCvarGlowRan);
				ChangeEdictState(entity, g_iOffsetGlow);
				if( g_bGlow )
					AcceptEntityInput(entity, "StartGlowing");
				else if( !g_bGlow && !g_iCvarGlowRan )
					AcceptEntityInput(entity, "StopGlowing");
			}
		}
	}

	CPrintToChat(client, "%tGlow has been turned %s", "Ext_ChatTagExtinguisher", g_bGlow ? "on" : "off");
	return Plugin_Handled;
}



// ====================================================================================================
//					TIMEOUT / TRACE / HURT / PUSH - PRETHINK
// ====================================================================================================
public Action:tmrTimeout(Handle:timer, any:client)
{
	g_hTimeout[client] = INVALID_HANDLE;
}

public Action:tmrTimepre(Handle:timer, any:client)
{
	g_hTimepre[client] = INVALID_HANDLE;

	if( g_hTimeout[client] != INVALID_HANDLE )
		CloseHandle(g_hTimeout[client]);
	g_hTimeout[client] = CreateTimer(g_fCvarPushTime, tmrTimeout, client);
}

public Action:tmrTrace(Handle:timer)
{
	new bool:destroy = true;
	static bool:bSwitch;
	bSwitch = !bSwitch;

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidEntRef(g_iPlayerData[i][INDEX_PART]) )
		{
			TraceAttack(i, bSwitch, 0, false);
			destroy = false;
		}
	}

	if( destroy )
	{
		g_hTimerTrace = INVALID_HANDLE;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

TraceAttack(client, bool:bHullTrace, iPushEntity, bool:bFirstTrace)
{
	decl Float:vPos[3], Float:vAng[3], Float:vEnd[3];

	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	MoveForward(vPos, vAng, vPos, 50.0);

	new Handle:trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, FilterExcludeSelf, client);
	if( TR_DidHit(trace) )
	{
		TR_GetEndPosition(vEnd, trace);
	}
	else
	{
		CloseHandle(trace);
		return;
	}

	if( bHullTrace )
	{
		CloseHandle(trace);
		decl Float:vMins[3], Float:vMaxs[3];
		vMins = Float: { -15.0, -15.0, -15.0 };
		vMaxs = Float: { 15.0, 15.0, 15.0 };
		trace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_SHOT, FilterExcludeSelf, client);
	
		if( !TR_DidHit(trace) )
		{
			CloseHandle(trace);
			return;
		}
	}

	TR_GetEndPosition(vEnd, trace);
	if( GetVectorDistance(vPos, vEnd) > g_fCvarRange )
	{
		CloseHandle(trace);
		return;
	}

	new type = g_iPlayerData[client][INDEX_TYPE];
	new entity = TR_GetEntityIndex(trace);
	CloseHandle(trace);

	if( entity > 0 && entity <= MaxClients )
	{
		if( iPushEntity && type == TYPE_BLASTPUSHBACK )
			PushEntity(client, vPos, vEnd);

		if( bFirstTrace && g_iCvarVomit )
		{
			new vomit;
			if( type == 3 ) vomit = 1;
			else vomit = type;

			if( (g_iCvarVomit == 7 || g_iCvarVomit & vomit) )
			{
				SDKCall(g_hSdkVomit, entity);
			}
		}

		if( g_iCvarFriend == 0 )
		{
			if( GetClientTeam(entity) == 2 )
				return;
		}
		else if( g_iCvarFriend == 2 && type != TYPE_BLASTPUSHBACK )
			return;

		if( type == TYPE_EXTINGUISHER || type == TYPE_FREEZERSPRAY )
			ExtinguishEntity(entity);

		HurtEntity(entity, client);
	}
	else
	{
		decl String:classname[16];
		GetEdictClassname(entity, classname, sizeof(classname));

		if( type == TYPE_FLAMETHROWER && strcmp(classname, "prop_physics") == 0 )
		{
			SetEntPropEnt(entity, Prop_Data, "m_hLastAttacker", client);
			AcceptEntityInput(entity, "Ignite", client, client);
		}
		else if( type == TYPE_FLAMETHROWER && strcmp(classname, "weapon_gascan") == 0 )
		{
			SetVariantString("OnIgnite !self:Break:!activator:2:1");
			AcceptEntityInput(entity, "AddOutput", client, client);
			AcceptEntityInput(entity, "Ignite", client, client);
		}
		else if( strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0 )
		{
			HurtEntity(entity, client);

			if( iPushEntity && type == TYPE_BLASTPUSHBACK )
				PushEntity(client, vPos, vEnd);

			if( g_bLeft4Dead2 &&
				( (g_iCvarCombo && type == TYPE_FREEZERSPRAY && g_iCvarType & ENUM_FREEZERSPRAY) || (!g_iCvarCombo && type == TYPE_FREEZERSPRAY) ) &&
				GetEntProp(entity, Prop_Data, "m_iHealth") > 0 && GetEntProp(entity, Prop_Send, "m_glowColorOverride") == 0 )
			{
				SetEntPropFloat(entity, Prop_Data, "m_flFrozen", 0.3);
				SetEntProp(entity, Prop_Send, "m_nGlowRange", 350);
				SetEntProp(entity, Prop_Send, "m_iGlowType", 2);
				SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlowS);
				AcceptEntityInput(entity, "StartGlowing");

				SetVariantString("OnKilled !self:StopGlowing::0:1");
				AcceptEntityInput(entity, "AddOutput");
			}
		}
	}
}

HurtEntity(target, client)
{
	decl String:sTemp[16];

	new entity = CreateEntityByName("point_hurt");
	Format(sTemp, sizeof(sTemp), "ext%d%d", EntIndexToEntRef(entity), client);
	DispatchKeyValue(target, "targetname", sTemp);
	DispatchKeyValue(entity, "DamageTarget", sTemp);
	IntToString(g_iCvarDamage, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "Damage", sTemp);
	if( g_iPlayerData[client][INDEX_TYPE] == TYPE_FLAMETHROWER )
		DispatchKeyValue(entity, "DamageType", "8");
	else
		DispatchKeyValue(entity, "DamageType", "0");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Hurt", client > 0 ? client : -1);
	RemoveEdict(entity);
}

PushEntity(client, Float:vAng[3], Float:vPos[3])
{
	new entity = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchSpawn(entity);
	SetEntityModel(entity, MODEL_BOUNDING);
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	new Float:vMins[3] = { -50.0, -50.0, -50.0 }, Float:vMaxs[3] = { 50.0, 50.0, 50.0 };
	SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);

	SetEntProp(entity, Prop_Data, "m_iHammerID", client);
	HookSingleEntityOutput(entity, "OnStartTouch", OnTouching);

	SetVariantString("OnUser1 !self:Kill::0.01:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
}

public OnTouching(const String:output[], caller, activator, Float:delay)
{
	new client = GetEntProp(caller, Prop_Data, "m_iHammerID", client);
	if( activator == client )
		return;

	decl Float:vPos[3], Float:vAng[3];
	GetEntPropVector(caller, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(caller, Prop_Data, "m_angRotation", vAng);

	MakeVectorFromPoints(vAng, vPos, vAng);
	NormalizeVector(vAng, vAng);
	ScaleVector(vAng, float(g_iCvarPush));
	vAng[2] = 300.0 + (g_iCvarPush / 10);

	TeleportEntity(activator, NULL_VECTOR, NULL_VECTOR, vAng);
}



// ====================================================================================================
//					PRETHINK - EXTINGUISHER SHOOT, BLOCK SHOOTING
// ====================================================================================================
public OnPreThink(client)
{
	static s_iEquipped[MAXPLAYERS];


	// --------------------------------------------------
	// Is the player holding a gascan, are they trying to refuel a dropped extinguisher?
	// --------------------------------------------------
	if( g_bLeft4Dead2 && IsValidEntRef(g_iRefuel[client][0]) )
	{
		new buttons = GetClientButtons(client);
		if( buttons & IN_ATTACK )
		{
			if( !IsValidEntRef(g_iRefuel[client][1]) )
			{
				new aim = GetClientAimTarget(client, false);
				if( aim != -1 )
				{
					new ref = EntIndexToEntRef(aim);

					for( new i = 0; i < MAX_ALLOWED; i++ )
					{
						if( g_iDropped[i][0] == ref && g_iDropped[i][2] != -12345 ) // Pointing at extinguisher and not broken.
						{
							buttons &= ~IN_ATTACK;
							SetEntProp(client, Prop_Data, "m_nButtons", buttons);

							new entity = CreateEntityByName("point_prop_use_target");
							DispatchKeyValue(entity, "nozzle", "gas_nozzle");
							DispatchSpawn(entity);

							decl Float:vPos[3];
							GetEntPropVector(ref, Prop_Data, "m_vecOrigin", vPos);
							TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

							new Float:vMins[3] = {-15.0, -15.0, -25.0}, Float:vMaxs[3] = {15.0, 15.0, 25.0};
							SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
							SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

							g_iRefuel[client][1] = EntIndexToEntRef(entity);
							g_iRefuel[client][2] = i+1;

							break;
						}
					}
				}
			}
		}
		else
		{
			new can = g_iRefuel[client][1];
			if( IsValidEntRef(can) )
				AcceptEntityInput(can, "Kill");
			g_iRefuel[client][1] = 0;
			g_iRefuel[client][2] = 0;
		}

		return;
	}



	// --------------------------------------------------
	// Does the player have a valid extinguisher attached?
	// --------------------------------------------------
	if( IsValidEntRef(g_iPlayerData[client][INDEX_PROP]) )
	{
		new iValidWeapon;
		new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new mounted = GetEntProp(client, Prop_Send, "m_usingMountedWeapon");
		if( mounted != 0 )
			iValidWeapon = -2;
		else
			iValidWeapon = HasWeapon(client, iWeapon, true);


		// --------------------------------------------------
		// Not holding the valid weapon to use for extinguishers
		// --------------------------------------------------
		if( iValidWeapon != iWeapon )
		{
			// --------------------------------------------------
			// Ext in hand? Then kill effects and move ext to their back.
			// --------------------------------------------------
			if( s_iEquipped[client] )
			{
				s_iEquipped[client] = 0;
				KillAttachments(client, false);
				MoveExtinguisher(client, false);
			}


			// --------------------------------------------------
			// Check enabled? Then drop the weapon.
			// --------------------------------------------------
			if( g_iCvarCheck && (iValidWeapon == 0 || iValidWeapon == 1) )
			{
				DropExtinguisher(client);

				if( g_iCvarHint )
				{
					SetGlobalTransTarget(client);

					decl String:sTemp[256], String:sWeapon[64];
					Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", client, "Ext_Blocked", client);
					Format(sWeapon, sizeof(sWeapon), "%T", "Ext_WeaponName", LANG_SERVER);
					ReplaceStringEx(sTemp, sizeof(sTemp), "<WEAPON>", sWeapon);
					CPrintToChat(client, sTemp);
				}
			}


			// --------------------------------------------------
			// If they are holding a melee weapon, move the extinguisher to the primary slot
			// --------------------------------------------------
			if( iValidWeapon == 1 && g_iGunSlot[client] == 1 )
				g_iGunSlot[client] = 0;
			return;
		}


		// --------------------------------------------------
		// Not holding the ext? Then move to hand
		// --------------------------------------------------
		if( !s_iEquipped[client] )
		{
			MoveExtinguisher(client, true);
			s_iEquipped[client] = 1;

			// Timeout before use
			if( g_hTimeout[client] != INVALID_HANDLE )
				CloseHandle(g_hTimeout[client]);
			g_hTimeout[client] = CreateTimer(0.4, tmrTimeout, client);
		}


		// --------------------------------------------------
		// They are holding the valid weapon and extinguisher
		// --------------------------------------------------

		// Forces player to raise weapon
		SetEntProp(client, Prop_Send, "m_isCalm", 0);


		// --------------------------------------------------
		// CHECK CLIENT BUTTONS, SET PRIMARY WEAPON ATTACK TO NOT SHOOT
		// --------------------------------------------------
		new buttons = GetClientButtons(client);
		SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 10.0);


		// --------------------------------------------------
		// ---------- RELOAD : DROP WEAPON
		// --------------------------------------------------
		if( buttons & IN_RELOAD )
		{
			DropExtinguisher(client);
		}


		// --------------------------------------------------
		// ---------- ATTACK : SHOOT!
		// --------------------------------------------------
		else if( (buttons & IN_ATTACK || buttons & IN_ZOOM) && g_iPlayerData[client][INDEX_BLOCK] == 0 && g_hTimeout[client] == INVALID_HANDLE )
		{
			new type;

			if( g_iCvarCombo ) // Combo? Make primary attack a flamethrower, secondary attack the spray and zoom the blast
			{
				if( g_iCvarType & ENUM_FLAMETHROWER && buttons & IN_ATTACK )
					type = TYPE_FLAMETHROWER;
				else if( g_iCvarType & ENUM_BLASTPUSHBACK && buttons & IN_SPEED && buttons & IN_ZOOM )
					type = TYPE_BLASTPUSHBACK;
				else if( (g_iCvarType & ENUM_FREEZERSPRAY || g_iCvarType & ENUM_EXTINGUISHER ) )
					type = TYPE_FREEZERSPRAY;

				g_iPlayerData[client][INDEX_TYPE] = type;
			}
			else
			{
				type = g_iPlayerData[client][INDEX_TYPE];
			}

			new fuel = g_iPlayerData[client][INDEX_FUEL];


			// --------------------------------------------------
			// Fuel is empty... kill particles and show hint. Set timeout so this doesnt trigger again... bad method but meh.
			// --------------------------------------------------
			if( g_iCvarFuel && fuel <= 0 )
			{
				if( g_iCvarRemove > 1 )
					KillAttachments(client, true);
				else
					KillAttachments(client, false);

				g_hTimeout[client] = CreateTimer(10.0, tmrTimeout, client);

				if( g_iCvarHint )
				{
					if( g_iCvarCombo || type == TYPE_EXTINGUISHER )
						PrintHintText(client, "%t", "Ext_EmptyExtinguisher");
					else if( type == TYPE_FLAMETHROWER )
						PrintHintText(client, "%t", "Ext_EmptyFlamethrower");
					else if( type == TYPE_FREEZERSPRAY )
						PrintHintText(client, "%t", "Ext_EmptyFreezerspray");
					else
						PrintHintText(client, "%t", "Ext_EmptyBlastpushback");

					if( g_bLeft4Dead2 == true )
					{
						if( g_iCvarCombo || type == TYPE_EXTINGUISHER )
							CPrintToChat(client, "%t%t", "Ext_ChatTagExtinguisher", "Ext_Refuel");
						else if( type == TYPE_FLAMETHROWER )
							CPrintToChat(client, "%t%t", "Ext_ChatTagFlamethrower", "Ext_Refuel");
						else if( type == TYPE_FREEZERSPRAY )
							CPrintToChat(client, "%t%t", "Ext_ChatTagFreezerspray", "Ext_Refuel");
						else
							CPrintToChat(client, "%t%t", "Ext_ChatTagBlastpushback", "Ext_Refuel");
					}
				}
			}


			// --------------------------------------------------
			// Still has fuel, create particles, update hint
			// --------------------------------------------------
			else
			{
				new iUpdateFuel;

				// Not shooting? No particles
				if( !IsValidEntRef(g_iPlayerData[client][INDEX_PART]) )
				{
					if( type == TYPE_BLASTPUSHBACK )
					{
						TraceAttack(client, true, g_iCvarPush, true);

						if( g_hTimepre[client] != INVALID_HANDLE )
							CloseHandle(g_hTimepre[client]);
						g_hTimepre[client] = CreateTimer(0.5, tmrTimepre, client);

						// FUEL
						if( g_iCvarPushFuel )
						{
							g_iPlayerData[client][INDEX_FUEL] -= g_iCvarPushFuel;
							iUpdateFuel = 1;
						}
					}
					else
					{
						TraceAttack(client, true, 0, true);

						if( g_hTimerTrace == INVALID_HANDLE )
							g_hTimerTrace = CreateTimer(g_fCvarFreq, tmrTrace, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}

					CreateEffects(client);
				}


				// FUEL
				if( g_iCvarFuel )
				{
					if( type != TYPE_BLASTPUSHBACK )
						g_iPlayerData[client][INDEX_FUEL]--;
					else
					{
						if( iUpdateFuel == 0 )
							return;
						else
							iUpdateFuel = 0;
					}
				}


				// FUEL HINT
				if( g_iCvarFuel && g_iCvarHint )
				{
					new percent = fuel * 10 / g_iCvarFuel;
					if( percent != (fuel -= type == TYPE_BLASTPUSHBACK ? g_iCvarPushFuel : 1) * 10 / g_iCvarFuel )
					{
						new String:sTemp[12];
						// sTemp[0] = '\x0';
						for( new i = 0; i < 10; i++ )
						{
							if( i < percent )
								StrCat(sTemp, sizeof(sTemp), "|");
							else
								StrCat(sTemp, sizeof(sTemp), " ");
						}

						if( g_iCvarCombo || type == TYPE_EXTINGUISHER )
							PrintHintText(client, "%t [%s]", "Ext_FuelExtinguisher", sTemp);
						else if( type == TYPE_FLAMETHROWER )
							PrintHintText(client, "%t [%s]", "Ext_FuelFlamethrower", sTemp);
						else if( type == TYPE_FREEZERSPRAY )
							PrintHintText(client, "%t [%s]", "Ext_FuelFreezerspray", sTemp);
						else
							PrintHintText(client, "%t [%s]", "Ext_FuelBlastpushback", sTemp);
					}
				}
			}
		}


		// --------------------------------------------------
		// NOT SHOOTING EXT, DELETE THE PARTICLES IF THEY ARE VALID
		// --------------------------------------------------
		else if( IsValidEntRef(g_iPlayerData[client][INDEX_PART]) )
		{
			// No longer firing weapon, kill particles etc.
			KillAttachments(client, false);

			// Timeout, stop shooting
			if( g_iPlayerData[client][INDEX_TYPE] == TYPE_BLASTPUSHBACK )
			{
				if( g_hTimepre[client] != INVALID_HANDLE )
				{
					CloseHandle(g_hTimepre[client]);
					g_hTimepre[client] = INVALID_HANDLE;
				}

				if( g_hTimeout[client] != INVALID_HANDLE )
					CloseHandle(g_hTimeout[client]);
				g_hTimeout[client] = CreateTimer(g_fCvarPushTime, tmrTimeout, client);
			}
			else
			{
				if( g_hTimeout[client] != INVALID_HANDLE )
					CloseHandle(g_hTimeout[client]);
				g_hTimeout[client] = CreateTimer(g_fCvarTimeout, tmrTimeout, client);
			}
		}
	}
	else
	{
		if( g_bLeft4Dead2 && IsValidEntRef(g_iRefuel[client][0]) == false )
		{
			g_iHooked[client] = 0;
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
		}
	}
}



// ====================================================================================================
//					EFFECTS - SPRAY or (FIRE and LIGHT) and DAMAGE.
// ====================================================================================================
CreateEffects(client)
{
	new Float:vPos[3], Float:vAng[3];

	new iType = g_iPlayerData[client][INDEX_TYPE];
	new particle = CreateEntityByName("info_particle_system");
	if( iType == TYPE_FLAMETHROWER )
		if( g_iCvarFlame == 0 || g_iCvarFlame == 2 )
			DispatchKeyValue(particle, "effect_name", PARTICLE_FIRE1);
		else
			DispatchKeyValue(particle, "effect_name", PARTICLE_FIRE2);
	else if( iType == TYPE_BLASTPUSHBACK )
		DispatchKeyValue(particle, "effect_name", PARTICLE_BLAST1);
	else
		DispatchKeyValue(particle, "effect_name", PARTICLE_SPRAY);

	DispatchSpawn(particle);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "Start");
	g_iPlayerData[client][INDEX_PART] = EntIndexToEntRef(particle);

	SetVariantString("!activator");
	AcceptEntityInput(particle, "SetParent", client);

	new bone = GetSurvivorType(client);

	if( bone == 0 )
	{
		SetVariantString(ATTACHMENT_BONE);

		if( iType == TYPE_BLASTPUSHBACK )
		{
			vPos[1] = 5.0;
			vPos[2] = 20.0;
		}
		else if( iType == TYPE_FLAMETHROWER )
		{
			vPos[1] = 7.0;
			vPos[2] = 25.0;

			if( g_iCvarFlame == 0 || g_iCvarFlame == 2 )
			{
				vAng[0] = -90.0;
				vAng[1] = -90.0;
				vAng[2] = -90.0;
			}
		}
		else
		{
			vAng[0] = -90.0;
			vPos[0] = -1.0;
			vPos[1] = 7.0;
			vPos[2] = 18.0;
		}
	}
	else
	{
		SetVariantString(ATTACHMENT_ARM);

		if( iType == TYPE_BLASTPUSHBACK )
		{
			vAng[0] = 90.0;
			vAng[1] = 90.0;
			vPos[0] = -5.0;
			vPos[1] = 45.0;
		}
		else if( iType == TYPE_FLAMETHROWER )
		{
			vAng[1] = 90.0;
			vPos[0] = -5.0;
			vPos[1] = 45.0;
		}
		else
		{
			vAng[1] = 90.0;
			vPos[0] = -3.0;
			vPos[2] = -3.0;
			vPos[1] = 35.0;
		}
	}

	AcceptEntityInput(particle, "SetParentAttachment");
	TeleportEntity(particle, vPos, vAng, NULL_VECTOR);


	// ====================================================================================================
	// SOUND
	// ====================================================================================================
	if( iType == TYPE_FLAMETHROWER )
		if( g_bLeft4Dead2 )
			EmitSoundToAll(SOUND_FIRE_L4D2, particle, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		else
			EmitSoundToAll(SOUND_FIRE_L4D1, particle, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	else if( iType == TYPE_BLASTPUSHBACK )
		EmitSoundToAll(SOUND_BLAST, particle, SNDCHAN_AUTO, SNDLEVEL_TRAIN, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	else
		EmitSoundToAll(SOUND_SPRAY, particle, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);


	// ====================================================================================================
	// BLAST
	// ====================================================================================================
	new entity;
	if( g_bLeft4Dead2 && iType == TYPE_BLASTPUSHBACK )
	{
		entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "effect_name", PARTICLE_BLAST2);

		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "Start");

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);

		if( bone == 0 ) SetVariantString(ATTACHMENT_BONE);
		else SetVariantString(ATTACHMENT_ARM);
		AcceptEntityInput(entity, "SetParentAttachment");

		vPos[2] = 100.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

		SetVariantString("OnUser1 !self:Kill::1.0:-1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}


	// ====================================================================================================
	// LIGHT_DYNAMIC
	// ====================================================================================================
	if( iType == TYPE_FLAMETHROWER )
	{
		if( (g_iCvarFlame == 2 || g_iCvarFlame == 3) )
		{
			entity = CreateEntityByName("light_dynamic");
			DispatchKeyValue(entity, "_light", "255 30 0 255");
			DispatchKeyValue(entity, "brightness", "1");
			DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
			DispatchKeyValueFloat(entity, "distance", 25.0);
			DispatchKeyValue(entity, "style", "6");
			DispatchSpawn(entity);
			AcceptEntityInput(entity, "TurnOn");
			g_iPlayerData[client][INDEX_LIGHT] = EntIndexToEntRef(entity);

			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", client);

			if( bone == 0 ) SetVariantString(ATTACHMENT_BONE);
			else SetVariantString(ATTACHMENT_ARM);
			AcceptEntityInput(entity, "SetParentAttachment");

			if( g_iCvarFlame == 3 )
			{
				SetVariantString("OnUser1 !self:Distance:50:0.1:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Distance:80:0.2:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Distance:125:0.3:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Distance:180:0.4:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");
			}
			else
			{
				SetVariantString("OnUser1 !self:Distance:100:0.1:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Distance:180:0.2:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");
			}

			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}



// ====================================================================================================
//					CREATE BUTTON ON ALL EXTINGUISHERS
// ====================================================================================================
public OnEntityCreated(entity, const String:classname[])
{
	if( g_bCvarAllow && g_iLoadStatus )
	{
		if( g_iCvarType & ENUM_EXTINGUISHER )
		{
			if( (g_iCvarSpray & (1<<0) && strcmp(classname, "inferno") == 0) || g_bLeft4Dead2 &&
				((g_iCvarSpray & (1<<1) && (strcmp(classname, "fire_cracker_blast") == 0)) ||
				(g_iCvarSpray & (1<<2) && strcmp(classname, "insect_swarm") == 0)) )
				SDKHook(entity, SDKHook_Spawn, OnSpawnInferno);
		}
	}
}

public OnSpawnInferno(entity)
{
	if( !(g_iCvarType & ENUM_EXTINGUISHER) )
		return;

	new index = -1;
	for( new i = 0; i < MAX_ALLOWED; i++ )
	{
		if( !IsValidEntRef(g_iInferno[i][0]) )
		{
			index = i;
			break;
		}
	}

	if( index != -1 )
	{
		new trigger = CreateEntityByName("trigger_multiple");
		DispatchKeyValue(trigger, "StartDisabled", "1");
		DispatchKeyValue(trigger, "spawnflags", "1");
		DispatchKeyValue(trigger, "entireteam", "0");
		DispatchKeyValue(trigger, "allowincap", "0");
		DispatchKeyValue(trigger, "allowghost", "0");

		DispatchSpawn(trigger);
		SetEntityModel(trigger, MODEL_BOUNDING);

		new Float:vMins[3] = {-150.0, -150.0, 0.0}, Float:vMaxs[3] = {150.0, 150.0, 50.0};
		SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

		decl Float:vPos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
		TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("OnUser1 !self:Enable::0.1:-1");
		AcceptEntityInput(trigger, "AddOutput");
		AcceptEntityInput(trigger, "FireUser1");

		g_iInferno[index][0] = EntIndexToEntRef(trigger);
		g_iInferno[index][1] = EntIndexToEntRef(entity);
		g_iInferno[index][2] = 0;

		HookSingleEntityOutput(trigger, "OnTrigger", OnTouchInferno);
	}
}

public OnTouchInferno(const String:output[], entity, client, Float:delay)
{
	if( client > 0 && client <= MaxClients )
	{
		new type = g_iPlayerData[client][INDEX_TYPE];

		// Player is shooting particles, has an extinguisher or combo/extinguisher
		if( (type == TYPE_EXTINGUISHER || (g_iCvarCombo && type == TYPE_FREEZERSPRAY)) && IsValidEntRef(g_iPlayerData[client][INDEX_PART]) )
		{
			entity = EntIndexToEntRef(entity);

			for( new i = 0; i < MAX_ALLOWED; i++ )
			{
				if( g_iInferno[i][0] == entity )
				{
					if( g_iInferno[i][2]++ >= g_iCvarTime )
					{
						if( IsValidEntRef(g_iInferno[i][1]) )
							AcceptEntityInput(g_iInferno[i][1], "Kill");
						AcceptEntityInput(entity, "Kill");

						g_iInferno[i][0] = 0;
						g_iInferno[i][1] = 0;
						g_iInferno[i][2] = 0;
						return;
					}
				}
			}
		}
	}
}



// ====================================================================================================
//					CREATE BUTTON
// ====================================================================================================
CreateButton(entity, arraytype, iType = 0)
{
	new index;
	if( iType == 0 ||
		iType == 1 && !(g_iCvarType & ENUM_EXTINGUISHER) ||
		iType == 2 && !(g_iCvarType & ENUM_FLAMETHROWER) ||
		iType == 3 && !(g_iCvarType & ENUM_FREEZERSPRAY) ||
		iType == 4 && !(g_iCvarType & ENUM_BLASTPUSHBACK) )
		iType = GetRandomType(g_iCvarType);

	if( arraytype == ENUM_WALLEXT )
	{
		decl String:sModelName[48];
		GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof sModelName);

		if( strcmp(sModelName, MODEL_EXTINGUISHER, false) != 0 )
			return false;

		for( new i = 0; i < MAX_ALLOWED; i++ )
		{
			if( !IsValidEntRef(g_iWallExt[i][1]) )	// Button
			{
				g_iSpawnCount++;
				index = i;
				break;
			}
			else if( i == MAX_ALLOWED -1 )
			{
				ThrowError("No free index to store wall button");
			}
		}
		g_iWallExt[index][0] = EntIndexToEntRef(entity);
	}
	else if( arraytype == ENUM_DROPPED )
	{
		for( new i = 0; i < MAX_ALLOWED; i++ )
		{
			if( !IsValidEntRef(g_iDropped[i][1]) )
			{
				index = i;
				break;
			}
			else if( i == MAX_ALLOWED -1 )
				ThrowError("No free index to store drop button");
		}
		g_iDropped[index][0] = EntIndexToEntRef(entity);
	}
	else
	{
		for( new i = 0; i < MAX_ALLOWED; i++ )
		{
			if( !IsValidEntRef(g_iSpawned[i][1]) )
			{
				index = i;
				break;
			}
			else if( i == MAX_ALLOWED -1 )
				ThrowError("No free index to store drop button");
		}
		g_iSpawned[index][0] = EntIndexToEntRef(entity);
	}


	decl String:sTemp[16];
	new button;
	if( g_fCvarTimed == 0.0 )
		button = CreateEntityByName("func_button");
	else
		button = CreateEntityByName("func_button_timed");

	if( arraytype == ENUM_WALLEXT )
		g_iWallExt[index][1] = EntIndexToEntRef(button);
	else if( arraytype == ENUM_DROPPED )
		g_iDropped[index][1] = EntIndexToEntRef(button);
	else
		g_iSpawned[index][1] = EntIndexToEntRef(button);

	Format(sTemp, sizeof(sTemp), "ft%d", EntIndexToEntRef(button));
	DispatchKeyValue(entity, "targetname", sTemp);
	DispatchKeyValue(button, "glow", sTemp);
	DispatchKeyValue(button, "rendermode", "3");

	if( g_bLeft4Dead2 && g_iCvarGlowRan )
	{
		SetEntProp(entity, Prop_Send, "m_nGlowRange", g_iCvarGlowRan);
		SetEntProp(entity, Prop_Send, "m_iGlowType", 3);

		if( g_iCvarCombo )
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarCombo);
		else if( iType == TYPE_EXTINGUISHER )
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlowE);
		else if( iType == TYPE_FLAMETHROWER )
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlowF);
		else if( iType == TYPE_FREEZERSPRAY )
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlowS);
		else
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarGlowB);

		ChangeEdictState(entity, g_iOffsetGlow);
		AcceptEntityInput(entity, "StartGlowing");
	}

	if( arraytype == ENUM_WALLEXT )
		g_iWallExt[index][2] = iType;
	else if( arraytype == ENUM_DROPPED )
		g_iDropped[index][3] = iType;
	else
		g_iSpawned[index][3] = iType;

	if( g_fCvarTimed == 0.0 )
	{
		DispatchKeyValue(button, "spawnflags", "1025");
		DispatchKeyValue(button, "wait", "1");
	}
	else
	{
		DispatchKeyValue(button, "spawnflags", "0");
		DispatchKeyValue(button, "auto_disable", "1");
		FloatToString(g_fCvarTimed, sTemp, sizeof(sTemp));
		DispatchKeyValue(button, "use_time", sTemp);
	}
	DispatchSpawn(button);
	AcceptEntityInput(button, "Enable");
	ActivateEntity(button);

	SetVariantString("!activator");
	AcceptEntityInput(button, "SetParent", entity);
	TeleportEntity(button, Float:{0.0, 0.0, 5.0}, NULL_VECTOR, NULL_VECTOR);

	SetEntProp(button, Prop_Send, "m_nSolidType", 0, 1);
	SetEntProp(button, Prop_Send, "m_usSolidFlags", 4, 2);

	new Float:vMins[3] = {-5.0, -5.0, -5.0}, Float:vMaxs[3] = {5.0, 5.0, 5.0};
	SetEntPropVector(button, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(button, Prop_Send, "m_vecMaxs", vMaxs);

	if( g_bLeft4Dead2 )
	{
		SetEntProp(button, Prop_Data, "m_CollisionGroup", 1);
		SetEntProp(button, Prop_Send, "m_CollisionGroup", 1);
	}

	if( g_iCvarBreak == 0 )
		SetEntProp(entity, Prop_Data, "m_iMinHealthDmg", 99999);
	else if( g_iCvarBreak > 1 )
		HookSingleEntityOutput(entity, "OnHealthChanged", OnHealthChanged);

	if( g_fCvarTimed == 0 )
		HookSingleEntityOutput(button, "OnPressed", OnPressed);
	else
	{
		SetVariantString("OnTimeUp !self:Enable::1:-1");
		AcceptEntityInput(button, "AddOutput");
		HookSingleEntityOutput(button, "OnTimeUp", OnPressed);
	}

	return true;
}



// ====================================================================================================
//					BUTTON PRESS - GIVE
// ====================================================================================================
public OnPressed(const String:output[], caller, activator, Float:delay)
{
	if( !g_bCvarAllow )
		return;

	if( IsValidEntRef(g_iPlayerData[activator][INDEX_PROP]) )
	{
		if( g_iCvarHint )
		{
			if( strcmp(g_sCvarWeapon, "") == 0 )
				CPrintToChat(activator, "%t%t", "Ext_ChatTagExtinguisher", "Ext_EquipHasCombo");
			else
			{
				SetGlobalTransTarget(activator);

				decl String:sTemp[256], String:sWeapon[64];
				Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", activator, "Ext_EquipHasCheck", activator);
				Format(sWeapon, sizeof(sWeapon), "%T", "Ext_WeaponName", LANG_SERVER);
				ReplaceStringEx(sTemp, sizeof(sTemp), "<WEAPON>", sWeapon);
				CPrintToChat(activator, sTemp);
			}
		}
		return;
	}

	if( g_iCvarMax && ExtinguisherCount(activator) == false )
		return;

	new iWeapon = GetEntPropEnt(activator, Prop_Send, "m_hActiveWeapon");
	new iValidWeapon = HasWeapon(activator, iWeapon);

	if( g_iCvarCheck && iValidWeapon == 0 )
	{
		if( g_iCvarHint )
		{
			SetGlobalTransTarget(activator);

			decl String:sTemp[256], String:sWeapon[64];
			Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", activator, "Ext_Blocked", activator);
			Format(sWeapon, sizeof(sWeapon), "%T", "Ext_WeaponName", LANG_SERVER);
			ReplaceStringEx(sTemp, sizeof(sTemp), "<WEAPON>", sWeapon);
			CPrintToChat(activator, sTemp);
		}
		return;
	}

	for( new i = 0; i < MAX_ALLOWED; i++ )
	{
		if( g_iDropped[i][1] && EntRefToEntIndex(g_iDropped[i][1]) == caller ) // Dropped Button
		{
			g_iPlayerData[activator][INDEX_FUEL] = g_iDropped[i][2];
			g_iPlayerData[activator][INDEX_TYPE] = g_iDropped[i][3];
			g_iDropped[i][1] = 0;
			g_iDropped[i][2] = 0;
			if( IsValidEntRef(g_iDropped[i][0]) )
			{
				AcceptEntityInput(g_iDropped[i][0], "Kill");
				g_iDropped[i][0] = 0;
				break;
			}
		}
		else if( g_iSpawned[i][1] && EntRefToEntIndex(g_iSpawned[i][1]) == caller ) // Spawned Button
		{
			g_iPlayerData[activator][INDEX_FUEL] = g_iCvarFuel;
			g_iPlayerData[activator][INDEX_TYPE] = g_iSpawned[i][3];
			if( IsValidEntRef(g_iSpawned[i][0]) )
			{
				AcceptEntityInput(g_iSpawned[i][0], "Kill");
				g_iSpawned[i][0] = 0;
				g_iSpawned[i][1] = 0;
				break;
			}
		}
		else if( g_iWallExt[i][1] && EntRefToEntIndex(g_iWallExt[i][1]) == caller ) // Wall Button
		{
			g_iPlayerData[activator][INDEX_FUEL] = g_iCvarFuel;
			g_iPlayerData[activator][INDEX_TYPE] = g_iWallExt[i][2];
			if( IsValidEntRef(g_iWallExt[i][0]) )
			{
				AcceptEntityInput(g_iWallExt[i][0], "Kill");
				g_iWallExt[i][0] = 0;
				g_iWallExt[i][1] = 0;
				break;
			}
		}
		else if( i == MAX_ALLOWED -1 )
		{
			g_iPlayerData[activator][INDEX_FUEL] = g_iCvarFuel;
			g_iPlayerData[activator][INDEX_TYPE] = GetRandomType(g_iCvarType);
			LogError("Cannot find button index..."); // Should never happen
		}
	}

	AcceptEntityInput(caller, "Kill"); // Delete button
	GiveExtinguisher(activator);
}



// ====================================================================================================
//					ON HEALTH CHANGED
// ====================================================================================================
public OnHealthChanged(const String:output[], caller, activator, Float:delay)
{
	if( g_iCvarBreak == 3 && activator > 0 && activator <= MaxClients && GetClientTeam(activator) == 3 )
		return;

	UnhookSingleEntityOutput(caller, "OnHealthChanged", OnHealthChanged);

	new iArray, iType, iButton;

	for( new i = 0; i < MAX_ALLOWED; i++ )
	{
		if( g_iWallExt[i][0] && EntRefToEntIndex(g_iWallExt[i][0]) == caller )
		{
			iButton = g_iWallExt[i][1];
			if( IsValidEntRef(iButton) )
			{
				if( g_iCvarRemove == 1 || g_iCvarRemove == 3 )
				{
					AcceptEntityInput(iButton, "Kill");
					g_iWallExt[i][0] = 0;
					g_iWallExt[i][1] = 0;
				}
				else
				{
					AcceptEntityInput(iButton, "Disable");
				}

				iType = g_iWallExt[i][2];
				iArray = 1;
				break;
			}
		}

		if( g_iDropped[i][0] && EntRefToEntIndex(g_iDropped[i][0]) == caller )
		{
			iButton = g_iDropped[i][1];
			if( IsValidEntRef(iButton) )
			{
				if( g_iCvarRemove == 1 || g_iCvarRemove == 3 )
				{
					AcceptEntityInput(iButton, "Kill");
					g_iDropped[i][0] = 0;
					g_iDropped[i][1] = 0;
				}
				else
				{
					AcceptEntityInput(iButton, "Lock");
					AcceptEntityInput(iButton, "Disable");
				}

				g_iDropped[i][2] = -12345;
				iType = g_iDropped[i][3];
				iArray = 2;
				break;
			}
		}

		if( g_iSpawned[i][0] && EntRefToEntIndex(g_iSpawned[i][0]) == caller )
		{
			iButton = g_iSpawned[i][1];
			if( IsValidEntRef(iButton) )
			{
				if( g_iCvarRemove == 1 || g_iCvarRemove == 3 )
				{
					AcceptEntityInput(iButton, "Kill");
					g_iSpawned[i][0] = 0;
					g_iSpawned[i][1] = 0;
				}
				else
				{
					AcceptEntityInput(iButton, "Disable");
				}

				iType = g_iSpawned[i][3];
				iArray = 3;
				break;
			}
		}
	}

	if( iArray == 0 )
	{
		LogError("Cannot find broken extinguisher..."); // Should never happen
		return;
	}

	new client = GetEntPropEnt(iButton, Prop_Data, "m_hActivator");
	if( client != -1 )
	{
		SetEntPropEnt(iButton, Prop_Data, "m_hActivator", -1);
		if( client > 0 && client <= MaxClients && IsClientInGame(client) )
			SetEntPropEnt(client, Prop_Data, "m_hUseEntity", -1);
	}

	if( iType == TYPE_FLAMETHROWER || GetRandomInt(0, 2) == 1 )
	{
		new entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "effect_name", PARTICLE_RAND);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "Start");

		decl Float:vPos[3], Float:vAng[3];
		GetEntPropVector(caller, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(caller, Prop_Data, "m_angRotation", vAng);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", caller);

		SetVariantString("OnUser1 !self:ClearParent::4:1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser1 !self:Kill::4.1:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}

	if( iArray != 1 ) // Wall ext
	{
		new entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "effect_name", PARTICLE_SPRAY);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "Start");

		decl Float:vPos[3], Float:vAng[3];
		GetEntPropVector(caller, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(caller, Prop_Data, "m_angRotation", vAng);
		decl Float:vFwd[3], Float:vRight[3], Float:vUp[3];
		GetAngleVectors(vAng, vFwd, vRight, vUp);
		ScaleVector(vFwd, 2.0);
		ScaleVector(vUp, 22.0);
		vPos[0] += vFwd[0] + vRight[0] + vUp[0];
		vPos[1] += vFwd[1] + vRight[1] + vUp[1];
		vPos[2] += vFwd[2] + vRight[2] + vUp[2];
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", caller);

		SetVariantString("OnUser1 !self:ClearParent::5:1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser1 !self:Kill::5.1:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		EmitSoundToAll(SOUND_SPRAY, caller, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 5.0);
		CreateTimer(5.0, tmrStopSound, EntIndexToEntRef(caller));
	}

	AcceptEntityInput(caller, "StopGlowing");

	if( g_iCvarRemove == 1 || g_iCvarRemove == 3 )
	{
		SetVariantString("OnUser1 !self:Kill::6:1");
		AcceptEntityInput(caller, "AddOutput");
		AcceptEntityInput(caller, "FireUser1");
	}

	if( (g_iCvarHint == 1 || g_iCvarHint == 3 ) && activator > 0 && activator <= MaxClients )
	{
		decl String:sTemp[256], String:sName[MAX_NAME_LENGTH];
		GetClientName(activator, sName, MAX_NAME_LENGTH);

		for( new x = 1; x <= MaxClients; x++ )
		{
			if( IsClientInGame(x) )
			{
				if( g_iCvarCombo || iType == TYPE_EXTINGUISHER )
					Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", x, "Ext_Broken", x);
				else if( iType == TYPE_FLAMETHROWER )
					Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagFlamethrower", x, "Ext_Broken", x);
				else if( iType == TYPE_FREEZERSPRAY )
					Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagFreezerspray", x, "Ext_Broken", x);
				else
					Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagBlastpushback", x, "Ext_Broken", x);

				ReplaceStringEx(sTemp, sizeof(sTemp), "<NAME>", sName);

				CPrintToChat(x, sTemp);
			}
		}
	}
}

public Action:tmrStopSound(Handle:timer, any:entity)
{
	if( IsValidEntRef(entity) )
		StopSound(entity, SNDCHAN_AUTO, SOUND_SPRAY);
}



// ====================================================================================================
//					MOVE EXTINGUISHER - PARENT TO HAND / BACK
// ====================================================================================================
MoveExtinguisher(client, bool:bWeaponSlot = false)
{
	new entity = g_iPlayerData[client][INDEX_PROP];

	if( IsValidEntRef(entity) )
	{
		new Float:vPos[3], Float:vAng[3];

		AcceptEntityInput(entity, "ClearParent");

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);

		entity = EntRefToEntIndex(entity);

		if( bWeaponSlot )
		{
			if( g_iCvarView == 1 )
				SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);

			new bone = GetSurvivorType(client);
			if( bone == 0 )
			{
				SetVariantString(ATTACHMENT_BONE);
				vAng[2] = 180.0;
				vPos[0] = -5.0;
				vPos[1] = 2.0;
				vPos[2] = 23.0;
			}
			else
			{
				SetVariantString(ATTACHMENT_ARM);
				vAng[2] = 90.0;
				vPos[0] = -5.0;
				vPos[1] = 40.0;
			}
			AcceptEntityInput(entity, "SetParentAttachment");

			if( g_iCvarView != 2 )
				SDKUnhook(entity, SDKHook_SetTransmit, OnTransmit);
		}
		else
		{
			if( g_iCvarView == 1 )
				SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);

			vAng[0] = 260.0;
			vAng[2] = 10.0;
			vPos[0] = 15.0;
			vPos[1] = 2.0;
			vPos[2] = 5.0;
			SetVariantString(ATTACHMENT_PRIMARY);
			AcceptEntityInput(entity, "SetParentAttachment");

			if( g_iCvarView != 2 )
				SDKHook(entity, SDKHook_SetTransmit, OnTransmit);
		}

		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	}
}



// ====================================================================================================
//					DROP EXTINGUISHER
// ====================================================================================================
DropExtinguisher(client)
{
	if( IsValidEntRef(g_iPlayerData[client][INDEX_PROP]) )
	{
		new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new iValidWeapon = HasWeapon(client, iWeapon);
		if( iValidWeapon )
			SetEntPropFloat(iValidWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.2);

		if( g_iCvarView == 1 )
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	
		new index;
		for( new i = 0; i < MAX_ALLOWED; i++ )
		{
			if( !IsValidEntRef(g_iDropped[i][0]) )
			{
				index = i;
				break;
			}
			else if( i == MAX_ALLOWED -1 )
			{
				KillAttachments(client, true);
				ThrowError("No free index for extinguisher model.");
			}
		}

		new entity = CreateEntityByName("prop_physics");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "model", MODEL_EXTINGUISHER);
		DispatchSpawn(entity);

		decl Float:vPos[3], Float:vAng[3];
		GetClientAbsOrigin(client, vPos);
		GetClientAbsAngles(client, vAng);
		MoveForward(vPos, vAng, vPos, 32.0);
		vPos[2] += 2.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 1);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);

		g_iDropped[index][0] = EntIndexToEntRef(entity);
		g_iDropped[index][2] = g_iPlayerData[client][INDEX_FUEL];
		g_iDropped[index][3] = g_iPlayerData[client][INDEX_TYPE];
		g_iPlayerData[client][INDEX_FUEL] = 0;

		CreateButton(entity, ENUM_DROPPED, g_iDropped[index][3]);
		KillAttachments(client, true);
	}
}



// ====================================================================================================
//					GIVE EXTINGUISHER
// ====================================================================================================
GiveExtinguisher(client)
{
	if( g_iCvarMax && ExtinguisherCount(client) == false )
		return;

	new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	new slot = GetPlayerWeaponSlot(client, 1);
	if( iWeapon == slot )
		g_iGunSlot[client] = 1;
	else
		g_iGunSlot[client] = 0;
	new iValidWeapon = HasWeapon(client, iWeapon);

	if( g_iCvarCheck && iValidWeapon == 0 )
	{
		if( g_iCvarHint )
		{
			SetGlobalTransTarget(client);

			decl String:sTemp[256], String:sWeapon[64];
			Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", client, "Ext_Blocked", client);
			Format(sWeapon, sizeof(sWeapon), "%T", "Ext_WeaponName", LANG_SERVER);
			ReplaceStringEx(sTemp, sizeof(sTemp), "<WEAPON>", sWeapon);
			CPrintToChat(client, sTemp);
		}
		return;
	}

	KillAttachments(client, true);

	if( g_iHooked[client] == 0 )
	{
		g_iHooked[client] = 1;
		SDKHook(client, SDKHook_PreThink, OnPreThink);
	}

	new entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_EXTINGUISHER);
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Data, "m_iEFlags", 0);

	g_iPlayerData[client][INDEX_PROP] = EntIndexToEntRef(entity);
	if( g_iCvarView == 2 )
		SDKHook(entity, SDKHook_SetTransmit, OnTransmit);

	// Check if the equipped weapon activates the extinguisher, if so, MoveExt to their hand, else move to their back.
	if( iWeapon != -1 && iWeapon == iValidWeapon )
	{
		SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 10.0);
		MoveExtinguisher(client, true);

		if( g_hTimeout[client] != INVALID_HANDLE )
			CloseHandle(g_hTimeout[client]);
		g_hTimeout[client] = CreateTimer(g_fCvarTimeout, tmrTimeout, client);
	}
	else
		MoveExtinguisher(client, false);

	if( g_iCvarHint )
	{
		SetGlobalTransTarget(client);

		decl String:sTemp[256];
		new type = g_iPlayerData[client][INDEX_TYPE];

		// Display message about using the item
		if( g_iCvarCombo )
			Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", client, "Ext_EquipCombo", client);
		else
		{
			if( type == TYPE_EXTINGUISHER )
				Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagExtinguisher", client, "Ext_EquipUseExtinguisher", client);
			else if( type == TYPE_FLAMETHROWER )
				Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagFlamethrower", client, "Ext_EquipUseFlamethrower", client);
			else if( type == TYPE_FREEZERSPRAY )
				Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagFreezerspray", client, "Ext_EquipUseFreezerspray", client);
			else
				Format(sTemp, sizeof(sTemp), "%T%T", "Ext_ChatTagBlastpushback", client, "Ext_EquipUseBlastpushback", client);
		}

		CPrintToChat(client, sTemp);

		// Display message if fuel empty
		if( g_iCvarFuel && g_iPlayerData[client][INDEX_FUEL] == 0 )
		{
			if( g_iCvarRemove > 1 )
				KillAttachments(client, true);

			if( g_iCvarCombo || type == TYPE_EXTINGUISHER )
				PrintHintText(client, "%t", "Ext_EmptyExtinguisher");
			else if( type == TYPE_FLAMETHROWER )
				PrintHintText(client, "%t", "Ext_EmptyFlamethrower");
			else if( type == TYPE_FREEZERSPRAY )
				PrintHintText(client, "%t", "Ext_EmptyFreezerspray");
			else
				PrintHintText(client, "%t", "Ext_EmptyBlastpushback");
		}
	}
}


bool:ExtinguisherCount(client)
{
	new count;
	for( new i = 0; i < MAX_ALLOWED; i++ )
	{
		if( IsValidEntRef(g_iPlayerData[i][INDEX_PROP]) )
			count++;

		if( count > g_iCvarMax )
		{
			if( g_iCvarHint )
				CPrintToChat(client, "%t%t", "Ext_ChatTagExtinguisher", "Ext_EquipFull");
			return false;
		}
	}

	return true;
}



// ====================================================================================================
//					SET TRANSMIT
// ====================================================================================================
public Action:OnTransmit(entity, client)
{
	if( EntIndexToEntRef(entity) == g_iPlayerData[client][INDEX_PROP] )
		return Plugin_Handled;
	return Plugin_Continue;
}



// ====================================================================================================
//					KILL ATTACHMENTS / ENTS
// ====================================================================================================
KillAttachments(client, bool:all)
{
	if( all )
	{
		if( g_iCvarView == 1 )
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);

		new iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		new iValidWeapon = HasWeapon(client, iWeapon);
		if( iValidWeapon )
			SetEntPropFloat(iValidWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.2);

		if( g_iHooked[client] )
		{
			g_iHooked[client] = 0;
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
		}
	}

	new entity = g_iPlayerData[client][INDEX_PROP];
	if( all && IsValidEntRef(entity ) )
	{
		if( g_iCvarView == 2 )
			SDKUnhook(entity, SDKHook_SetTransmit, OnTransmit);
		AcceptEntityInput(entity, "ClearParent");
		AcceptEntityInput(entity, "kill");
		g_iPlayerData[client][INDEX_PROP] = 0;
	}

	entity = g_iPlayerData[client][INDEX_PART];
	if( IsValidEntRef(entity) )
	{
		AcceptEntityInput(entity, "ClearParent");
		AcceptEntityInput(entity, "kill");
		g_iPlayerData[client][INDEX_PART] = 0;

		StopSound(entity, SNDCHAN_AUTO, SOUND_BLAST);
		StopSound(entity, SNDCHAN_AUTO, SOUND_SPRAY);
		if( g_bLeft4Dead2 )
			StopSound(entity, SNDCHAN_AUTO, SOUND_FIRE_L4D2);
		else
			StopSound(entity, SNDCHAN_AUTO, SOUND_FIRE_L4D1);
	}

	entity = g_iPlayerData[client][INDEX_LIGHT];
	if( IsValidEntRef(entity) )
	{
		AcceptEntityInput(entity, "ClearParent");
		AcceptEntityInput(entity, "kill");
		g_iPlayerData[client][INDEX_LIGHT] = 0;
	}
}

KillEnts()
{
	new entity;

	for( new i = 0; i < MAX_ALLOWED; i++ )
	{
		entity = g_iWallExt[i][0];
		if( IsValidEntRef(entity) )
		{
			StopSound(entity, SNDCHAN_AUTO, SOUND_SPRAY);
			AcceptEntityInput(entity, "StopGlowing");
			g_iWallExt[i][0] = 0;
		}

		entity = g_iWallExt[i][1];
		if( IsValidEntRef(entity) )
		{
			RemoveEdict(entity);
			g_iWallExt[i][1] = 0;
		}

		entity = g_iDropped[i][0];
		if( IsValidEntRef(entity) )
		{
			StopSound(entity, SNDCHAN_AUTO, SOUND_SPRAY);
			RemoveEdict(entity);
			g_iDropped[i][0] = 0;
		}

		entity = g_iDropped[i][1];
		if( IsValidEntRef(entity) )
		{
			RemoveEdict(entity);
			g_iDropped[i][1] = 0;
		}

		entity = g_iSpawned[i][0];
		if( IsValidEntRef(entity) )
		{
			StopSound(entity, SNDCHAN_AUTO, SOUND_SPRAY);
			RemoveEdict(entity);
			g_iSpawned[i][0] = 0;
		}

		entity = g_iSpawned[i][1];
		if( IsValidEntRef(entity) )
		{
			RemoveEdict(entity);
			g_iSpawned[i][1] = 0;
		}

		entity = g_iInferno[i][0];
		if( IsValidEntRef(entity) )
		{
			RemoveEdict(entity);
			g_iInferno[i][0] = 0;
		}
	}
}



// ====================================================================================================
//					STUFF
// ====================================================================================================
// Returns if the player has a valid weapon or not. Valid entity ID on success, 0 on failure, 1 on melee weapons.
HasWeapon(client, iWeapon, bool:test = false)
{
	if( iWeapon == -1 || g_iGunSlot[client] == 3 )
		return 0;

	if( g_iCvarCheck == 0 && strcmp(g_sCvarWeapon, "") == 0 )
	{
		if( g_iGunSlot[client] != 0 )
		{
			if( GetPlayerWeaponSlot(client, 1) == iWeapon )
			{
				decl String:sTemp[16];
				GetEdictClassname(iWeapon, sTemp, sizeof(sTemp));
				if( strcmp(sTemp, "weapon_melee") == 0 )
				{
					if( test )
						return 1;
					else
						return 0;
				}
				else
					return iWeapon;
			}
			return 0;
		}
		else
		{
			if( GetPlayerWeaponSlot(client, 0) == iWeapon )
				return iWeapon;
			else
				return 0;
		}
	}

	decl String:sWeapon[32];
	new entity;

	for( new i = 0; i < 2; i++ )
	{
		entity = GetPlayerWeaponSlot(client, i);
		if( entity != -1 )
		{
			GetEdictClassname(entity, sWeapon, sizeof(sWeapon));
			if( strcmp(sWeapon, g_sCvarWeapon) == 0 )
				return entity;
		}
	}

	return 0;
}

GetSurvivorType(client)
{
	if( !g_bLeft4Dead2 )
		return 1; // All models should use the "louis" position, since L4D1 models have no weapon_bone attachment.

	decl String:sModel[30];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	if( sModel[26] == 't' )								// t = Teenangst
		return 1;
	else if( sModel[26] == 'm' && sModel[27] == 'a')	// ma = Manager
		return 1;
	else
		return 0;
}

GetRandomType(iType)
{
	if( g_iCvarCombo ) return 1;

	new iCount, iArray[4];
	if( iType & ENUM_EXTINGUISHER )
		iArray[iCount++] = 1;
	if( iType & ENUM_FLAMETHROWER )
		iArray[iCount++] = 2;
	if( iType & ENUM_FREEZERSPRAY )
		iArray[iCount++] = 3;
	if( iType & ENUM_BLASTPUSHBACK )
		iArray[iCount++] = 4;
	return iArray[GetRandomInt(0, iCount -1)];
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

PrecacheParticle(const String:ParticleName[])
{
	new Particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(Particle, "effect_name", ParticleName);
	DispatchSpawn(Particle);
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	Particle = EntIndexToEntRef(Particle);
	SetVariantString("OnUser1 !self:Kill::0.1:-1");
	AcceptEntityInput(Particle, "AddOutput");
	AcceptEntityInput(Particle, "FireUser1");
}



// ====================================================================================================
//					POSITION STUFF
// ====================================================================================================
MoveForward(const Float:vPos[3], const Float:vAng[3], Float:vReturn[3], Float:fDistance)
{
	decl Float:vDir[3];
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vReturn = vPos;
	vReturn[0] += vDir[0] * fDistance;
	vReturn[1] += vDir[1] * fDistance;
	vReturn[2] += vDir[2] * fDistance;
}

SetTeleportEndPoint(client, Float:vPos[3], Float:vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	new Handle:trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, FilterExcludeSelf, client);

	if(TR_DidHit(trace))
	{
		decl Float:vNorm[3];
		TR_GetEndPosition(vPos, trace);
		TR_GetPlaneNormal(trace, vNorm);
		GetVectorAngles(vNorm, vAng);
		if( vNorm[2] == 1.0 )
		{
			vAng[0] = 0.0;
			vAng[1] += 180.0;
		}
		else
		{
			vPos[2] += 1.0;
		}
	}
	else
	{
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}

public bool:FilterExcludeSelf(entity, contentsMask, any:client)
{
	if( entity == client )
		return false;
	return true;
}