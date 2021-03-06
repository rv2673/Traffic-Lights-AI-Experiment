globals [
  ; Police and fine variables
  ;prob-police-appearance             ;; in promille, so [0,1000]
  
  ; Experience variables, there are three ways to participate in someone getting caught:
  ; (1) Experiencing: getting caught ourselves.
  ; (2) Seeing: see someone getting caught.
  ; (3) Hearing: someone telling you someone got caught.
  caught-experienced-weight;
  caught-saw-weight
  caught-heard-weight
  ; The radius around people caught that other people will see.
  caught-saw-radius
  ; The chance to hear the news on a per person basis.
  caught-heard-chance
  
  ; Car and pedestrian quantities
  ;number-of-people
  ;number-of-cars
  
  ; Traffic light for the cars
  car-traffic-light-red?
  car-traffic-light-xpos
  car-traffic-light-ypos
  
  ; Traffic light for the pedestrians
  pedestrian-traffic-light-red?
  pedestrian-traffic-light-xpos
  pedestrian-traffic-light-ypos
  
  pedestrian-viewing-range            ;; in patches, world is 33x33 patches.
  
  ; Waiting zone
  ;waiting-zone?
  waiting-time-base
  waiting-time-diff
  
  ; The road
  road-start-xpos
  road-end-xpos
  
  ; The tick number when the car or pedestrian traffic light should go green respectively red
  tick-car-green
  tick-car-red
  tick-pedestrian-green
  tick-pedestrian-red
  
  ;; STATISTICS
  ;; Statistics are based on the number of people approaching/crossing the road during one traffic light cycle.
  ;; In case of red light walkers who wrap around the world and approach the road multiple times they will be counted accordingly.
  ;; A cycle starts as soon as the pedestrian traffic light goes red.
  stat-cycles
  
  ; Counter of the number of pedestrians approaching the road during a cycle.
  ; Note: these don't have to be unique pedestrians since one person can be counted multiple times.
  stat-pedestrians
  stat-cautious
  stat-adaptive
  stat-reckless
  
  ; The total counterparts of the stat globals above.
  stat-total-pedestrians
  stat-total-cautious
  stat-total-adaptive
  stat-total-reckless
  
  ; Counter for the number of times a pedestrian walks through a red light during one traffic light cycle
  ; Resets when the pedestrian traffic light goes green
  stat-red-walking 
  stat-adaptive-red-walking
  
  ; Counters for the number of times a red light appeared and the total amount of red light walkers during the simulation
  stat-total-red-lights
  stat-total-red-walking
  stat-total-adaptive-red-walking
  
  ;The rate at which the probability to cross reduces
  reducerate
  
  ; The distance (in patches) an agent looks around to see if other people are crossing (y/n)
  influence-radius
  ; The influence (factor) a reckless agent has on other people
  influence-pos-factor
  ; The influence (factor) a non-reckless agent has on other people
  influence-neg-factor ; can be negative
]

; Person model
breed [people person]
people-own [
  walker-type                         ;; "cautious", "adaptive", "reckless"
  walked-through-red? 
  own-profit
  ; The number of ticks a person waits before approaching the road 
  wait-time
  
  ; Adaptive type specific properties
  adaptive-threshold-people-crossing
  adaptive-gone-reckless
  adaptive-fixed-prob-cross
  adaptive-prob-cross
  
  ; Factors in influence by people in this person's neighbourhood. Resets every crossing. See
  ; should-move? for more info
  influence-factor
]

; Car model
breed [cars car]


;; SETUP
to setup
  ; Clear the entire simulation
  clear-all
  setup-globals
  
  ; Generate a starting situation
  setup-world
  setup-people
  setup-cars
  
  ; Reset the simulation ticks
  reset-ticks
end

