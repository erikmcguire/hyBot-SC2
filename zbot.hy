#! /usr/bin/env hy
; hy 0.15.0+64.ga42e17a
; Python 3.7.1

(import sc2 time random
        [sc2 [run_game BotAI maps Race Difficulty]]
        [sc2.player [Bot Computer]]
        [sc2.constants [*]])

(defclass rueBot [BotAI]
  (defn/a on_step [self iteration]
    (await (self.distribute_workers))
    (await (self.grow_drones))
    (await (self.grow_overlord))
    (await (self.move_overlord))
    (await (self.grow_extractor))
    (await (self.expand))
    (await (self.hyden))
    (await (self.grow_hy))
    (await (self.attack)))

  (defn/a attack [self]
    (setv hydras (self.units HYDRALISK ))
    (if (> (len hydras.idle) 4)
      (for [hy hydras.idle]
        (setv target (.find_target self self.state))
        (if target
          (await (self.do (.attack hy target.position)))
          (await (self.do (.attack hy (random.choice self.enemy_start_locations))))))))

  (defn find_target [self state]
    (setv enemies self.known_enemy_units)
      (when (> (len self.known_enemy_units) 0)
        (.choice random enemies)))

  (defn/a grow_drones [self]
    (for [larva (. (. (self.units LARVA) ready) noqueue)]
      (if (and (self.can_afford DRONE)
               (not (self.already_pending DRONE)))
        (await (self.do (.train larva DRONE))))))

  (defn/a grow_extractor [self]
    (for [hatchery (.ready (self.units HATCHERY))]
      (setv vespers (.closer_than self.state.vespene_geyser 15.0 hatchery))
      (for [vesper vespers]
        (when (self.can_afford EXTRACTOR)
          (setv drone (self.select_build_worker vesper.position))
          (if (!= drone None)
            (if (not (. (.closer_than (self.units EXTRACTOR) 1.0 vesper) exists))
              (await (self.do (.build drone EXTRACTOR vesper)))))))))

  (defn/a expand [self]
    (if (and (< (. (self.units HATCHERY) amount) 3)
             (self.can_afford HATCHERY))
      (await (self.expand_now))))

  (defn/a grow_overlord [self]
    (cond [(and (< self.supply_left 5)
                (not (self.already_pending OVERLORD)))
          (setv larvae (. (self.units LARVA) ready))
          (if larvae.exists
            (when (self.can_afford OVERLORD)
              (await (self.do (.train larvae.random OVERLORD)))))]))

  (defn/a hyden [self]
    (setv hatch (. self.townhalls random))
    (if (not (or (. (. (self.units SPAWNINGPOOL) ready) exists)
                    (self.already_pending SPAWNINGPOOL)))
            (when (self.can_afford SPAWNINGPOOL)
              (await (self.build SPAWNINGPOOL :near hatch))))
    (if (. (. (self.units SPAWNINGPOOL) ready) exists)
            (if (and (not (or (. (self.units LAIR) exists)
                              (self.already_pending LAIR)))
                     (. hatch noqueue))
              (when (self.can_afford LAIR)
                (await (self.do (.build hatch LAIR))))))
    (if (. (. (self.units LAIR) ready) exists)
            (when (and (not (or (. (self.units HYDRALISKDEN) exists)
                         (self.already_pending HYDRALISKDEN)))
                      (self.can_afford HYDRALISKDEN))
                  (await (self.build HYDRALISKDEN :near hatch)))))

  (defn/a grow_hy [self]
    (for [larva (. (. (self.units LARVA) ready) noqueue)]
      (if (and (. (. (self.units HYDRALISKDEN) ready) exists)
               (> self.supply_left 0))
        (when (self.can_afford HYDRALISK)
          (await (self.do (.train larva HYDRALISK)))))))

  (defn/a move_overlord [self]
    (for [ol (self.units OVERLORD)]
      (setv rp (. ol.position neighbors4) |
               (. ol.position neighbors8)
            larvae (self.units LARVA))
      (when larvae.exists
        (await (self.do (.move ol (.furthest larvae.random.position rp))))))))

(defn main []
  (run_game (.get maps "AbyssalReefLE")
            [(Bot :race Race.Zerg :ai (rueBot))
             (Computer Race.Protoss Difficulty.Easy)]
             :realtime False :save_replay_as (.format "ZvT-{}.SC2Replay" (.strftime time "%H%M%S"))))

(when (= --name-- "__main__")
  (main))
