import sc2, time, random
from sc2 import run_game, maps, Race, Difficulty
from sc2.player import Bot, Computer
from sc2.data import race_townhalls
from sc2.constants import *

class rueBot(sc2.BotAI):
    def __init__(self):
        self.ITERATIONS_PER_MINUTE = 165
        self.MAX_WORKERS = 50

    async def on_step(self, iteration):
        self.iteration = iteration
        await self.distribute_workers()
        await self.grow_drones()
        await self.grow_overlord()
        await self.move_overlord()
        await self.grow_extractor()
        await self.expand()
        await self.grow_offensive_buildings()
        await self.grow_army()
        await self.attack()

    async def attack(self):
        waspish = {HYDRALISK: [6, 4],
                   MUTALISK: [4, 2],
                   ZERGLING: [8, 6]}
        for unit in waspish:
            if self.units(unit).amount > waspish[unit][0] and self.units(unit).amount > waspish[unit][1]:
                for w in self.units(unit).idle:
                    target = self.find_target(self.state)
                    if target:
                        await self.do(w.attack(target.position))
            elif len(self.known_enemy_units) > 0 and self.units(unit).amount > waspish[unit][1]:
                for w in self.units(unit).idle:
                    await self.do(w.attack(random.choice(self.enemy_start_locations)))

    def find_target(self, state):
        enemies = self.known_enemy_units
        if len(self.known_enemy_units) > 0:
            return random.choice(enemies)

    async def grow_drones(self):
        if len(self.units(DRONE)) < self.MAX_WORKERS and self.units(HATCHERY).amount * 16 > len(self.units(DRONE)):
            for larva in self.units(LARVA).ready.noqueue:
                if self.can_afford(DRONE) and not self.already_pending(DRONE):
                    await self.do(larva.train(DRONE))

    async def grow_extractor(self):
        for hatchery in self.units(HATCHERY).ready:
            vespers = self.state.vespene_geyser.closer_than(15.0, hatchery)
            for vesper in vespers:
                if self.can_afford(EXTRACTOR):
                    drone = self.select_build_worker(vesper.position)
                    if drone:
                        if not self.units(EXTRACTOR).closer_than(1, vesper).exists:
                            await self.do(drone.build(EXTRACTOR, vesper))

    async def expand(self):
        if self.units(HATCHERY).amount < 4 and self.can_afford(HATCHERY):
            await self.expand_now()

    async def grow_overlord(self):
        if self.supply_left < 5 and not self.already_pending(OVERLORD):
            larvae = self.units(LARVA).ready
            if larvae.exists:
                if self.can_afford(OVERLORD):
                    await self.do(larvae.random.train(OVERLORD))

    async def grow_offensive_buildings(self):
        hatch = self.townhalls.random

        if not (len(self.units(SPAWNINGPOOL)) >= (self.iteration / (self.ITERATIONS_PER_MINUTE / 2)) or self.already_pending(SPAWNINGPOOL)):
            if self.can_afford(SPAWNINGPOOL) and len(self.units(SPAWNINGPOOL)) < 4:
                await self.build(SPAWNINGPOOL, near=hatch)

        if self.units(SPAWNINGPOOL).ready.exists:
            if not (self.units(LAIR).exists or self.already_pending(LAIR)) and hatch.noqueue:
                if self.can_afford(LAIR):
                    await self.do(hatch.build(LAIR))

        if self.units(LAIR).ready.exists:
            builds = [SPIRE, HYDRALISKDEN]
            lens = list(map(lambda b: len(self.units(b)), builds))
            m = min(lens)
            for b in builds:
                if not (self.units(b).exists or self.already_pending(b)):
                    if self.can_afford(b) and len(self.units(b)) <= m and len(self.units(b)) < (self.iteration / (self.ITERATIONS_PER_MINUTE / 2)):
                        await self.build(b, near=hatch)

    async def grow_army(self):
        units = {HYDRALISK: HYDRALISKDEN, MUTALISK: SPIRE, ZERGLING: SPAWNINGPOOL}
        lens = list(map(lambda u: len(self.units(u)), units))
        m = min(lens)
        for unit in units:
            for larva in self.units(LARVA).ready.noqueue:
                if self.units(units[unit]).ready.exists and self.supply_left > 0:
                    if self.can_afford(unit) and len(self.units(unit)) <= m:
                        await self.do(larva.train(unit))

    async def move_overlord(self):
        for ol in self.units(OVERLORD):
            rp = ol.position.neighbors4 | ol.position.neighbors8
            larvae = self.units(LARVA)
            if larvae.exists:
                await self.do(ol.move(larvae.random.position.furthest(rp)))

def main():
    run_game(maps.get("AbyssalReefLE"),
            [Bot(Race.Zerg, rueBot()),
            Computer(Race.Protoss, Difficulty.Easy)],
        realtime=False, save_replay_as="ZvT-{}.SC2Replay".format(time.strftime("%m%d%Y%H%M%S")))

if __name__ == "__main__":
    main()