to setup-globals
  ;set prob-police-appearance 1
  
  set caught-experienced-weight 1.0
  set caught-saw-weight 0.4
  set caught-heard-weight 0.1
  set caught-saw-radius 4
  set caught-heard-chance 10
  
  ;set number-of-people 100
  ;set number-of-cars 25
  
  set car-traffic-light-red? false
  set car-traffic-light-xpos 4
  set car-traffic-light-ypos (max-pycor * 2 - (max-pycor * 0.4)) - max-pycor
  
  set pedestrian-traffic-light-red? true
  set pedestrian-traffic-light-xpos 0
  set pedestrian-traffic-light-ypos 0
  
  set pedestrian-viewing-range 8
  
  ;set waiting-zone? true
  set waiting-time-base 2
  set waiting-time-diff 8
  
  set road-start-xpos 0
  set road-end-xpos  4
  
  set tick-car-green 0
  set tick-car-red tick-car-green + car-green-time
  set tick-pedestrian-green ceiling (car-green-time * 1.2)
  set tick-pedestrian-red tick-pedestrian-green + pedestrian-green-time
  
  set stat-cycles 0
  set stat-pedestrians 0
  set stat-cautious 0
  set stat-adaptive 0
  set stat-reckless 0
  set stat-total-pedestrians 0
  set stat-total-cautious 0
  set stat-total-adaptive 0
  set stat-total-reckless 0
  set stat-red-walking 0
  set stat-adaptive-red-walking 0
  set stat-total-red-lights 0
  set stat-total-red-walking 0
  set stat-total-adaptive-red-walking 0
  
  ;The rate at which the probability to cross reduces
  set reducerate 1.0
  
  ; Set the starting color of the traffic lights
  color-traffic-light-car
  color-traffic-light-pedestrian 
  
  set influence-radius 10
  set influence-pos-factor 0.95
  set influence-neg-factor 0
end

; Colors the car traffic light during setup
to color-traffic-light-car
  ask patch car-traffic-light-xpos car-traffic-light-ypos [ 
    ifelse car-traffic-light-red?
     [ set pcolor red ]
     [ set pcolor green ]
  ]
end  

; Colors the pedestrian traffic light during setup
to color-traffic-light-pedestrian
  ask patch pedestrian-traffic-light-xpos pedestrian-traffic-light-ypos [ 
    ifelse pedestrian-traffic-light-red?
     [ set pcolor red ]
     [ set pcolor green ]
  ]
end

; Colors the patches corresponding to the waiting zone and the road
to setup-world
  ; Color the waiting area
  if waiting-zone
  [
    ask patches with [ pxcor = min-pxcor ] ; Patches on the far left side of the world
    [ set pcolor blue ]
  ]
  
  ; Color the road
  ask patches [ 
    if (pxcor < road-end-xpos) and (pxcor > road-start-xpos) [ set pcolor white ]
  ]
end

; Create the people during setup 
to setup-people  
  create-people number-of-people [
    ; Place the people on the left side of the road, but keep space for them to be counted in the current cycle.
    let xcoordinate (random (max-pxcor - 3) * -1) - 3
    ; Leave some space free at the top
    let ycoordinate (random-float (max-pycor * 2 - (max-pycor * 0.4)) - max-pycor)
    
    setxy xcoordinate ycoordinate
    set shape "person"
    set heading 90 
    
    ; 20% cautions, 60 % adaptive, 20% reckless
    ; Note: these percentages are the ratio among the population NOT the pedestrians approaching the road,
    ; since one person can cross the road multiple times.
    let prob random 100  
    ifelse prob <= 20
      [ set walker-type "cautious" ] 
      [ ifelse prob <= 80
        [ set walker-type "adaptive"
          ; Adaptive people have additional variables
          set adaptive-threshold-people-crossing (random-float 0.5) + 0.15
          set adaptive-fixed-prob-cross random-float 0.3 + 0.3
          set adaptive-prob-cross adaptive-fixed-prob-cross
          set adaptive-gone-reckless false ]
        [ set walker-type "reckless" ]] 
    
    ; Assign a color to the person depending on its walker type.
    ifelse walker-type = "cautious"
      [ set color green ]
      [ ifelse walker-type = "adaptive"
        [ set color yellow]
        [ set color red] ]
    set influence-factor 0
  ]
end

; Create the cars during setup
to setup-cars
  create-cars number-of-cars [
    ; The road is only three patches wide [1, 3]
    let xcoordinate ((random 3) + 1)
    ; The car can be anywhere along the road.
    let ycoordinate random-ycor
    
    setxy xcoordinate ycoordinate
    set shape "car"
    set heading 180
  ]
