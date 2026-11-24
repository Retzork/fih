"""Entity grouping and one-line "when is this active" notes for the review pages.

The review pages group every sheet by the creature or screen it belongs to, so the same fish
never appears in two places. Names and behaviour come from the recovered data in `scripts/`:
`Fish.STATE_SHEETS` (guppy state rows), `Fish.SPECIES_DRAW`, `Pet.IMAGES`/`DEFS` (24-pet roster),
`Level` alien sheets, `Coin` rows and the `SCL_*` store/chooser icons.
"""

FISH = [
    (
        "guppy",
        "Guppy",
        "The starter fish. Its state sheets are 10 columns wide and one row per growth art: row 1 "
        "draws fish stage 0, row 2 stage 1, row 3 stages 2-3 and row 4 stage 4. The fifth row of the "
        "small/hungry sheets is carnivore art, not a guppy stage: it is the row Oscar draws, so it "
        "is shown on his card.",
        [
            "SMALLSWIM", "HUNGRYSWIM", "SMALLEAT", "HUNGRYEAT", "SMALLTURN", "HUNGRYTURN",
            "SMALLDIE", "SIMSWIM1", "SIMSWIM2", "SIMSWIM3", "SIMTURN1", "SIMTURN2", "SIMTURN3",
            "SIMEAT1", "SIMEAT2", "SIMEAT3",
        ],
        {
            "SMALLSWIM": "Body, normal: swims in the tank. Four guppy stage rows; the sheet's fifth "
                          "row is carnivore art and is on Oscar's card. 10 frames per row.",
            "HUNGRYSWIM": "Body, starving: swaps in when the fish's hunger runs out. Same four stage "
                          "rows; row 5 is Oscar's carnivore art.",
            "SMALLEAT": "Eat animation, normal: plays while a pellet is being eaten.",
            "HUNGRYEAT": "Eat animation, starving: the hungry twin of the same rows.",
            "SMALLTURN": "Turn animation, normal: plays when the fish reverses direction.",
            "HUNGRYTURN": "Turn animation, starving.",
            "SMALLDIE": "Corpse: cells 6..9 of each stage row, drawn for a dead fish until it fades. "
                         "Row 5 is Oscar's carnivore corpse.",
            "SIMSWIM1": "Eye layer only: composited over the body while swimming; alone it is floating eyes (Q-0042).",
            "SIMSWIM2": "Second eye-layer variant for the swim state (Q-0042).",
            "SIMSWIM3": "Third eye-layer variant for the swim state (Q-0042).",
            "SIMTURN1": "Eye/fin layer for the turn state; the body comes from SMALLTURN (Q-0042).",
            "SIMTURN2": "Second turn layer variant.",
            "SIMTURN3": "Third turn layer variant.",
            "SIMEAT1": "Eye/fin layer for the eat state; the body comes from SMALLEAT (Q-0042).",
            "SIMEAT2": "Second eat layer variant.",
            "SIMEAT3": "Third eat layer variant.",
        },
    ),
    (
        "oscar",
        "Oscar (Carnivore)",
        "The carnivore fish: eats smaller fish instead of pellets and pays more when it dies. It "
        "draws the shared guppy state sheets at their fifth row - the carnivore art - so its swim, "
        "starving swim, eat, turn and corpse clips come from those sheets. SIMCARNIVORE is his own "
        "layered art: body mask, fin mask, teeth and body for the swim, turn and eat poses. The SCL "
        "icon is its store/chooser portrait.",
        ["SIMCARNIVORE", "SCL_OSCAR"],
        {
            "SIMCARNIVORE": "Oscar's layered art: body mask, fin mask, teeth and body for the swim, "
                             "turn and eat poses. He is one size, so there is no growth row; the draw "
                             "stacks the four layers.",
            "SCL_OSCAR": "40x40 store/chooser icon.",
        },
    ),
    (
        "breeder",
        "Breeder",
        "Spawns free fish on its own cycle, so it is usually bought for the food chain. "
        "Hungry twin swaps in when unfed.",
        ["BREEDER", "HUNGRYBREEDER", "SCL_BREEDER"],
        {
            "BREEDER": "Breeder body, normal: nine rows - three growth stages, each with swim, turn "
                        "and eat.",
            "HUNGRYBREEDER": "Breeder body, starving: twelve rows - three growth stages with swim, "
                              "turn and death, then the eat pose at each of the three sizes.",
            "SCL_BREEDER": "40x40 store/chooser icon.",
        },
    ),
    (
        "ultra",
        "Ultravore",
        "The largest pellet-eater; its 160 px box makes it a wide target for aliens and lasers.",
        ["ULTRA", "SCL_ULTRA"],
        {
            "ULTRA": "Ultravore body: one size, four rows - swim, eat, turn and death.",
            "SCL_ULTRA": "40x40 store/chooser icon.",
        },
    ),
    (
        "gekko",
        "Beetlemuncher (Gekko)",
        "Eats the beetles that drop in later tanks; 80 px body.",
        ["GEKKO", "SCL_GEKKO"],
        {
            "GEKKO": "Beetlemuncher body: green swim, turn and eat, then the starving yellow swim, "
                      "turn, death and eat.",
            "SCL_GEKKO": "40x40 store/chooser icon.",
        },
    ),
    (
        "starcatcher",
        "Starcatcher",
        "Catches star pickups; 80 px body.",
        ["STARCATCHER", "SCL_STARCATCHER"],
        {
            "STARCATCHER": "Starcatcher body: purple swim, green starving swim and green starving "
                            "death.",
            "SCL_STARCATCHER": "40x40 store/chooser icon.",
        },
    ),
    (
        "grubber",
        "Grubber",
        "Bottom feeder that eats food that reaches the sand.",
        ["GRUBBER", "SCL_GRUBBER"],
        {
            "GRUBBER": "Grubber body: brown swim and eat, then the starving green swim, death and "
                        "eat.",
            "SCL_GRUBBER": "40x40 store/chooser icon.",
        },
    ),
    (
        "ball",
        "Ball",
        "The Ball species' body sheet; Stanley throws the same ball art.",
        ["BALLS"],
        {"BALLS": "Four ball designs, one per row: white, beach, soccer and basketball."},
    ),
]

