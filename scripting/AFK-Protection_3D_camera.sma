/*  *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *
*                                                                                       *
*   Plugin: "AFK Protection: 3D Camera"                                                 *
*                                                                                       *
*   Official plugin support: https://dev-cs.ru/threads/13904/                           *
*   Official repository: https://github.com/Nord1cWarr1or/AFK-Protection-3D-Camera      *
*                                                                                       *
*   Contacts of the author: Telegram: @NordicWarrior                                    *
*                                                                                       *
*   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *
*                                                                                       *
*   Плагин: "Защита АФК: 3D Камера"                                                     *
*                                                                                       *
*   Официальная поддержка плагина: https://dev-cs.ru/threads/13904/                     *
*   Официальный репозиторий: https://github.com/Nord1cWarr1or/AFK-Protection-3D-Camera  *
*                                                                                       *
*   Связь с автором: Telegram: @NordicWarrior                                           *
*                                                                                       *
*   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   */

#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <msgstocks>
#include <afk_protection>

new const PLUGIN_VERSION[] = "0.0.13";

#define AUTO_CONFIG		// Comment out if you don't want the plugin config to be created automatically in "configs/plugins"

#define GetCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

enum _:XYZ { Float:X, Float:Y, Float:Z };

new const CAMERA_CLASSNAME[]    = "trigger_camera";
new const CAMERA_MODEL[]        = "models/rpgrocket.mdl";

enum _:Cvars
{
    Float:CAM_HEIGHT,
    Float:CAM_DISTANCE,
    Float:CAM_ROTATION_SPEED,
    CAM_HIDE_HUD,
};

new g_pCvarValue[Cvars];
new g_iCvarValue_RoundTime;
new g_iRotatingSide[MAX_PLAYERS + 1];
new g_iCameraEnt[MAX_PLAYERS + 1] = { NULLENT, ... };
new g_iPreviousPlayerView[MAX_PLAYERS + 1] = { NULLENT, ... };

public plugin_init()
{
    register_plugin("AFK Protection: 3D Camera", PLUGIN_VERSION, "Nordic Warrior");

    register_dictionary("afk_protection_3D_cam.txt");

    RegisterHookChain(RG_CBasePlayer_Spawn, "RG_PlayerSpawn_Post", true);
    RegisterHookChain(RG_CBasePlayer_Killed, "RG_PlayerKilled_Post", true);

    CreateCvars();

    #if defined AUTO_CONFIG
    AutoExecConfig();
    #endif
}

public plugin_precache()
{
    precache_model(CAMERA_MODEL);
}

