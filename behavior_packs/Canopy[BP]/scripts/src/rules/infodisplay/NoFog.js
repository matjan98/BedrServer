import { EntityComponentTypes, world } from "@minecraft/server";
import { InfoDisplayShapeElement } from "./InfoDisplayShapeElement";

export class NoFog extends InfoDisplayShapeElement {
    static FOG_REMOVAL_IDS = {
        "minecraft:overworld": "canopy:overworld_no_fog",
        "minecraft:nether": "canopy:nether_no_fog",
        "minecraft:the_end": "canopy:end_no_fog"
    };
    static FOG_TAG = "canopy_no_fog";

    playerFogComponent;

    constructor(player) {
        const ruleData = {
            identifier: 'noFog',
            description: { translate: 'rules.infoDisplay.noFog' },
            wikiDescription: `Disables the fog effect for the player. Water and lava are unaffected.`,
            onEnableCallback: () => this.removeFog(),
            onDisableCallback: () => this.resetFog()
        };
        super(ruleData, 0);
        this.player = player;
        this.playerFogComponent = NoFog.resolveFogComponent(player);
        this.onDimensionChangeBound = this.onDimensionChange.bind(this);
    }

    // LOKALNY PATCH (2026-08-04, MC 26.40 / @minecraft/server 2.10.0-beta).
    // Z enuma EntityComponentTypes zniknal czlon Fog, a zastepujace go FogSettings pojawia sie
    // dopiero w 2.11.0-beta (26.50-preview) - na 26.40 nie ma zadnego API mgly. Bez tej oslony
    // getComponent(undefined) rzucalo InvalidArgumentError juz w KONSTRUKTORZE, przez co caly
    // InfoDisplay nie powstawal ani razu: system.runInterval probowal go tworzyc co tick
    // (~20 bledow/s w logu), nie bylo wspolrzednych, a F8 nie mial czego pokazywac.
    // Gdy wyjdzie Canopy pod 26.40 - ten patch znika razem ze stara wersja paczki.
    static resolveFogComponent(player) {
        const componentId = EntityComponentTypes.Fog ?? 'minecraft:fog';
        try {
            return player.getComponent(componentId);
        } catch (error) {
            return undefined;
        }
    }

    removeFog() {
        if (!this.playerFogComponent)
            return;
        this.playerFogComponent.push(this.getCurrentFogId(), NoFog.FOG_TAG);
        world.afterEvents.playerDimensionChange.subscribe(this.onDimensionChangeBound);
    }

    resetFog() {
        if (!this.playerFogComponent)
            return;
        world.afterEvents.playerDimensionChange.unsubscribe(this.onDimensionChangeBound);
        this.clearFog();
    }

    clearFog() {
        if (!this.playerFogComponent)
            return;
        this.playerFogComponent.remove(NoFog.FOG_TAG);
    }

    getCurrentFogId() {
        const currentDimension = this.player.dimension.id;
        return NoFog.FOG_REMOVAL_IDS[currentDimension] ?? NoFog.FOG_REMOVAL_IDS["minecraft:overworld"];
    }

    onTick() {
        /* pass */
    }

    onDimensionChange() {
        if (!this.playerFogComponent)
            return;
        this.clearFog();
        const fogRemovalId = this.getCurrentFogId();
        this.playerFogComponent.push(fogRemovalId, NoFog.FOG_TAG);
    }
}