end
;; END OF SETUP PROCEDURES


; UPDATE
to go
  ; Update the people
  ask people [ update-person ]
 
  ; Update the cars
  ask cars [ move-car ]
  
  ; Update the world
  update-world
  tick
end
 
; Update method for people
to update-person
  ; Run the converging function
  if ticks mod 10 = 0 and walker-type = "adaptive"
  [ 
    set adaptive-prob-cross (1.0 / reducerate) * sin((adaptive-prob-cross - adaptive-fixed-prob-cross) * 180.0 / pi) + adaptive-fixed-prob-cross
  ] 
   
  ; Check if the person is waiting, if so reduce the wait-time
  ifelse wait-time > 0
  [
    set wait-time wait-time - 1
  ]
  [
    ; Move the person and check if the person wrapped around.
    let xcor-before xcor
    move-person
    
    ; Check for pedestrians approaching the road.
    if xcor < road-start-xpos and abs(xcor-before - road-start-xpos) > 2 and abs(xcor - road-start-xpos) <= 2
    [ 
      ; Count the pedestrian towards the various stat variables
      stat-count-pedestrian self
    ]
    
    ; Check for pedestrians wrapping around.
    if xcor < xcor-before and waiting-zone
    [
      ; Determine a slightly random wait time.
      set wait-time (waiting-time-base + random waiting-time-diff)
      
      ; Remove the caught label.
      set label ""
      
      ; Place the person on the blue waiting zone.
      ; Note: the y coordinate is randomized to reduce bias due to optimum crossing heights
      let ycoordinate (random-float (max-pycor * 2 - (max-pycor * 0.4)) - max-pycor) ; Should be the same as in setup-people
      setxy min-pxcor ycoordinate
      
      ; Reset influence factor
      set influence-factor 0
    ]
  ]
end

; Handle the movement of a person
to move-person
  ; Randomize the movement speed a bit
  let movement (random 2 + 1)

  if should-move? movement
  [
    ;; walked through red?
    let moved-onto-road? xcor <= pedestrian-traffic-light-xpos and xcor + movement > pedestrian-traffic-light-xpos
    if pedestrian-traffic-light-red? and moved-onto-road?
    [
      set  walked-through-red? true
    ]
    
    ;; made it across the road without being spotted
    if (xcor > road-end-xpos or xcor + movement > road-end-xpos) and walked-through-red? = true
    [
      set walked-through-red? false
      ;; Increase the profit the pedestrian gained
      let profit-gained (tick-pedestrian-green + 5 - ticks) * 0.1
      if profit-gained < 0 
      [
        set profit-gained 0
      ]
      set own-profit own-profit + (profit-gained)
      
      ; Count the pedestrian towards the red walkers.
      stat-count-red-walker self

      update-adaptive-persons
    ]
    
    fd movement
  ]
end

to update-adaptive-persons
  let percentage-red stat-percentage-red-walking false
  ;; some adaptive people saw enough people walk through red. Become reckless again!
  ask (people with [walker-type = "adaptive" and percentage-red >= adaptive-threshold-people-crossing]) 
  [ set adaptive-gone-reckless true ]
end

to-report car-in-range? [ ycar yped ]
  ;; Map negative coordinates x to W - x (where W is world height)
  let ycar2 (ycar + world-height) mod world-height
  
  let range1? (ycar  > yped and ycar  < yped + pedestrian-viewing-range)
  let range2? (ycar2 > yped and ycar2 < yped + pedestrian-viewing-range)
  
  ifelse (range1? or range2?)
  [report true ]
  [report false]
  
end