# (id, title, blurb, items, descriptions, role-line used on the animation page)
PETS = [
    ("stinky", "Stinky", "Awarded 1-1. Chases coins along the bottom lane and collects them.",
     ["STINKY", "SCL_STINKY"], {"STINKY": "Idle loop in the tank; he swims the bottom lane collecting coins."}),
    ("niko", "Niko", "Awarded 1-2. Opens his shell on a 1224/1233/1440/1450-tick cycle and drops a pearl.",
     ["NIKO", "NIKOTOWER", "SCL_NIKO"], {
         "NIKO": "Idle loop; the pearl cycle opens the shell and drops a 250-value pearl.",
         "NIKOTOWER": "Niko's tower prop, drawn with him on the tank floor."}),
    ("itchy", "Itchy", "Awarded 1-3. Contact attacker: damages aliens that come within reach.",
     ["ITCHY", "SCL_ITCHY"], {"ITCHY": "Idle loop; the contact hit applies while aliens are close."}),
    ("prego", "Prego", "Awarded 1-4. Breeds extra fish on his 930-tick period.",
     ["PREGO", "SCL_PREGO"], {"PREGO": "Idle loop; the birth signal fires on his period."}),
    ("zorf", "Zorf", "Awarded 1-5. Food helper: drops pellets into the tank on his 65-tick timer.",
     ["ZORF", "SCL_ZORF"], {"ZORF": "Idle loop; pellets appear on his action timer."}),
    ("clyde", "Clyde", "Awarded 2-1. Coin collector that steps in two dimensions.",
     ["CLYDE", "SCL_CLYDE"], {"CLYDE": "Idle loop; he walks toward coins to collect them."}),
    ("vert", "Vert", "Awarded 2-2. Drops coins on his 216-tick period (coin kind 2).",
     ["VERT", "SCL_VERT"], {"VERT": "Pingpong idle loop; the coin drop fires on his period."}),
    ("rufus", "Rufus", "Awarded 2-3. Melee pet: bites aliens inside 60 px.",
     ["RUFUS", "SCL_RUFUS"], {"RUFUS": "Idle loop; the bite applies while an alien is in reach."}),
    ("meryl", "Meryl", "Awarded 2-4. The mermaid: sings on her 1400-tick cycle, blinks and moves her "
     "lips. Her menu art is a separate sheet set and lives in its own group.",
     ["MERYL", "MERYLBLINK", "MERYLLIPS", "SCL_MERYL"], {
         "MERYL": "Idle loop in the tank; her song cycle runs on the 1400-tick period.",
         "MERYLBLINK": "Plays once when she blinks; 5 frames from 3 cells.",
         "MERYLLIPS": "Mouth/lip layer used by her song and blink.",
         "SCL_MERYL": "40x40 store/chooser icon."}),
    ("wadsworth", "Wadsworth", "Awarded 2-5. Sheltered fish hide behind him while he is hidden.",
     ["WADSWORTH", "SCL_WADSWORTH"], {"WADSWORTH": "Idle loop; he hides fish on his 120-tick period."}),
    ("seymour", "Seymour", "Awarded 3-1. Aura pet; the aura writer is still a named guard (Q-0044).",
     ["SEYMOUR", "SCL_SEYMOUR"], {"SEYMOUR": "Idle loop in the tank."}),
    ("shrapnel", "Shrapnel", "Awarded 3-2. Drops bombs on his 633..652-tick period.",
     ["SHRAPNEL", "SCL_SHRAPNEL"], {"SHRAPNEL": "Idle loop; the bomb drop fires on his rolled period."}),
    ("gumbo", "Gumbo", "Awarded 3-3. Steers to the opposite corner and glows; fish lure still guarded.",
     ["GUMBO", "GUMBOLIGHT", "SCL_GUMBO"], {
         "GUMBO": "Idle loop; his corner steering runs while he is in the tank.",
         "GUMBOLIGHT": "His 20-frame glow, drawn while the corner action is active; its two rows "
                       "are the two halves of the pulse."}),
    ("blip", "Blip", "Awarded 3-4. Unlocks a store item instantly on his 200/720-tick gates.",
     ["BLIP", "SCL_BLIP"], {"BLIP": "Idle loop in the tank."}),
    ("rhubarb", "Rhubarb", "Awarded 3-5. Snaps to the bottom lane.",
     ["RHUBARB", "SCL_RHUBARB"], {"RHUBARB": "Idle loop; he sits on the sand."}),
    ("nimbus", "Nimbus", "Awarded 4-1. Cloud pet with a toss action.",
     ["NIMBUS", "SCL_NIMBUS"], {"NIMBUS": "Idle loop in the tank."}),
    ("amp", "Amp", "Awarded 4-2. Charges and electrocutes; only the charge half is live (Q-0044).",
     ["AMP", "AMPCHARGE", "SCL_AMP"], {
         "AMP": "Idle loop in the tank.",
         "AMPCHARGE": "20-frame charge-up played by the store/chooser portrait: the first row "
                       "charges, the second discharges."}),
    ("gash", "Gash", "Awarded 4-3. Bites on his 1570/1520-tick timer.",
     ["GASH", "SCL_GASH"], {"GASH": "Idle loop; the bite timer runs while he is in the tank."}),
    ("angie", "Angie", "Awarded 4-4. Revives a corpse into a live fish.",
     ["ANGIE", "SCL_ANGIE"], {"ANGIE": "Idle loop; she swims to a corpse to revive it."}),
    ("presto", "Presto", "Awarded 5-1. Transforms fish with the CHANGE-O picker.",
     ["PRESTO", "SCL_PRESTO"], {"PRESTO": "Idle loop in the tank."}),
    ("brinkley", "Brinkley", "Bonus pet. Eats food; contact counts 3/15/45/135.",
     ["BRINKLEY", "EGGBRINKLEY", "SCL_BRINKLEY"], {
         "BRINKLEY": "Idle loop; he eats pellets that touch him.",
         "EGGBRINKLEY": "The egg he hatches from on the hatch screen."}),
    ("nostradamus", "Nostradamus", "Bonus pet. Sneezes snot coins (kind 0x12) on his 300..599 timer.",
     ["NOSTRADAMUS", "EGGNOSTRADAMUS", "SCL_NOSTRADAMUS"], {
         "NOSTRADAMUS": "Idle loop; the sneeze fires on his period.",
         "EGGNOSTRADAMUS": "The egg he hatches from on the hatch screen."}),
    ("stanley", "Stanley", "Bonus pet. Throws balls at aliens; uses the BALLS art. Six rows, each a "
     "separate animation: green walk and turn, brown walk and turn, brown head-down, and the "
     "green-to-brown colour change.",
     ["STANLEY", "EGGSTANLEY", "SCL_STANLEY"], {
         "STANLEY": "Idle loop; the throw action fires on his 100-tick period.",
         "EGGSTANLEY": "The egg he hatches from on the hatch screen."}),
    ("walter", "Walter", "Bonus pet. Three rows: swim, turn and the glove punch; the glove launch is "
     "still a named guard (Q-0044).",
     ["WALTER", "EGGWALTER", "SCL_WALTER"], {
         "WALTER": "Idle loop; the punch applies while an alien is in reach.",
         "EGGWALTER": "The egg he hatches from on the hatch screen."}),
]

