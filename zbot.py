import sc2, time, random
from sc2 import run_game, maps, Race, Difficulty
from sc2.player import Bot, Computer
from sc2.data import race_townhalls
from sc2.constants import *

class rueBot(sc2.BotAI):
    async def on_step(self, iteration):
        await self.distribute_workers()
        await self.grow_drones()
        await self.grow_overlord()
        await self.move_overlord()
        await self.grow_extractor()
        await self.expand()
        await self.offensive_force_pools()
        await self.grow_offensive_force()
        await self.attack()

    async def attack(self):
        hydras = self.units(HYDRALISK)
        if len(hydras.idle) > 4:
            for hy in hydras.idle:
                target = self.find_target(self.state)
                if target:
                    await self.do(hy.attack(target.position))
                else:
                    await self.do(
                        hy.attack(random.choice(self.enemy_start_locations)))

    def find_target(self, state):
        enemies = self.known_enemy_units
        if len(self.known_enemy_units) > 0:
            return random.choice(enemies)

    async def grow_overlord(self):
        if self.supply_left < 5 and not self.already_pending(OVERLORD):
            larvae = self.units(LARVA).ready
            if larvae.exists:
                if self.can_afford(OVERLORD):
                    await self.do(larvae.random.train(OVERLORD))

    async def grow_drones(self):
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

    async def offensive_force_pools(self):
        hatch = self.townhalls.random

        if not (self.units(SPAWNINGPOOL).ready.exists or self.already_pending(SPAWNINGPOOL)):
            if self.can_afford(SPAWNINGPOOL):
                await self.build(SPAWNINGPOOL, near=hatch)

        if self.units(SPAWNINGPOOL).ready.exists:
            if not (self.units(LAIR).exists or self.already_pending(LAIR)) and hatch.noqueue:
                if self.can_afford(LAIR):
                    await self.do(hatch.build(LAIR))

        if self.units(LAIR).ready.exists:
            if not (self.units(HYDRALISKDEN).exists or self.already_pending(HYDRALISKDEN)):
                if self.can_afford(HYDRALISKDEN):
                    await self.build(HYDRALISKDEN, near=hatch)

    async def grow_offensive_force(self):
        for larva in self.units(LARVA).ready.noqueue:
            if self.units(HYDRALISKDEN).ready.exists and self.supply_left > 0:
                if self.can_afford(HYDRALISK):
                    await self.do(larva.train(HYDRALISK))

    async def expand(self):
        if self.units(HATCHERY).amount < 3 and self.can_afford(HATCHERY):
            await self.expand_now()

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
        realtime=False, save_replay_as="ZvT-{}.SC2Replay".format(time.strftime("%H%M%S")))

if __name__ == "__main__":
    main()
