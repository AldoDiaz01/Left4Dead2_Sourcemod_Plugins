#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

new Handle:hGLAmmo = INVALID_HANDLE;
new Handle:hM60Ammo = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[L4D2] Ammo Pickup",
	author = "Dr!fter",
	description = "Allow ammo pickup for m60 and grenade launcher",
	version = "1.1.1"
}
public OnPluginStart()
{
	hGLAmmo = FindConVar("ammo_grenadelauncher_max");
	hM60Ammo = FindConVar("ammo_m60_max");
	HookEvent("ammo_pile_weapon_cant_use_ammo", OnWeaponDosntUseAmmo, EventHookMode_Pre);
}
public Action:OnWeaponDosntUseAmmo(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new weaponIndex = GetPlayerWeaponSlot(client, 0);
	
	if(weaponIndex == -1)
		return Plugin_Continue;
	
	new String:classname[64];
	
	GetEdictClassname(weaponIndex, classname, sizeof(classname));
	
	if(StrEqual(classname, "weapon_rifle_m60") || StrEqual(classname, "weapon_grenade_launcher"))
	{
		new iClip1 = GetEntProp(weaponIndex, Prop_Send, "m_iClip1");
		new iPrimType = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryAmmoType");
		
		if(StrEqual(classname, "weapon_rifle_m60"))
		{
			SetEntProp(client, Prop_Send, "m_iAmmo", ((GetConVarInt(hM60Ammo)+150)-iClip1), _, iPrimType);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_iAmmo", ((GetConVarInt(hGLAmmo)+1)-iClip1), _, iPrimType);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public OnPluginEnd()
{
}