ALIENS = [
    ("sylvester", "Sylvester & Mini Sylvester", "Alien enemy. Joins a wave, crosses the tank and attacks fish. "
     "The Mini sheet is the fish-scale variant the port's Mini Sylvester species draws.",
     ["SYLV", "MINISYLV"], {"SYLV": "Loop while the alien is on screen.",
                             "MINISYLV": "Small variant loop; drawn at fish scale while that species swims."}),
    ("balrog", "Balrog", "Alien enemy; its wave ships with the tank-1 roster.",
     ["BALROG"], {"BALROG": "Loop while the alien is on screen."}),
    ("gus", "Gus", "Alien enemy; larger 160 px body.",
     ["GUS"], {"GUS": "Loop while the alien is on screen."}),
    ("destructor", "Destructor", "Alien enemy with a destructor beam.",
     ["DESTRUCTOR"], {"DESTRUCTOR": "Loop while the alien is on screen."}),
    ("ulysses", "Ulysses", "Alien enemy.",
     ["ULYSSES"], {"ULYSSES": "Loop while the alien is on screen."}),
    ("psychosquid", "Psychosquid", "Alien enemy; 50-frame loop.",
     ["PSYCHOSQUID"], {"PSYCHOSQUID": "Loop while the alien is on screen."}),
    ("bilaterus", "Bilaterus", "Two-headed alien; the port's Bi species body.",
     ["BILATERUS"], {"BILATERUS": "Loop while the alien is on screen."}),
    ("boss", "Boss (Cyrax)", "The tank-5 boss fight art; the fight itself is a named placeholder (G6).",
     ["BOSS", "HALO"], {"BOSS": "Loop while the boss is in the tank.", "HALO": "Boss halo overlay."}),
]

