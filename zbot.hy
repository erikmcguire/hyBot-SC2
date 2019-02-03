#! /usr/bin/env hy
; hy 0.15.0+64.ga42e17a
; Python 3.7.1

(import sc2 time random
        [sc2 [run_game BotAI maps Race Difficulty]]
        [sc2.player [Bot Computer]]
        [sc2.constants [*]])

(defclass rueBot [BotAI]
  (defn --init-- [self]
    (setv self.ITERATIONS_PER_MINUTE 165
          self.MAX_WORKERS 50))

  (defn/a on_step [self iteration]
    (setv self.iteration iteration)
    (await (self.distribute_workers))
    (await (self.grow_drones))
    (await (self.grow_overlord))
    (await (self.move_overlord))
    (await (self.grow_extractor))
    (await (self.expand))
    (await (self.grow_offensive_buildings))
    (await (self.grow_army))
    (await (self.attack)))

  (defn/a attack [self]
    (setv waspish {HYDRALISK [15 5]
                   MUTALISK [8 3]
                   ZERGLING [30 15]})
    (for [unit waspish]
      (if (and (> (. (self.units unit) amount)
                  (first (get waspish unit)))
               (> (. (self.units unit) amount)
                  (nth (get waspish unit) 1))))
          (for [w (. (self.units unit) idle)]
            (setv target (.find_target self self.state))
            (if target
                (await (self.do
                    (.attack w
                            (. target
                               position))))))
          (when (and (> (. (self.units unit) amount)
                        (nth (get waspish unit) 1))
                     (> (len (self.known_enemy_units)) 0))
            (for [w (. (self.units unit) idle)]
                (await (self.do
                        (.attack w
                                 (random.choice
                                    self.enemy_start_locations))))))))

  (defn find_target [self state]
    (setv enemies self.known_enemy_units)
      (when (> (len self.known_enemy_units) 0)
        (.choice random enemies)))

  (defn/a grow_drones [self]
    (if (and (> (* 16 (len (self.units HATCHERY)))
             (len (self.units DRONE)))
          (< (len (self.units DRONE))
              self.MAX_WORKERS))
      (for [larva (. (. (self.units LARVA) ready) noqueue)]
        (if (and (self.can_afford DRONE)
                 (not (self.already_pending DRONE)))
          (await (self.do (.train larva DRONE)))))))

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
    (if (and (< (. self.townhalls amount) 2)
             (self.can_afford HATCHERY))
      (await (self.expand_now))))

  (defn/a grow_overlord [self]
    (cond [(and (< self.supply_left 5)
                (not (self.already_pending OVERLORD)))
          (setv larvae (. (self.units LARVA) ready))
          (if larvae.exists
            (when (self.can_afford OVERLORD)
              (await (self.do (.train larvae.random OVERLORD)))))]))

  (defn/a grow_offensive_buildings [self]
    (setv hatch (. self.townhalls random))
    (cond [(and (not (or (>= (. (self.units SPAWNINGPOOL) amount)
                             (/ self.iteration
                                (/ self.ITERATIONS_PER_MINUTE 2)))
                     (self.already_pending SPAWNINGPOOL)))
                (< (. (self.units SPAWNINGPOOL) amount) 4)
                (self.can_afford SPAWNINGPOOL))
            (await (self.build SPAWNINGPOOL :near hatch))]
          [(and (. (. (self.units SPAWNINGPOOL) ready) exists)
                   (not (or (. (self.units LAIR) exists)
                            (self.already_pending LAIR)))
                   (. hatch noqueue)
                   (self.can_afford LAIR))
            (await (self.do (.build hatch LAIR)))]
          [(. (. (self.units LAIR) ready) exists)
            (setv builds [SPIRE HYDRALISKDEN]
                  lens (list (map (fn [b] (len (self.units b))) builds))
                  m (min lens))
            (for [b builds]
              (if (and (not (or (>= (len (self.units b))
                                      (/ self.iteration
                                         (/ self.ITERATIONS_PER_MINUTE 2)))
                                    (self.already_pending b)))
                       (self.can_afford b)
                       (<= (len (self.units b))
                           m))
                  (await (self.build b :near hatch))))]))

  (defn/a grow_army [self]
    ; (if (not (> (. (self.units HYDRALISK) amount)
    ;             (. (self.units MUTALISK) amount)))
    (setv units {HYDRALISK HYDRALISKDEN MUTALISK SPIRE ZERGLING SPAWNINGPOOL}
          lens (list (map (fn [u] (len (self.units u))) units))
          m (min lens))
    (for [unit units]
      (for [larva (. (. (self.units LARVA) ready) noqueue)]
        (if (and (. (. (self.units (get units unit)) ready) exists)
                 (> self.supply_left 0))
          (when (and (self.can_afford unit)
                     (<= (len (self.units unit))
                          m))
            (await (self.do (.train larva unit))))))))

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
             :realtime False :save_replay_as (.format "ZvT-{}.SC2Replay" (.strftime time "%m%d%Y%H%M%S"))))

(when (= --name-- "__main__")
  (main))
