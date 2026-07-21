import { system } from "@minecraft/server";
import { ModalFormData } from "@minecraft/server-ui";

export function getElapsedTime(joinTime) {
    const ticks = system.currentTick - joinTime;
    const secs = Math.floor((ticks / 20) % 60).toString().padStart(2, "0");
    const mins = Math.floor((ticks / 1200) % 60).toString().padStart(2, "0");
    const hours = Math.floor(ticks / 72000).toString().padStart(2, "0");
    return hours + ":" + mins + ":" + secs;
}

export function getViewDirection(player) {
    var angle = player.getRotation().y;
    if(angle < 0) angle = 360 - Math.abs(angle);
    if((225 < angle) && (angle <= 315)) {
        return "East";
    } else if((45 <= angle) && (angle < 135)) {
        return "West";
    } else if ((135 < angle) && (angle <= 225)) {
        return "North";
    } else {
        return "South";
    }
}

export function getChunkLoc(player) {
    const location = player.location;
    const chunkX = Math.floor(location.x/16);
    const chunkZ = Math.floor(location.z/16);
    const locInChunkX = Math.floor(location.x - 16 * chunkX);
    const locInChunkZ = Math.floor(location.z - 16 * chunkZ);
    return `${chunkX}, ${chunkZ} (${locInChunkX}, ${locInChunkZ})`;
}

export function getYaw(player) {
    return `${Math.round(player.getRotation().x*(-1))}deg`;
}

export function fieldMenu(player, fieldAssign, fieldList, panel="left") {
    const form = new ModalFormData()
    form.title("Star's Debug Screen Fields Editor");

    const vars = {
        left: {
            i: 1,
            k: 20
        },
        right: {
            i: 21,
            k: 46
        }
    };

    for(var i = vars[panel]["i"]; i <= vars[panel]["k"]; i++) {
        form.dropdown(`Field ${i}:`, fieldList, {defaultValueIndex: fieldList.indexOf(fieldAssign[i])});
    }

    return form.show(player).then((r) => {
        if(r.canceled) return;
        let i = vars[panel]["i"];
        for(let selection in r.formValues) {
            fieldAssign[String(i)] = fieldList[r.formValues[selection]];
            i = i+1;
        }
        player.setDynamicProperty("fieldAssign", JSON.stringify(fieldAssign));
        player.onScreenDisplay.setActionBar(`§6New Debug Screen Feilds have been saved!`);
    });
}