SPECIAL = [
    ("food", "Food & bonus food", "Pellets and the three bonus foods.",
     ["FOOD", "PIZZA", "ICECREAM", "CHICKEN", "BONUS1", "BONUS2", "BONUS3"], {
         "FOOD": "50-cell pellet sheet: five rows, one per food kind - brown, green and red pellets, "
                  "the star-potion flask and the breeding droplet.",
         "PIZZA": "Bonus-round food art, shown during the bonus level.",
         "ICECREAM": "Bonus-round food art.",
         "CHICKEN": "Bonus-round food art.",
         "BONUS1": "Bonus-round pickup art.",
         "BONUS2": "Bonus-round pickup art.",
         "BONUS3": "Bonus-round pickup art."}),
    ("coins", "Coins & treasure", "Coin art. Rows pick the value, the column is the spin.",
     ["MONEY", "SHELLS", "PEARL", "MONEYBAG", "MISCITEMS", "PEANUT"], {
         "MONEY": "Normal-tank coin sheet: 10 frames per row - silver, gold, star, blue diamond, "
                   "treasure chest and the beetle art.",
         "SHELLS": "Virtual Tank shell sheet: 20 frames per row - silver, gold, blue and green "
                   "spiral shells.",
         "PEARL": "Single-cell 500-value pearl (Niko's pearl included).",
         "MONEYBAG": "Single-cell bag o' shells for the top shell tiers.",
         "MISCITEMS": "Single-cell Shrapnel drop, drawn with a SPARKS overlay.",
         "PEANUT": "Nostradamus' snot pickup; shipped blank, so it is deliberately invisible."}),
    ("eggs", "Eggs & hatching", "The egg-buy dome, the crack strip and the shell shards.",
     ["EGGPIECES", "EGGSHARDS", "EGGCRACK1", "EGGCRACK2", "HATCHANIMATION", "PETLIMITEGG"], {
         "EGGPIECES": "Store dome progress: three cells from bare shell to whole egg.",
         "EGGSHARDS": "Shards left when an egg breaks.",
         "EGGCRACK1": "Crack strip, first style.",
         "EGGCRACK2": "Crack strip, second style.",
         "HATCHANIMATION": "3-cell crack strip played on the hatch screen before the pet appears.",
         "PETLIMITEGG": "The 'pet limit' egg shown when the tank is full."}),
    ("weapon", "Weapon & projectiles", "Lasers, upgrades and the shots aliens and pets fire.",
     ["LASERS", "LASERUPGRADES", "MISSILE", "ENERGYBALL", "CHOMP", "BOLT", "CROSSHAIR"], {
         "LASERS": "60-frame laser sheet: six rows, one per weapon tier (the port draws tier N "
                    "from row N-2).",
         "LASERUPGRADES": "10 cells, one weapon-level icon per cell (store art).",
         "MISSILE": "Missile projectile, 16 frames.",
         "ENERGYBALL": "Alien energy shot, 6 frames.",
         "CHOMP": "Alien bite effect, 5 frames.",
         "BOLT": "Lightning bolt overlay.",
         "CROSSHAIR": "5-frame target cursor drawn where the shot will land."}),
    ("explosions", "Explosions & smoke", "One-shot burst and smoke effects.",
     ["EXPLOSION", "EXPLOSIONSMALL", "EXPLOSIONTINY", "SMOKETINY", "SMOKESMALL", "SMOKEMISSILE"], {
         "EXPLOSION": "Large burst, once per hit.",
         "EXPLOSIONSMALL": "Small burst.",
         "EXPLOSIONTINY": "Tiny burst.",
         "SMOKETINY": "Smoke puff trail.",
         "SMOKESMALL": "Smoke puff, small.",
         "SMOKEMISSILE": "Missile smoke trail."}),
    ("effects", "Pickups, sparkle & ambient", "Overlays drawn around pickups and the tank.",
     ["SPARKLE", "SPARKS", "BUBBLES", "SHADOW", "WARPHOLE", "WARPGLOW", "MONEYFLASH", "ZZZ"], {
         "SPARKLE": "14-frame collection sparkle, played when a pickup is taken.",
         "SPARKS": "5-frame spark overlay, drawn on special coin drops.",
         "BUBBLES": "5-frame ambient bubble trail.",
         "SHADOW": "Soft shadow drawn under creatures.",
         "WARPHOLE": "Alien warp hole, 17 frames.",
         "WARPGLOW": "Glow that accompanies the warp hole.",
         "MONEYFLASH": "Flash on the money readout when coins land.",
         "ZZZ": "Sleep mark drawn over an idle/sleeping pet."}),
    ("tanks", "Tanks & backdrops", "The six tank backdrops, their masks, lighting and water overlays.",
     ["TANKBACKDROP1", "TANKBACKDROP2", "TANKBACKDROP3", "TANKBACKDROP4", "TANKBACKDROP5",
      "TANKBACKDROP6", "AQUARIUM1", "AQUARIUM2", "AQUARIUM3", "AQUARIUM4", "AQUARIUM5",
      "AQUARIUM6", "TANKMASK1", "TANKMASK2", "TANKMASK3", "TANKMASK4", "TANKMASK5",
      "TANKMASK6", "TANKLIGHTING", "STOREBACKDROPS", "WAVESIDE", "WAVE", "BUBBULATOR",
      "BUBBULATOR_STORE", "TANKCHOOSER", "HORZCREASE", "VERTCREASE", "HEALTHBAR", "HEALTHBARTUBE"], {
         "TANKLIGHTING": "Lighting overlay drawn across the tank.",
         "STOREBACKDROPS": "Six-cell store backdrop set.",
         "WAVESIDE": "Side wave overlay; pingpong loop along the tank edge.",
         "WAVE": "Wave overlay; pingpong loop across the surface.",
         "BUBBULATOR": "Bubbler decoration, 20-frame loop.",
         "BUBBULATOR_STORE": "Bubbler as sold in the store.",
         "TANKCHOOSER": "Tank chooser panel art.",
         "HORZCREASE": "Horizontal crease overlay.",
         "VERTCREASE": "Vertical crease overlay.",
         "HEALTHBAR": "Alien health bar frame.",
         "HEALTHBARTUBE": "Alien health bar fill."}),
    ("aliensfx", "Alien & magnet effects", "Alien-attractor parts and the beam/glow overlays.",
     ["AA_BEAM", "AA_GLOW", "AA_TOP1", "AA_TOP2", "AA_BOTTOM", "AA_STORE"], {
         "AA_BEAM": "Alien attractor beam.",
         "AA_GLOW": "Alien attractor glow.",
         "AA_TOP1": "Attractor top cap, style 1.",
         "AA_TOP2": "Attractor top cap, style 2.",
         "AA_BOTTOM": "Attractor base.",
         "AA_STORE": "Attractor as sold in the store."}),
]