public OnConfigsExecuted()
{
    register_cvar("AFKProtection_3DCamera_version", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
    
    g_iCvarValue_RoundTime = get_cvar_num("mp_roundtime");    
}

public OnPlayerBecameAFK_pre(const pPlayer)
{
    CreateCam(pPlayer);

    switch(g_pCvarValue[CAM_HIDE_HUD])
    {
        case 1: hide_hud_elements(pPlayer, g_iCvarValue_RoundTime ? HideElement_Crosshair : HideElement_Crosshair | HideElement_Timer);
        case 2: hide_hud_elements(pPlayer, g_iCvarValue_RoundTime ? HideElement_All : HideElement_All | HideElement_Timer);
    }
}

public OnPlayerBack_post(const pPlayer)
{
    RemoveCam(pPlayer, true);

    if(g_pCvarValue[CAM_HIDE_HUD])
        hide_hud_elements(pPlayer, g_iCvarValue_RoundTime ? HideElement_None : HideElement_Timer);

    if(g_iRotatingSide[pPlayer])
        g_iRotatingSide[pPlayer] = 0;
    else
        g_iRotatingSide[pPlayer] = 1;
}

public client_disconnected(pPlayer)
{
    RemoveCam(pPlayer, false);

    g_iPreviousPlayerView[pPlayer] = NULLENT;
}

public RG_PlayerSpawn_Post(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return;

    if(apr_get_player_afk(pPlayer))
    {
        engset_view(pPlayer, g_iCameraEnt[pPlayer]);
        client_cmd(pPlayer, "stopsound");

        switch(g_pCvarValue[CAM_HIDE_HUD])
        {
            case 1: hide_hud_elements(pPlayer, g_iCvarValue_RoundTime ? HideElement_Crosshair : HideElement_Crosshair | HideElement_Timer);
            case 2: hide_hud_elements(pPlayer, g_iCvarValue_RoundTime ? HideElement_All : HideElement_All | HideElement_Timer);
        }
    }
}

public RG_PlayerKilled_Post(const pPlayer)
{
    if(!is_user_connected(pPlayer))
        return;

    if(apr_get_player_afk(pPlayer))
    {
        RemoveCam(pPlayer, true);

        if(!g_pCvarValue[CAM_HIDE_HUD])
            hide_hud_elements(pPlayer, g_iCvarValue_RoundTime ? HideElement_None : HideElement_Timer);
    }
}

CreateCam(const pPlayer)
{
    new iCameraEnt = rg_create_entity(CAMERA_CLASSNAME);

    if(is_nullent(iCameraEnt))
        return;
    
    engfunc(EngFunc_SetModel, iCameraEnt, CAMERA_MODEL);

    set_entvar(iCameraEnt, var_owner, pPlayer);
    set_entvar(iCameraEnt, var_solid, SOLID_NOT);
    set_entvar(iCameraEnt, var_movetype, MOVETYPE_NOCLIP);
    set_entvar(iCameraEnt, var_rendermode, kRenderTransColor);

    g_iPreviousPlayerView[pPlayer] = get_viewent(pPlayer);
    
    engset_view(pPlayer, iCameraEnt);
    client_cmd(pPlayer, "stopsound");

    set_entvar(iCameraEnt, var_nextthink, get_gametime() + 0.01);
    SetThink(iCameraEnt, "OnCamThink");

    g_iCameraEnt[pPlayer] = iCameraEnt;
}

RemoveCam(pPlayer, bool:bAttachViewToPlayer)
{
    if(bAttachViewToPlayer)
    {
        if(!is_nullent(g_iPreviousPlayerView[pPlayer]))
        {
            engset_view(pPlayer, g_iPreviousPlayerView[pPlayer]);
        }
        else
        {
            engset_view(pPlayer, pPlayer);
        }
        
        client_cmd(pPlayer, "stopsound");
    }

    new iCameraEnt = MaxClients;

    while((iCameraEnt = rg_find_ent_by_class(iCameraEnt, CAMERA_CLASSNAME)))
    {
        if(is_nullent(iCameraEnt))
            continue;

        if(get_entvar(iCameraEnt, var_owner) == pPlayer && g_iCameraEnt[pPlayer] == iCameraEnt)
        {
            set_entvar(iCameraEnt, var_flags, FL_KILLME);

            g_iCameraEnt[pPlayer] = NULLENT;
            break;
        }
    }
}

public OnCamThink(iCameraEnt)
{
    new pPlayer = get_entvar(iCameraEnt, var_owner);

    if(!is_user_alive(pPlayer) || is_nullent(iCameraEnt))
        return;

    /* --- Рассчёт движения камеры по окружности --- */

    static Float:flPlayerOrigin[XYZ], Float:flCamOrigin[XYZ]

    get_entvar(pPlayer, var_origin, flPlayerOrigin);

    static Float:flAngle[MAX_PLAYERS + 1] = { 0.01, ... };
    flAngle[pPlayer] += g_pCvarValue[CAM_ROTATION_SPEED];

    flCamOrigin[X] = flPlayerOrigin[X] + g_pCvarValue[CAM_DISTANCE] * (g_iRotatingSide[pPlayer] ? floatcos(flAngle[pPlayer], radian) : floatsin(flAngle[pPlayer], radian));
    flCamOrigin[Y] = flPlayerOrigin[Y] + g_pCvarValue[CAM_DISTANCE] * (g_iRotatingSide[pPlayer] ? floatsin(flAngle[pPlayer], radian) : floatcos(flAngle[pPlayer], radian));
    flCamOrigin[Z] = flPlayerOrigin[Z] + g_pCvarValue[CAM_HEIGHT];

    engfunc(EngFunc_TraceLine, flPlayerOrigin, flCamOrigin, IGNORE_MONSTERS, pPlayer, 0);

    new Float:flFraction;
    get_tr2(0, TR_flFraction, flFraction);

    flCamOrigin[X] = flPlayerOrigin[X] + flFraction * g_pCvarValue[CAM_DISTANCE] * (g_iRotatingSide[pPlayer] ? floatcos(flAngle[pPlayer], radian) : floatsin(flAngle[pPlayer], radian));
    flCamOrigin[Y] = flPlayerOrigin[Y] + flFraction * g_pCvarValue[CAM_DISTANCE] * (g_iRotatingSide[pPlayer] ? floatsin(flAngle[pPlayer], radian) : floatcos(flAngle[pPlayer], radian));
    flCamOrigin[Z] = flPlayerOrigin[Z] + flFraction * g_pCvarValue[CAM_HEIGHT];

    set_entvar(iCameraEnt, var_origin, flCamOrigin);

    /* --- */

    /* --- Рассчёт того, чтобы камера смотрела на игрока --- */

    static Float:flCamAngles[XYZ];

    xs_vec_sub(flPlayerOrigin, flCamOrigin, flCamAngles);

    vector_to_angle(flCamAngles, flCamAngles);

    flCamAngles[X] *= -1.0;

    set_entvar(iCameraEnt, var_angles, flCamAngles)

    /* --- */

    set_entvar(iCameraEnt, var_nextthink, get_gametime() + 0.01);
}

CreateCvars()
{
    bind_pcvar_float(create_cvar("afk_cam_height", "120.0",
        .description = GetCvarDesc("AFK_CAM_HEIGHT")),
        g_pCvarValue[CAM_HEIGHT]);

    bind_pcvar_float(create_cvar("afk_cam_distance", "150.0",
        .description = GetCvarDesc("AFK_CAM_DISTANCE")),
        g_pCvarValue[CAM_DISTANCE]);

    bind_pcvar_float(create_cvar("afk_cam_rotation_speed", "0.005",
        .description = GetCvarDesc("AFK_CAM_ROTATION_SPEED")),
        g_pCvarValue[CAM_ROTATION_SPEED]);

    bind_pcvar_num(create_cvar("afk_cam_hide_hud", "2",
        .description = GetCvarDesc("AFK_CAM_HIDE_HUD")),
        g_pCvarValue[CAM_HIDE_HUD]);
}