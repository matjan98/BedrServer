import { world, system } from "@minecraft/server";
import { ActionFormData } from "@minecraft/server-ui";
import * as staticData from "./static_data";
import * as func from "./imp_func";

// central menu registery
const menu_details = {
    display_name: "Star's Debug Screen",
    icon_path: "textures/star/debug_screen_icon",
    uuid: "c9b13a0a-09ea-40b9-9da7-a984e0e04281",
    trigger_persona_id: "4c8ae710-df2e-47cd-814d-cc7bf21a3d67"
}
world.afterEvents.worldLoad.subscribe(() => {
    const dim = world.getDimension("overworld");
    dim.runCommand(`scriptevent "star-menu:register" ${JSON.stringify(menu_details)}`);
});

// keeping track of the TPS
var lastTick = Date.now();
var worldTps = 20;
var timeArray = [];
system.runInterval(() => {
    if (timeArray.length === 20) timeArray.shift();
    timeArray.push(Date.now() - lastTick);
    worldTps = Math.round(1000 / (timeArray.reduce((a, b) => a + b) / timeArray.length));
    lastTick = Date.now();
})

// this runs the debug screen for each player when they initially spawn
world.afterEvents.playerSpawn.subscribe((event) => {
    if (event.initialSpawn == false) return;
    const player = event.player;
    const joinTime = system.currentTick;

    // setting and/or loading field assignments for the player
    if (player.getDynamicProperty("fieldAssign") == undefined) {
        player.setDynamicProperty("fieldAssign", JSON.stringify(staticData.defaultFieldAssign));
    }
    const fieldAssign = JSON.parse(player.getDynamicProperty("fieldAssign"));
    
    // dynamic data storage object
    const data = {
        empty: "",
        biome: "",
        lightLevel: "",
        difficulty: "",
        inVillage: "",
        isUnderground: "",
        weather: "",
        elTime: "",
        chunkLoc: "",
        entityCount: "",
        dimension: "",
        direction: "",
        dayCount: "",
        moonPhase: "",
        yaw: "",
        tps: "",
    }

    // menu system
    const menuEvent = system.afterEvents.scriptEventReceive.subscribe((e) => {
        if(e.id != "star-menu:trigger" || e.message != menu_details.uuid || e.sourceEntity != player) return;

        const fieldList = Object.keys(data);
        new ActionFormData()
        .title("Star's Debug Screen Settings")
        .body("Select whichever panel you would like to edit.")
        .button("Edit Left Panel")
        .button("Edit Right Panel")
        .show(player)
        .then((r) => {
            if(r.canceled) return;
            if(r.selection == 0) {
                func.fieldMenu(player, fieldAssign, fieldList, "left")
            } else if(r.selection == 1) {
                func.fieldMenu(player, fieldAssign, fieldList, "right")
            }
        });
    });

    // reciever for data events coming form player entity file
    const dataEvent = world.afterEvents.dataDrivenEntityTrigger.subscribe((event) => {
        if(event.entity != player || !event.eventId.startsWith("ds")) return;
        const id = event.eventId.slice(3, 7);
        const value = event.eventId.slice(8);
        
        if(id == "0011") {
            data.inVillage = "In Village?: "+value;
        } else if(id == "0100") {
            data.isUnderground = "Is Underground?: "+value;
        } else if(id == "0110") {
            data.weather = "Weather: "+value;
        }
    });

    // data transfer to hud.json on every odd tick
    const runId = system.runInterval(() => {
        if (system.currentTick%2 == 0) return;

        data.elTime = "Elapsed Time: "+func.getElapsedTime(joinTime);
        data.direction = "Facing Direction: "+func.getViewDirection(player);
        data.chunkLoc = "Chunk Loc: "+func.getChunkLoc(player);
        data.yaw = "Yaw: "+func.getYaw(player);
        data.entityCount = "Entity Count: "+player.dimension.getEntities({location: player.location, maxDistance: 96}).length;
        data.dimension = "Dimension: "+player.dimension.id;
        data.dayCount = "Day Count: "+world.getDay();
        data.moonPhase = "Moon Phase: "+world.getMoonPhase();
        data.tps = "TPS: "+worldTps;
        data.difficulty = "Difficulty: "+world.getDifficulty();
        data.biome = "Biome: "+player.dimension.getBiome(player.location).id.slice(10);
        data.lightLevel = "Light Level: "+player.dimension.getLightLevel(player.location);

        let dataString = "";
        Object.keys(fieldAssign).forEach((f) => {
            const d = data[fieldAssign[f]].padStart(100, "!");
            dataString = dataString+d;
        });
        player.onScreenDisplay.setTitle(dataString);
    }, 1);

    // setup to stop the all events and callbacks when the player leaves
    const leaveEvent = world.beforeEvents.playerLeave.subscribe((event) => {
        if(event.player != player) return;
        system.clearRun(runId);
        system.run(() => {
            system.afterEvents.scriptEventReceive.unsubscribe(menuEvent);
            world.afterEvents.dataDrivenEntityTrigger.unsubscribe(dataEvent);
            world.beforeEvents.playerLeave.unsubscribe(leaveEvent);
        });
    });
});