SPECIAL.append(
    ("bonus", "Bonus screen", "The bonus round's bucket, awards and welcome banners.",
     ["BONUSBUCKET", "BONUSAWARD", "BONUSAWARD2", "WELCOMETO", "WELCOMEBACK"], {
         "BONUSBUCKET": "Bucket that catches the bonus drops.",
         "BONUSAWARD": "Award plate shown when the bonus ends.",
         "BONUSAWARD2": "Second award plate.",
         "WELCOMETO": "'Welcome to' banner shown on the bonus screen.",
         "WELCOMEBACK": "'Welcome back' banner shown on the bonus screen."})
)

UI = [
    ("meryl-menu", "Meryl - main menu", "The selector screen's baked mermaid is not the pet sheet: it "
     "stops at a stump and the tail is a separate strip the menu draws over it. Kept apart from the "
     "tank pet so the two Meryls are reviewed separately.",
     ["SELECTORSCREEN", "MERYLTAIL", "MERYL_MENU"], {
         "MERYLTAIL": "The tail fin the baked menu mermaid is missing; plays once on menu entry.",
         "SELECTORSCREEN": "The main menu art. Its painted mermaid stops at a stump - the tail is a "
                            "separate strip.",
         "MERYL_MENU": "Review composite: menu mermaid with MERYLTAIL fitted at the stump (port fit, "
                       "Q-0055)."}),
    ("cursors", "Cursors & blank", "Mouse cursor cells; BLANK hides the cursor.",
     ["CURSOR_POINTER", "CURSOR_HAND", "CURSOR_DRAGGING", "CURSOR_TEXT", "BLANK"], {
         "BLANK": "Fully transparent cell, drawn to hide the cursor.",
         "CURSOR_POINTER": "Default arrow.",
         "CURSOR_HAND": "Hand shown over clickable tank items.",
         "CURSOR_DRAGGING": "Grab cursor while dragging.",
         "CURSOR_TEXT": "Text I-beam for the edit box."}),
    ("loading", "Title & loading", "The title page and the loader bars.",
     ["TITLEPAGE", "TITLEPAGEMASK", "LOADERBAR", "LOADERBAROVER", "LOADERBARLOADING", "LOADERPLAY", "WAIT_BAR"], {
         "TITLEPAGE": "Title screen backdrop, shown while the main menu loads.",
         "TITLEPAGEMASK": "Alpha mask for the title art.",
         "LOADERBAR": "Empty loader track, shown under the title.",
         "LOADERBAROVER": "Loader hover overlay.",
         "LOADERBARLOADING": "Loader fill while a level loads.",
         "LOADERPLAY": "Loader 'play' state.",
         "WAIT_BAR": "Please-wait bar on the hatch/connect screens."}),
    ("screens", "Screen frames", "Full 640x480 screen art and its shared frame parts.",
     [    "STORESCREEN", "HATCHSCREEN", "SCREENBACK", "SCREENTITLE",
      "SCREENTITLEHOLE", "FISHBOX", "FISHBOXBUTTON"], {
         "SELECTORSCREEN": "The main menu: mermaid plus the telephone-box button panel.",
         "STORESCREEN": "Store screen backdrop.",
         "HATCHSCREEN": "The awarded-pet incubator screen.",
         "SCREENBACK": "Backdrop shared by the sub-screens.",
         "SCREENTITLE": "Screen title plate.",
         "SCREENTITLEHOLE": "Hole cut in the title plate.",
         "FISHBOX": "Fish chooser box.",
         "FISHBOXBUTTON": "Fish chooser button plate."}),
    ("buttons", "Buttons & widgets", "Button cells, check boxes, sliders and the menu bar.",
     ["MAINBUTTON", "LEFTBUTTON", "RIGHTBUTTON", "CENTERBUTTON", "PETBUTTON", "PETBUTTONRING",
      "PETBUTTONREFLECT", "PETBUTTONHOLE", "STORELEFTBUTTON", "STORETOPBUTTON",
      "STORERIGHTBUTTON", "STORELEFTHILIGHT", "STORETOPHILIGHT", "STORERIGHTHILIGHT",
      "BATTLETANKBUTTON", "BATTLETANKBUTTOND", "MIDDLEBUTTON", "MIDDLEBUTTOND",
      "OPTIONSBUTTON", "OPTIONSBUTTOND", "MENUBTND", "MENUBTND2", "MENUBTNU", "MENUBTNO",
      "PETBTNU", "PETBTNO", "UNCHECKED", "CHECKED", "SLIDERTRACK", "SLIDERTHUMB", "MENUBAR",
      "MENUBUTTONREFLECTION", "TROPHYBAR", "SPEECHBUBBLE", "SELECTORSPEECHBUBBLE",
      "HATCHREFLECTION", "FATBUTTON", "BONUSBUTTONOVERLAY", "TROPHYBUTTONS", "DIALOGBUTTON"], {
         "MENUBAR": "The 640x75 store bar with its purple price plates.",
         "PETBUTTON": "4-cell pet chooser button.",
         "PETBUTTONRING": "Ring around the pet button.",
         "PETBUTTONREFLECT": "Reflection under the pet button.",
         "PETBUTTONHOLE": "Hole behind the pet button.",
         "UNCHECKED": "Empty check box.",
         "CHECKED": "Ticked check box.",
         "SLIDERTRACK": "Options slider track.",
         "SLIDERTHUMB": "Options slider thumb.",
         "SPEECHBUBBLE": "Speech bubble drawn over tank creatures.",
         "SELECTORSPEECHBUBBLE": "Speech bubble on the main menu.",
         "MENUBUTTONREFLECTION": "Reflection under the menu buttons.",
         "HATCHREFLECTION": "Reflection under the hatched pet.",
         "TROPHYBAR": "Trophy progress bar.",
         "TROPHYBUTTONS": "6-cell trophy tab buttons.",
         "FATBUTTON": "Wide button plate.",
         "BONUSBUTTONOVERLAY": "Overlay drawn on the bonus button.",
         "DIALOGBUTTON": "Dialog button plate."}),
    ("help", "Help & info cards", "The help screens and the shell/info plates.",
     ["HELPALIEN", "HELPPETCHOOSE", "HELPSCREENSAVER", "HELPSHELL", "STORESHELL", "HELPARROW"], {
         "HELPALIEN": "Help card about aliens.",
         "HELPPETCHOOSE": "Help card about choosing a pet.",
         "HELPSCREENSAVER": "Help card about the screen saver.",
         "HELPSHELL": "Help card for shells.",
         "STORESHELL": "Store shell plate.",
         "HELPARROW": "Arrow drawn on the help screens."}),
    ("dialogs", "Dialogs & text", "Modal dialog chrome and the text field.",
     ["DIALOG", "EDITBOX"], {
         "DIALOG": "Dialog panel frame.",
         "EDITBOX": "Text input field."}),
]

