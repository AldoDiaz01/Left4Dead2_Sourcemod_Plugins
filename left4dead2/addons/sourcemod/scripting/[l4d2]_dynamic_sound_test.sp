/* Includes */
#include <sourcemod>
#include <sdktools>

/* L4D1 Survivor Models */
#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_ZOEY 	"models/survivors/survivor_teenangst.mdl"
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"

/* Plugin Information */
public Plugin:myinfo =  {
	name = "[L4D2] L4D1 sounds restore", 
	author = "DeathChaos25", 
	description = "Restores L4D1 sounds when playing a L4D1 campaign on L4D2 survivor set", 
	version = "1.0", 
	url = "1337H4X"
}

/* Globals */
#define DEBUG 1 
#define DEBUG_TAG "L4D1 Sound Restore"
#define DEBUG_PRINT_FORMAT "[%s] %s"

#define MAX_ENTITIES 4096

/* Plugin Functions */
public OnPluginStart()
{
	HookEvent("player_incapacitated_start", IncapStart)
	HookEvent("revive_success", ReviveSuccess)
	HookEvent("player_spawn", PlayerSpawn)
	HookEvent("survivor_rescued", SurvivorRescued)
	HookEvent("player_death", PlayerDeath)
	HookEvent("mission_lost", MissionLost)
}

public OnMapStart()
{
	// Map check coming soon tm music/tags/LeftForDeathHit_l4d1.wav
	PrefetchSound("music/tags/LeftForDeathHit_l4d1.wav")
	PrecacheSound("music/tags/LeftForDeathHit_l4d1.wav", true)
	
	PrefetchSound("music/tags/LeftForDeathHit_l4d1.wav")
	PrecacheSound("music/tags/LeftForDeathHit_l4d1.wav", true)
}


public IncapStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsL4D1Survivor(client) && !IsFakeClient(client))
	{
		StopMusic(client)
		ClientCommand(client, "music_dynamic_play Event.Down_L4D1");
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (i != client && IsSurvivor(i) && IsPlayerAlive(i) && !IsFakeClient(i))
			{
				StopMusic(i)
				EmitSoundToClient(i, "music/tags/PuddleOfYouHit_l4d1.wav", _, SNDCHAN_STATIC)
			}
		}
	}
}

public ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	if (IsL4D1Survivor(client) && !IsFakeClient(client))
	{
		StopMusic(client)
	}
}

public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client))
	{
		StopMusic(client)
	}
}

public SurvivorRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	if (IsSurvivor(client))
	{
		StopMusic(client)
	}
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsL4D1Survivor(client))
	{
		StopMusic(client)
		ClientCommand(client, "play @#music/undeath/LeftForDeath_l4d1.wav");
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (i != client && IsSurvivor(i) && IsPlayerAlive(i) && !IsFakeClient(i))
			{
				ClientCommand(i, "music_dynamic_stop_playing Event.SurvivorDeathHit")
				EmitSoundToClient(i, "music/tags/LeftForDeathHit_l4d1.wav", _, SNDCHAN_STATIC)
			}
		}
	}
}

public MissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsL4D1Survivor(i) && !IsFakeClient(i))
		{
			CreateTimer(0.00001, STOPMUSIC, i);
		}
	}
}

public Action:STOPMUSIC(Handle:Timer, any:i)
{
	StopMusic(i)
	ClientCommand(i, "music_dynamic_play Event.ScenarioLose_L4D1")
}

stock StopMusic(client)
{
	ClientCommand(client, "music_dynamic_stop_playing Event.Down_L4D1")
	ClientCommand(client, "music_dynamic_stop_playing Event.Down")
	ClientCommand(client, "music_dynamic_stop_playing Event.SurvivorDeath_L4D1")
	ClientCommand(client, "music_dynamic_stop_playing Event.SurvivorDeath")
	ClientCommand(client, "music_dynamic_stop_playing Event.ScenarioLose_L4D1")
	ClientCommand(client, "music_dynamic_stop_playing Event.ScenarioLose")
	
	FakeCHEAT(client, "stopsound", "@#music/terror/PuddleOfYou.wav")
	FakeCHEAT(client, "stopsound", "@#music/terror/PuddleOfYou_l4d1.wav")
	
	FakeCHEAT(client, "stopsound", "music/tags/LeftForDeathHit.wav")
	FakeCHEAT(client, "stopsound", "music/tags/LeftForDeathHit_l4d1.wav")
	
	FakeCHEAT(client, "stopsound", "@#music/undeath/Death.wav")
	//FakeCHEAT(client, "stopsound", "@#music/undeath/Death_l4d1.wav")
	
	FakeCHEAT(client, "stopsound", "@#music/undeath/LeftForDeath_l4d1.wav")
	FakeCHEAT(client, "stopsound", "music/tags/LeftForDeathHit_l4d1.wav")
}

#if DEBUG
stock Debug_PrintText(const String:format[], any:...)
{
	decl String:buffer[256]
	VFormat(buffer, sizeof(buffer), format, 2)
	
	LogMessage(buffer)
	
	new AdminId:adminId
	for (new client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || IsFakeClient(client)) {
			continue
		}
		
		adminId = GetUserAdmin(client)
		if (adminId == INVALID_ADMIN_ID || !GetAdminFlag(adminId, Admin_Root)) {
			continue
		}
		
		PrintToChat(client, DEBUG_PRINT_FORMAT, DEBUG_TAG, buffer)
	}
}
#endif  

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsL4D1Survivor(client)
{
	if (IsSurvivor(client))
	{
		decl String:model[42];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
		if (StrEqual(model, MODEL_FRANCIS, false) || StrEqual(model, MODEL_LOUIS, false)
			 || StrEqual(model, MODEL_BILL, false) || StrEqual(model, MODEL_ZOEY, false))
		{
			return true;
		}
		
	}
	return false;
}

stock bool:IsIncaped(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
}

void FakeCHEAT(client, char[] sCommand, char[] sArgument)
{
	int iFlags = GetCommandFlags(sCommand)
	SetCommandFlags(sCommand, iFlags & ~FCVAR_CHEAT)
	ClientCommand(client, "%s %s", sCommand, sArgument)
}