to-report should-move? [ movement ]
  let on-or-across-road? xcor > road-start-xpos
  let y ycor
  let car-approaching? any? cars with [car-in-range? ycor y]
  
  ;; Depending on the walker-type, certain conditions must be met before they move.
  ifelse walker-type = "cautious" 
  [
    ;; cautious: only move if
    ;; 1. they are on or across the road or
    ;; 2. they won't get on the road or
    ;; 3. the light is green and and no car is approaching them and they will get on the road
    report cautious-should-move? movement
  ] 
  [
    ifelse walker-type = "adaptive" 
    [
      ;; adaptive: only move if
      ;; 1. a cautious person would move or  
      ;; 2. there are enough people also crossing the road and does not feel that the chance of being caught is high enough.
      let near-people people in-radius influence-radius with [self != myself]
      let vals [0] ; We don't want an empty list if no one is around
      
      ask near-people
      [
        ifelse walked-through-red? = true[
         set vals lput influence-pos-factor vals 
        ][
         set vals lput influence-neg-factor vals
        ]
      ]
      
      ;; Increase the influence factor if necessary
      let new-factor max list 0 (mean vals)      
      set influence-factor max list new-factor influence-factor
      
      ;; Calculate the chance
      let chance adaptive-prob-cross
      if apply-influence-factor
      [
        set chance min list 1 (chance + influence-factor)
      ]
      
      report cautious-should-move? movement or (not car-approaching? and random-float 1.0 <= chance and label = "") 
    ] 
    ;; reckless: only move if
    ;; 1. a cautious person would move or
    ;; 2. they expect that no car will not hit them before they crossed the road (through red light)
    [
      report cautious-should-move? movement or (not car-approaching?)
    ]
  ]
end

to-report cautious-should-move? [ movement ]
  let on-or-across-road? xcor > road-start-xpos
  let y ycor
  let car-on-road? any? cars with [ycor < car-traffic-light-ypos and ycor > y]
  
  ;; cautious: only move if
  ;; 1. they are on or across the road or
  if on-or-across-road?
  [ report true ]
  ;; 2. they won't get on the road or
  if ceiling(xcor + movement) <= road-start-xpos
  [ report true  ]
  ;; 3. the light is green and and no car is approaching them and they will get on the road
  if not pedestrian-traffic-light-red? and not car-on-road?
  [ report true ]

  report false
end

to move-car
  ; A car moves with a randomized speed.
  let movement (random 4 + 1)
  
  if not car-traffic-light-red? or ycor <= car-traffic-light-ypos
  [ fd movement ]
end

to update-world
  update-lights
  update-cops
end  

to update-lights
  ; Instead of perfectly switching green from the car-light to the pedestrian-light both are temporarily red.
  ; So when the car-light goes red: 1/5th of green time later pedestrian light goes green
  if ticks = tick-car-green
  [
    set car-traffic-light-red? false
    color-traffic-light-car
    
    ; Update the red/green times of the traffic lights.
    set tick-car-red ticks + car-green-time
    set tick-pedestrian-green ticks + ceiling (car-green-time * 1.2)
    set tick-pedestrian-red tick-pedestrian-green + pedestrian-green-time
    
    set tick-car-green tick-pedestrian-red + ceiling (pedestrian-green-time * 0.2)
  ]
  
  ; Car light goes red
  if ticks = tick-car-red
  [
    set car-traffic-light-red? true
    color-traffic-light-car  
  ]
  
  ; Pedestrian light goes green
  if ticks = tick-pedestrian-green
  [
    set pedestrian-traffic-light-red? false
    color-traffic-light-pedestrian  
  ]
  
  ; Pedestrian light goes red
  if ticks = tick-pedestrian-red
  [
    ; Set the pedestrian traffic-light red.
    set pedestrian-traffic-light-red? true
    color-traffic-light-pedestrian

    ; End of cycle, adjust adaptive people that didn't see enough reckless behaviour to stay reckless themselves.
    let percentage-red-walking stat-percentage-red-walking false
    ask people with [walker-type = "adaptive"]
    [
      if adaptive-gone-reckless = true and percentage-red-walking < adaptive-threshold-people-crossing
      [ set adaptive-gone-reckless false ]
    ]

    ; Start a new cycle.
    stat-start-cycle
        
    ; Update the total number of red-lights stat
    set stat-total-red-lights stat-total-red-lights + 1
  ]
end