GROUP_FALLBACK = {
    "aliensfx": "Alien-attractor overlay, drawn while the attractor is active.",
    "buttons": "Interface button art; the widget swaps the cell for hover/press.",
    "screens": "Full-screen art, drawn only while its screen is open.",
    "loading": "Title/loader art, shown while the game boots or a level loads.",
    "help": "Help art, drawn on its help screen.",
    "cursors": "Cursor art, drawn at the pointer.",
    "dialogs": "Dialog art, drawn while the dialog is open.",
    "effects": "Overlay effect, played once when its event fires.",
    "tanks": "Tank/backdrop art, drawn behind the tank.",
    "eggs": "Egg art, drawn while an egg is bought, cracking or hatching.",
    "coins": "Pickup art, drawn while the coin is on the tank floor.",
    "food": "Food art, drawn while it falls or sinks.",
    "weapon": "Weapon art, drawn while the shot is in flight.",
    "explosions": "One-shot effect, played when its hit lands.",
    "boss": "Boss art, drawn while the boss is in the tank.",
    "guppy": "Guppy sheet cell chosen by growth stage and state.",
}

ALL = FISH + PETS + ALIENS + SPECIAL + UI


def _kind(gid: str) -> str:
    if any(gid == f[0] for f in FISH):
        return "fish"
    if any(gid == p[0] for p in PETS):
        return "pet"
    if any(gid == a[0] for a in ALIENS):
        return "alien"
    if gid in ("food", "coins", "eggs"):
        return "item"
    if gid in ("weapon", "explosions", "effects", "aliensfx"):
        return "effect"
    if gid == "tanks":
        return "world"
    return "ui"


