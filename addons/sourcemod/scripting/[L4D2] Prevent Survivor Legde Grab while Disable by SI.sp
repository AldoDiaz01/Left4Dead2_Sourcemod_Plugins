#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
#define PLUGIN_NAME "[L4D2] Prevent Survivor Legde Grab while Disable by SI"

public Plugin:myinfo =  {
	name = PLUGIN_NAME, 
	author = "DeathChaos25", 
	description = "Survivors will not be able to save themselves from Special Infected by grabbing on to ledges, instead they will now fall to their deaths", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=261023"
};

public OnPluginStart()
{
	HookEvent("jockey_ride", Event_DisableLedgeHang);
	HookEvent("jockey_ride_end", Event_EnableLedgeHang);
	HookEvent("tongue_grab", Event_DisableLedgeHang);
	HookEvent("tongue_release", Event_EnableLedgeHang);
}

public Action:Event_DisableLedgeHang(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsSurvivor(client))
	{
		return;
	}
	AcceptEntityInput(client, "DisableLedgeHang");
}

public Action:Event_EnableLedgeHang(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!IsSurvivor(client))
	{
		return;
	}
	AcceptEntityInput(client, "EnableLedgeHang");
}

stock bool:IsSurvivor(client)
{
	new maxclients = GetMaxClients();
	if (client > 0 && client < maxclients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
} 