to update-cops
  let prob 1 + random 100
  if prob < prob-police-appearance and ticks mod 10 = 0
  [
    ;; deliquents are people who walked through the red light
    let deliquents (people with [walked-through-red? = true])
    
    ask deliquents 
    [
      ; Caught red handed.
      set label "EXP"
      set label-color blue

      ;; Reduce the probability of crossing by a percentage of the current probability.
      ;; Note: in case the fine is 100% effective, there's no chance of crossing.
      set adaptive-prob-cross adaptive-prob-cross - (adaptive-prob-cross * (fine / 100) * caught-experienced-weight)
      
      ;; If the fine is 100% effective, all our previous profit wasn't worth it.
      set own-profit own-profit * (1 - fine / 100)
      set walked-through-red? false
      
      if walker-type = "adaptive"
      [ set adaptive-gone-reckless false ]
    ]
    
    ; Note: ask the delinquents again to prevent seeing some getting caught and then experiencing it ourselves later.
    ask deliquents
    [
      ask people in-radius caught-saw-radius [
        ; Make sure the same person isn't 'shocked' by seeing someone get caught twice or ...
        ; even worse experience getting caught AND seeing someone getting caught.
        if label = ""
        [
          ; Saw some getting caught red handed.
          set label "SAW"
          set label-color blue
          
          ; Apply the fine to the cooldown.
          set adaptive-prob-cross adaptive-prob-cross - (adaptive-prob-cross * (fine / 100) * caught-saw-weight)
        ]
      ]
    ]
    
    ; Pick a few people at random for hearing the news (only if someone actually got caught).
    if not (count deliquents = 0)
    [
      ask people
      [
        let prob2 1 + random 100
        if prob2 < caught-heard-chance and label = ""
        [
          set label "HEARD"
          set label-color blue
          
          ; Apply the fine to the cooldown.
          set adaptive-prob-cross adaptive-prob-cross - (adaptive-prob-cross * (fine / 100) * caught-heard-weight)
        ]
      ]
    ]
  ]
end
;; END OF UPDATE PROCEDURES


;; STATISTICS
to stat-start-cycle
  ; Increase the cycle counter.
  set stat-cycles stat-cycles + 1
  
  set stat-pedestrians 0
  set stat-cautious 0
  set stat-adaptive 0
  set stat-reckless 0
  
  set stat-red-walking 0
  set stat-adaptive-red-walking 0
end

; Method for counting a pedestrian.
to stat-count-pedestrian [pedestrian]
  set stat-pedestrians stat-pedestrians + 1
  set stat-total-pedestrians stat-total-pedestrians + 1
  
  ask pedestrian [
    ifelse walker-type = "cautious"
    [ set stat-cautious stat-cautious + 1
      set stat-total-cautious stat-total-cautious + 1 ]
    [ ifelse walker-type = "adaptive"
      [ set stat-adaptive stat-adaptive + 1
        set stat-total-adaptive stat-total-adaptive + 1 ]
      [ set stat-reckless stat-reckless + 1
        set stat-total-reckless stat-total-reckless + 1 ]]
  ]
end

; Method for counting a red walker
to stat-count-red-walker [pedestrian]
  set stat-red-walking stat-red-walking + 1
  set stat-total-red-walking stat-total-red-walking + 1
  
  ask pedestrian [
    if walker-type = "adaptive"
    [
      set stat-adaptive-red-walking stat-adaptive-red-walking + 1
      set stat-total-adaptive-red-walking stat-total-adaptive-red-walking + 1
    ]
  ]
end

to-report stat-percentage [walkertype total?]
  ; Check if the divider is zero.
  ifelse total?
  [ if stat-total-pedestrians = 0 [report 0] ]
  [ if stat-pedestrians = 0 [report 0] ]
  
  ifelse walkertype = "cautious"
  [ report stat-cautious-percentage total? ]
  [ ifelse walkertype = "adaptive"
    [ report stat-adaptive-percentage total? ]
    [ report stat-reckless-percentage total? ] ]
end

to-report stat-percentage-red-walking [total?]
  ; Check if the divider is zero.
  ifelse total?
  [ if stat-total-pedestrians = 0 [report 0] ]
  [ if stat-pedestrians = 0 [report 0] ]  
  
  ifelse total?
  [ report stat-total-red-walking / stat-total-pedestrians ]
  [ report stat-red-walking / stat-pedestrians ]
end

to-report stat-avg-percentage-adaptive-red-walking
  let numerator ((stat-total-adaptive-red-walking) / (stat-total-red-lights + 1))
  let denominator ((stat-total-pedestrians) / (stat-total-red-lights + 1))
  
  if denominator = 0
  [ report 0 ]
  report numerator / denominator