GROUPS = []
GROUP_OF = {}
DESC = {}
for gid, title, blurb, items, descs in ALL:
    GROUP_OF.update({name: gid for name in items})
    DESC.update(descs)
    GROUPS.append({"id": gid, "title": title, "blurb": blurb, "kind": _kind(gid),
                   "items": list(items)})

# MERYL_MENU is a generated composite, not a manifest sheet.
COMPOSITES = {"MERYL_MENU": "meryl-menu"}

## Rows that belong together inside one entity: the sheet's own families (one growth per row family,
## a colour pair, the four layers of a pose). `emit()` turns each entry into a sub-section of the
## entity's group, so Breeder reads as three growths instead of nine loose rows.
SUBGROUPS = {
    "BREEDER": [
        ("Normal - growth 1", "Swim, turn and eat at the first size.", (0, 1, 2)),
        ("Normal - growth 2", "The same three states one size up.", (3, 4, 5)),
        ("Normal - growth 3", "The largest breeder.", (6, 7, 8)),
    ],
    "HUNGRYBREEDER": [
        ("Starving - growth 1", "Starving swim, turn and death at the first size.", (0, 1, 2)),
        ("Starving - growth 2", "Starving swim, turn and death at the second size.", (3, 4, 5)),
        ("Starving - growth 3", "Starving swim, turn and death at the third size.", (6, 7, 8)),
        ("Starving - eat", "The starving eat pose at each of the three sizes.", (9, 10, 11)),
    ],
    "GRUBBER": [
        ("Normal (brown)", "Swim and eat.", (0, 1)),
        ("Starving (green)", "Swim, death and eat.", (2, 3, 4)),
    ],
    "GEKKO": [
        ("Normal (green)", "Swim, turn and eat.", (0, 1, 2)),
        ("Starving (yellow)", "Swim, turn, death and eat.", (3, 4, 5, 6)),
    ],
    "PSYCHOSQUID": [
        ("Red", "Swim and turn.", (0, 1)),
        ("Blue", "Swim and turn.", (2, 3)),
        ("Colour change", "Red to blue.", (4,)),
    ],
    "BILATERUS": [
        ("Side view", "Jaw open, jaw wide, jaw working, fins out and the two mouth-open poses.",
         (0, 1, 2, 3, 4, 5)),
        ("Top-down", "The pod with the fins out and turned.", (6, 7)),
    ],
    "SIMCARNIVORE": [
        ("Swim", "Body mask, fin mask, teeth and the black body.", (0, 1, 2, 3)),
        ("Turn", "The same four layers for the turn.", (4, 5, 6, 7)),
        ("Eat", "The same four layers for the eat.", (8, 9, 10, 11)),
    ],
    "STANLEY": [
        ("Green", "Walk and turn.", (0, 1)),
        ("Brown", "Walk, turn and eat.", (2, 3, 4)),
        ("Colour change", "Green to brown.", (5,)),
    ],
    "ITCHY": [
        ("Swim and turn", "The two moving poses, mouth closed.", (0, 1)),
        ("Eat", "The same two poses with the mouth open.", (2, 3)),
    ],
}


def subgroups_for(sheet: str):
    return SUBGROUPS.get(sheet, [])

# Groups that hold one entity each; skipped when the entity owns no animated clip.
FISH_NAMES = {f[0] for f in FISH}
PET_NAMES = {p[0] for p in PETS}
ALIEN_NAMES = {a[0] for a in ALIENS}


def group_for(name: str) -> str:
    return GROUP_OF.get(name) or COMPOSITES.get(name) or "other"


def describe(name: str, gid: str | None = None) -> str:
    if name in DESC:
        return DESC[name]
    gid = gid or group_for(name)
    if name.startswith("SCL_"):
        return "40x40 store/chooser icon."
    return GROUP_FALLBACK.get(gid, "Review art.")


def title_of(gid: str) -> str:
    for group in GROUPS:
        if group["id"] == gid:
            return group["title"]
    return "Other"


def blurb_of(gid: str) -> str:
    for group in GROUPS:
        if group["id"] == gid:
            return group["blurb"]
    return ""


# Animation-page role notes, per clip name. `describe()` already covers many; these add timing.
CLIP_DESC = {
    "MERYLTAIL": "Menu fin flop: plays once on selector entry, two ticks a frame after a three-tick hold.",
    "MERYLBLINK": "Blink: once, five frames out of three cells.",
    "MERYL": "Tank idle loop; her song cycle is the 1400-tick period.",
    "SCL_MERYL": "Chooser portrait loop (10 frames).",
    "NIKO": "Tank idle; the shell opens on the pearl cycle.",
    "SCL_NIKO": "Chooser portrait pingpong loop.",
    "SCL_STINKY": "Chooser portrait loop.",
    "BALROG": "Alien wave loop.",
    "GUS": "Alien wave loop.",
    "SYLV": "Alien wave loop.",
    "DESTRUCTOR": "Alien wave loop.",
    "ULYSSES": "Alien wave loop.",
    "PSYCHOSQUID": "Alien wave loop.",
    "BOSS": "Boss idle loop.",
    "MINISYLV": "Small Sylvester loop.",
    "STINKY": "Tank idle; collects coins along the bottom lane.",
    "CLYDE": "Tank idle; walks to coins.",
    "VERT": "Pingpong idle; drops a coin on his period.",
    "WALTER": "Pingpong idle; punch applies while an alien is in reach.",
    "SCL_WALTER": "Chooser portrait pingpong loop.",
    "NIKOTOWER": "Niko's tower prop, held while he sits on the floor.",
    "HALO": "Boss halo overlay.",
    "GUMBOLIGHT": "Gumbo's glow while his corner action is active.",
    "AMPCHARGE": "Amp's charge-up.",
    "WAVESIDE": "Side wave, pingpong along the edge.",
    "WAVE": "Surface wave, pingpong across the tank.",
}