end

; Average influence factor of adaptive pedestrians. 
to-report stat-avg-inf-factor
  let inf-factors []
  ask (people with [walker-type = "adaptive"])
  [
    set inf-factors lput influence-factor inf-factors
  ]
  report mean inf-factors
end

; DO NOT call directly, use stat-percentage instead
to-report stat-cautious-percentage [total?]
  ifelse total?
  [ report stat-total-cautious / stat-total-pedestrians ]
  [ report stat-cautious / stat-pedestrians ]
end

; DO NOT call directly, use stat-percentage instead
to-report stat-adaptive-percentage [total?]
  ifelse total?
  [ report stat-total-adaptive / stat-total-pedestrians ]
  [ report stat-adaptive / stat-pedestrians ]
end

; DO NOT call directly, use stat-percentage instead
to-report stat-reckless-percentage [total?]
  ifelse total?
  [ report stat-total-reckless / stat-total-pedestrians ]
  [ report stat-reckless / stat-pedestrians  ]
end

; The percentage of adaptive people in the simulation that have gone reckless.
; This will be the stat of interest.
to-report stat-percentage-gone-reckless
  report (count people with [walker-type = "adaptive" and adaptive-gone-reckless = true]) / (count people with [walker-type = "adaptive"])
end

;; END OF STATISTICS PROCEDURES
@#$#@#$#@
GRAPHICS-WINDOW
190
10
824
665
16
16
18.91
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
75
10
140
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
5
10
68
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
5
50
185
83
car-green-time
car-green-time
1
100
50
1
1
NIL
HORIZONTAL

SLIDER
5
85
185
118
pedestrian-green-time
pedestrian-green-time
1
100
25
1
1
NIL
HORIZONTAL

SLIDER
5
120
185
153
number-of-people
number-of-people
1
100
40
1
1
NIL
HORIZONTAL

SLIDER
5
155
185
188
number-of-cars
number-of-cars
0
100
15
1
1
NIL
HORIZONTAL

PLOT
5
495
185
667
Average profit reckless
Time
Profit
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [own-profit] of people with [walker-type = \"reckless\"]"

PLOT
5
340
185
490
Average profit adaptive
Time
Profit
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [own-profit] of people with [walker-type = \"adaptive\"]"

SLIDER
5
190
185
223
prob-police-appearance
prob-police-appearance
0
100
25
5
1
percent
HORIZONTAL

SLIDER
5
225
185
258
fine
fine
0
100
20
10
1
NIL
HORIZONTAL

PLOT
1255
515
1455
665
Average Adaptive that walk trough red
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot stat-avg-percentage-adaptive-red-walking"

SWITCH
5
260
185
293
waiting-zone
waiting-zone
0
1
-1000

PLOT
880
60
1195
305
Red light walkers %
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot stat-percentage-red-walking false"

MONITOR
880
310
1032
355
Pedestrians crossing
stat-pedestrians
1
1
11

MONITOR
1040
310
1195
355
Red walkers
stat-red-walking
1
1
11

PLOT
830
360
1030
510
Walker type %
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"cautious" 1.0 0 -10899396 true "" "plot stat-percentage \"cautious\" false"
"adaptive" 1.0 0 -1184463 true "" "plot stat-percentage \"adaptive\" false"
"reckless" 1.0 0 -2674135 true "" "plot stat-percentage \"reckless\" false"

PLOT
1040
360
1240
510
Total walker type %
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"cautious" 1.0 0 -10899396 true "" "plot stat-percentage \"cautious\" true"
"adaptive" 1.0 0 -1184463 true "" "plot stat-percentage \"adaptive\" true"
"reckless" 1.0 0 -2674135 true "" "plot stat-percentage \"reckless\" true"

PLOT
830
515
1030
665
Adaptive gone reckless %
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot stat-percentage-gone-reckless"

PLOT
1040
515
1240
665
Average Influence Factor 
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot stat-avg-inf-factor"

SWITCH
5
300
185
333
apply-influence-factor
apply-influence-factor
0
1
-1000

PLOT
1255
360
1455
510
Average Adaptive probability
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [adaptive-prob-cross] of people with [walker-type = \"adaptive\"]"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
